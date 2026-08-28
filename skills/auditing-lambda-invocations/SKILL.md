---
name: auditing-lambda-invocations
description: Use when asked what an AWS Lambda actually did over some past window and whether it is still doing it — vague multi-day reports about a function returning wrong answers, "is the fix live on PROD", "why did request/order N get that result", checking a deployed alias against its own CloudWatch logs, a symptom whose window spans a deploy or an alias promotion, or deciding whether a bad Lambda result is our defect, an upstream dependency, or a caller sending something the contract cannot use. Agnostic of account, region, function name, and environment/alias naming.
---

# Auditing Lambda Invocations

A function's log group is two things at once: a **corpus** of the real events it
was invoked with, and an **oracle** of what the deployed version actually returned
for them. Reading it tells you what happened. Re-running the corpus through the
current code and diffing against the oracle tells you whether it still happens —
as a measurement, not an opinion about a diff.

Lambda hands you the one thing that makes this rigorous for free: **every
invocation records the function version that served it.** Use it, or every finding
you report is attributed to "production" rather than to a build.

The failure mode is confident misattribution — a real symptom pinned to the wrong
version, the wrong component, or the wrong owner, delivered with a table.

## The gate — is this an audit?

**Does the answer depend on what the deployed function really did, over a window
you cannot reproduce on demand?**

- **No** → read the handler, write a test, invoke it locally. "Why does this
  return X" is answerable from source. Say so and move on.
- **Yes** → the clusters below apply.

## 1. Pin the target before pulling anything

Every one of these is a parameter. Hardcoding any of them is what makes an audit
unrepeatable next quarter, in the next account, for the next function.

| Resolve | How |
|---|---|
| Account and identity you are actually using | `aws sts get-caller-identity` — confirm it before blaming missing data on the service |
| Function, region, alias under audit | From the ask. "Production" is an alias, not a fact |
| Alias → version **right now** | `aws lambda list-aliases --function-name <fn>` — this is the build your verdicts are about |
| Version → publish time | `aws lambda list-versions-by-function --function-name <fn>` |
| Env/config of the alias | `aws lambda get-function-configuration --function-name <fn> --qualifier <alias>` — config changes behaviour without changing code |
| Log group | conventionally `/aws/lambda/<fn>`, often suffixed per environment; confirm with `aws logs describe-log-groups --log-group-name-prefix` rather than assuming |

**Permissions split matters.** `describe-log-groups` frequently succeeds where
reading *events* (`logs tail` / `filter-log-events`) is denied, and DynamoDB or
other state reads may be denied entirely. Establish what you can read up front and
state what you could not verify, rather than silently inferring it.

## 2. Pull the whole window to disk, once

| Do | Because |
|---|---|
| Export the entire window to a file before analysing any of it | Sampling picks the answer before you ask; you cannot count what you never pulled |
| Keep raw log, per-invocation records, and analysis as separate artifacts | Re-deriving is free; re-fetching may be impossible once retention expires |
| Never page a large log group through your own context | You will answer from the first screenful and call it a survey |
| Sanity-check the export: first/last timestamp, invocations per day, versions present | A suspicious zero-day is usually a truncated export, not a quiet day |

Capture and replay are scripts that get rerun. **REQUIRED SUB-SKILL:** use
`durable-scripts` for them — this is precisely its "persist raw collected data to
disk as it is produced" rule.

## 3. Rebuild invocations from the Lambda frame

CloudWatch returns interleaved lines. The frame Lambda itself emits is what
reassembles them, and it is identical in every account:

- `INIT_START` — cold start. `INIT_START` with no following `START` is an init failure.
- `START RequestId: <id> Version: <n>` — the correlation id **and the build**.
- your handler's own lines
- `END RequestId: <id>`
- `REPORT RequestId: <id> Duration / Billed Duration / Memory Size / Max Memory Used / Init Duration`

Tag every line with its request id and version, then fold each group into one
record: version, timestamp, inputs, outputs, REPORT metrics. That file is the
corpus; everything downstream queries it, never the raw log.

## 4. Attribute every observation to a version

A window that spans a deploy is several different programs in one file.

| Do | Because |
|---|---|
| Build the version → commit → what-changed table **before** reading any finding | Otherwise you report a fixed bug as live, or credit a fix that shipped after the evidence |
| Take the version from each invocation's `START`, not from the deploy history | Deploy history says what was published; `START` says what served |
| For each adjacent version pair, diff the source — `git diff --stat <a>..<b> -- <src>` | An empty diff means the version boundary is **not** a behaviour boundary |
| Report per-version counts with denominators, never window totals | "5 occurrences" hides that all 5 predate the fix |

**The env-publish trap.** Updating environment variables publishes a **new version
with byte-identical code**. Treating that as a code boundary misdates a fix in both
directions. A version number changing is not evidence that behaviour changed —
the diff is.

**The alias trap.** The alias under audit may lag the branch by several commits, a
promotion commit may exist with no published version behind it yet, and the
repo's default branch may not be what the pipeline builds from. Verify which ref
ships before writing "fixed".

## 5. Health pass from REPORT, before any logic finding

`REPORT` answers questions about the function's operation that its own logging
does not. Do this pass first — it is cheap and it reframes everything after it.

Errors and timeouts (`Task timed out`), max duration against the configured
timeout, `Max Memory Used` against `Memory Size`, cold-start share, and the
invocation-count shape per day. A logic audit that opens with "and there were no
errors or timeouts in the window" is trusted differently from one that never looked.

## 6. Replay the corpus through the current code

**Parity control first.** Replay the window served by the *currently deployed*
version and diff against what it actually returned. It must match.

- Matches → the harness is faithful; divergence on older versions localizes a real change.
- Doesn't match → **that is a harness bug, not a finding.** Every conclusion in
  the run is noise until this is clean.

When diffing older versions, separate **truncation** (current code returns a
subset — expected after a filter tightened) from **reordering among survivors**
(compare the common prefix only), or you will count one as the other.

## 7. Recover unlogged inputs by inversion, never by invention

Handlers routinely fail to log inputs the replay needs. Do not guess them, and do
not skip the replay because of them. Search for the value that **reproduces the
recorded output**, then treat the result by cardinality:

| Outcome | Do |
|---|---|
| Exactly one candidate reproduces every recorded row | Use it; note that it was recovered, not read |
| Several fit | Drop that invocation from the corpus — never pick the plausible one |
| None fit | Your model of the code is wrong. Chase that before continuing |

A **range** or set of values that all reproduce the output is the *several fit*
row, not the first one. Narrowing an input to an interval is not recovering it:
report those invocations as ambiguous and exclude them from any count that
depends on the value. Recovering one input of two is the normal outcome — use
the one you pinned, and bound what the other one can no longer decide.

Also check whether the value is sitting in a *different* line of the same
invocation — a value absent from the success path is often present in a debug
line the handler emitted on the way there.

Report the survival rate. "104 of 104 recovered" and "40 of 104" are different claims.

## 8. Name what the log cannot answer

Every field the handler does not log bounds a class of question permanently. State
that boundary beside the findings it limits, not as a footnote.

If the pre-filter input is never logged, "should this candidate have been included"
is unanswerable for everything the filter dropped. Say so, rather than answering
it from the survivors.

## 9. Count units of work, not invocations

One order, ticket, or job is frequently several invocations — client retries,
scheduled re-runs, a caller polling. Dedupe on the domain id, not on RequestId, or
every rate you report is inflated.

This also hands you the strongest upstream test available: **find one unit of work
invoked more than once.** If the answers differ while your inputs and code did not,
the variance is upstream, and two timestamps prove it more cheaply than any amount
of reasoning about the dependency.

## 10. Classify before writing the finding

| Class | Signature | Verdict reads |
|---|---|---|
| Our defect | Recorded event + current code reproduces the bad output | Still reproduces / fixed in version N |
| Upstream dependency | Same unit of work, minutes apart, different dependency response | Not fixable here — escalate with timestamps |
| Caller contract | Handler behaved as documented; the caller sent something the contract cannot use | Integration gap — cite the contract |
| Correct but illegible | Behaviour is right; the log line makes it look wrong | Not a defect — fix the logging |

**A count is not evidence of harm.** "46% of candidates were filtered out" says
nothing about whether a *better* one was removed. Reconstruct what was removed and
measure it against what won — with a yardstick that matches the reported symptom.
A nearby-but-wrong yardstick produces a confident wrong verdict in either direction.

## Verdict vocabulary

Every finding gets exactly one. "Fixed" without saying *where* is the most common
way an audit misleads.

- **Still reproduces** — on the version the audited alias currently points to
- **Fixed in production** — version and date it landed
- **Fixed on a branch, not deployed** — name the ref and where it is sitting
- **Upstream** — not addressable in this codebase
- **Not a defect** — behaviour is correct; say what made it look otherwise
- **Undecided** — the log cannot settle it; say which field would have

## Nine months later

Could someone else re-run your capture and replay against a different account,
function, and alias, land on the same numbers, and see which questions you chose
not to answer?

Commands, the segmentation recipe, the inversion pattern, and a worked audit:
`reference/method.md`.
