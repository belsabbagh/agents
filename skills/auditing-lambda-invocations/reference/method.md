# Method, in full

Every `<placeholder>` below is a parameter. Nothing here assumes an account,
region, function name, or environment/alias naming scheme.

## Pinning the target

```bash
aws sts get-caller-identity                                    # who am I, which account
aws lambda list-aliases --function-name <fn>                   # alias -> version (the build under audit)
aws lambda list-versions-by-function --function-name <fn> \
  | jq -r '.Versions[] | "\(.Version)\t\(.LastModified)\t\(.Description // "")"'
aws lambda get-function-configuration --function-name <fn> --qualifier <alias> \
  | jq '{Version, Runtime, Handler, Timeout, MemorySize, Environment}'
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/<fn> \
  | jq -r '.logGroups[] | "\(.logGroupName) stored=\(.storedBytes) retention=\(.retentionInDays // "never")"'
```

`describe-log-groups` often succeeds where reading events does not. If
`aws logs tail` is denied, that is an IAM gap to name in the report, not evidence
of a quiet function.

## Pulling the window

```bash
aws logs tail "<log-group>" --since 7d --format short > window.log
```

`--since` accepts durations (`7d`, `24h`) or an ISO instant. Run it in the
background and write straight to a file — never into your own context.

Verify the export before trusting it:

```bash
head -1 window.log; tail -1 window.log                          # true window covered
awk '$2=="START"{print substr($1,1,10)}' window.log | sort | uniq -c   # invocations per day
awk '$2=="START"{print $NF}' window.log | sort -n | uniq -c      # versions present, with counts
```

A day showing zero is usually truncation. Re-pull before analysing.

## Rebuilding invocations

```bash
# Tag every line with its request id and the version that served it.
awk '
  $2 == "START"  { req = $4; ver = $6; next }
  $2 == "END" || $2 == "REPORT" || $2 == "INIT_START" { next }
  { line = $0; sub(/^[^ ]+ /, "", line); printf "%s\t%s\t%s\t%s\n", req, ver, $1, line }
' window.log > tagged.tsv
```

Then fold each request id into one record. With JSON handler logs:

```bash
jq -Rc 'split("\t") | {req:.[0], ver:.[1], ts:.[2], m:(.[3]|fromjson)}' tagged.tsv > lines.jsonl

jq -sc 'group_by(.req) | map(
    (map(select(.m.msg=="<your request log line>"))  | first) as $in
  | (map(select(.m.msg=="<your result log line>"))   | first) as $out
  | {req: .[0].req, ver: .[0].ver, ts: .[0].ts,
     input: $in.m, output: $out.m}
) | .[]' lines.jsonl > invocations.jsonl
```

`invocations.jsonl` is the corpus. Query that from here on.

## Health pass from REPORT

```bash
grep -c 'Task timed out' window.log
awk '$2=="REPORT"{ for(i=1;i<=NF;i++) if($i=="Duration:" && $(i-1)!="Billed") print $(i+1) }' \
  window.log | sort -n | tail -1                                # slowest invocation, ms
awk '$2=="REPORT"{ for(i=1;i<=NF;i++) if($i=="Used:") print $(i+1) }' window.log | sort -n | tail -1
grep -c INIT_START window.log                                   # cold starts
```

Compare slowest duration against the configured `Timeout` and max memory against
`MemorySize` from step 1. Report these even when clean — "no errors, no timeouts,
slowest 4.2s against a 30s timeout" is what makes the rest of the audit credible.

## The version map

```bash
git log --format='%h %ad %s' --date=iso-strict --grep='<deploy marker>'
```

Join publish times from `list-versions-by-function` to commits by timestamp, then
test each adjacent pair for a real code change:

```bash
git diff --stat <older>..<newer> -- <source dirs>   # empty output => config/env-only publish
```

Emit a table before reading any finding: version, active window, commit, what
changed, invocation count. Versions with an empty diff are **one** behaviour
regime with their neighbour, not two.

## Recovering an unlogged input by inversion

The input is unknown; the output it produced is recorded; the function relating
them is in the code you have. Search the domain for the value that reproduces
every recorded row.

```python
def recover(candidates, rows, predict):
    """The unique candidate reproducing every recorded row, else None.

    candidates: the input domain (enumerable, or narrowed by an invariant first)
    rows:       the recorded output rows of ONE invocation
    predict:    (candidate, row) -> what the code would have produced
    """
    fits = [c for c in candidates
            if all(close(predict(c, r), r["recorded"]) for r in rows)]
    return fits[0] if len(fits) == 1 else None    # ambiguous or impossible -> drop
```

- **Compare on every row**, not the first. One row fits many candidates; ten rarely fit two.
- **Match the recorded precision.** If the handler rounded to 2 decimals, compare at 2 decimals — exact equality rejects the true value.
- **Ambiguous means drop**, not "pick the common one".
- **Impossible means your model is wrong** — the code path you believe ran, didn't. That is a finding in itself.
- **Report the survival rate** alongside every number derived from the corpus.

Before searching, check the other lines of the same invocation: a value missing
from the success path is often present in a debug line emitted along the way.

## Replay harness shape

```
replay(corpus[version == alias_current_version]) == recorded_output    # must be 100%
```

Run this control first. Then replay older versions, where divergence is the
finding. Emit one JSON object per invocation — version, whether the current code
reproduced the recorded order, whether the top result changed, what the recovered
inputs were — and aggregate with `jq`. Per-invocation JSON keeps the harness
honest: you can point at any single row and re-derive it.

Keep the harness in the repo under `scripts/`, reading the corpus on stdin. It is
a durable script: flags for narrowing to one request id, machine-readable output
on stdout, diagnostics on stderr.

## Worked audit

A ranking Lambda; one week; users report "wrong results, sometimes".

1. **Pin** — alias `PROD` → version 62; log group confirmed; caller identity confirmed.
2. **Pull** — whole week to disk. 318 invocations, six versions present.
3. **Health** — zero errors, zero timeouts, slowest 4.2s. Nothing operational; it is a logic audit.
4. **Version map** — six versions, but one was an environment-variable publish with an empty code diff. Five behaviour regimes, not six.
5. **Parity** — replay the current version's own window: identical, 100%. Harness trusted.
6. **Replay the rest** — one class of misordering appears only on versions predating a specific commit → fixed, with the version and date. Another appears on every version including the current one → still reproduces.
7. **Inversion** — two inputs the ranking depends on appear in no log line. Both recovered as the unique values reproducing the recorded output, in 187 of 187 invocations. Recovered, not guessed, and stated as such.
8. **Units of work** — one order was invoked three times in five hours. Two returned an escalation, one returned a result, with identical inputs and code. Upstream, proven by timestamps.
9. **Bound** — the candidate list handed to the function is never logged, only its count. "Should this candidate have matched" is unanswerable for anything absent from the response. Stated beside the finding it limits.

Result: one fixed in production, one still reproducing on the current alias, one
upstream, one correct-but-illegible, and one question the logs cannot settle.
