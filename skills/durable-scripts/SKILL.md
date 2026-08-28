---
name: durable-scripts
description: Use when about to write a script, CLI tool, one-off automation, sweep, aggregation, integration, migration, or sync in any language — before writing the first line. Decides whether the task is a genuine throwaway (write it directly, skip everything here) or something that will be rerun, handed to future-you, touch shared/external state, or process significant data/time (apply rerun-safety/idempotency, CLI flag conventions, incremental checkpointing, observability, config precedence, and cwd-independence). Language-agnostic — not tied to Python/Node/Bash specifically.
---

# Durable Scripts

Most scripts you write are genuinely disposable. A few quietly become
load-bearing — rerun weekly, copied into another project, or the only record
of how a migration happened. The failure mode isn't "insufficient rigor," it's
picking the wrong bucket: over-building a five-minute throwaway, or under-building
something that turns out to need to survive a crash, a rerun, or a rename of the
directory it lives in.

## The gate — decide the bucket first

**Will this be rerun, handed to future-you, touch shared/external state, or
process a lot of data/time?**

- **No** → write the direct one-off. Skip the checklist below. Say so in one
  line ("quick one-off, skipping the durability checklist") and move on.
- **Yes** → the clusters below apply.

This is the only gate. Don't apply a "core minimum" to everything (that's
ceremony on genuinely disposable scripts) and don't wait for the user to say
"make this reusable" (scripts become long-lived quietly, without anyone
flagging it up front).

## The clusters (once the gate says yes)

### 1. Contract & interface
| Do | Because |
|---|---|
| Inputs, outputs, side effects, and failure conditions are answerable without reading the implementation | Future-you (or a teammate) needs to trust it before running it |
| Named args over positional; move to config once flags multiply | Positional args are unreadable at the call site past 2-3 |
| One flag vocabulary reused across scripts: `--dry-run`, `--verbose`, `--force`, `--output`, `--config`, `--limit`, `--since`, `--until` | Consistency across your own scripts beats novelty in any one |
| `--help` includes real invocation examples, not just a flag list | A flag list doesn't show *how* they compose |
| Escape hatches (`--limit`, `--only`, `--since`) exist | Debugging should never require a full run |
| Runnable from any working directory — resolve paths relative to the script's own location, an explicit arg, or a discovered project root; never assume the caller `cd`'d somewhere first | The next invocation (cron, another repo, a teammate's shell) won't share your cwd |

### 2. Safety & idempotency
| Do | Because |
|---|---|
| Rerun-safe by default: upserts, checkpoints, dedup keys, atomic file replacement | Never assume a clean first run — reruns are the norm, not the exception |
| Destructive ops require explicit intent: `--dry-run` is the safe default, `--force` gates irreversible action | Cheap insurance against the 2am fat-fingered rerun |
| Shape as discovery → plan → execute (`find_targets()` then `process_target()`) | Lets `--dry-run` simply stop after the plan, for free |
| Decide persistent identity explicitly — what makes two things "the same": path / DB id / content hash / external id / `(source, key)` | Undecided identity is the root cause of most duplicate-processing and sync bugs |
| Fail early: validate paths, credentials, incompatible flags, schema before expensive or destructive work | Cheap checks up front beat an expensive rollback |

### 3. Large-data / long-running — hard rule, not a judgment call
**Persist raw collected data and incremental output to disk *as it's produced*,
never buffered until the end.** A crash mid-sweep must lose zero already-fetched
work. This one is non-negotiable for anything sweeping/collecting at scale —
learned the expensive way from re-running multi-hour prod sweeps that buffered
everything in memory and lost it all on a late failure.

- Structure around units of work so "only what changed since last run" becomes
  possible later, even if the first version processes everything.
- Concurrency is opt-in and bounded to a sane worker cap; retries apply only to
  genuinely transient failures (a timeout is retriable, malformed input is not).

### 4. Observability & partial failure
| Do | Because |
|---|---|
| Machine-readable data on stdout, diagnostics on stderr | `foo \| jq ...` or `foo > results.json` must work without log noise mixed in |
| Meaningful exit codes: 0 success, nonzero failure | Never print "ERROR" and exit 0 |
| Log the *decision*, not the activity — "skipping foo: output exists, hash unchanged" beats "processing foo" — with an identifier every line traces back to | Activity logs tell you it ran; decision logs tell you why the result looks the way it does |
| Batch runs end in a summary: scanned/eligible/succeeded/failed counts + a reproducible failure-log path | The last line printed is what gets read |

### 5. Config & modes
- Precedence: sensible defaults → config file → environment variables → explicit CLI args.
- Env vars are for secrets/environment-specific values, not ordinary behavioral knobs.
- Named modes beat boolean-flag explosions: `--strategy=merge` over requiring the
  reader to decode `--keep-old --dedupe --prefer-new-metadata` as "merge."

### 6. Architecture
- Orchestration (parse args → load config → validate → call `run()` → report →
  exit code) stays separate from domain logic that's callable outside the CLI
  (tests, another script, a notebook).
- Selection separate from action — inspect what *would* be touched independently
  of processing it.
- Prefer a pipeline with inspectable intermediate artifacts (JSON/JSONL/CSV/SQLite)
  over one monolithic script, when phases have a real intermediate shape.
- No mandated directory layout. This is about separation of concerns, not folders.

### 7. Boring dependencies; test the dangerous parts
- Reach for the runtime's stdlib / what's already used in the project before
  adding a dependency for a one-off script.
- One real check each for: filtering rules, transformation logic, idempotency,
  path handling, malformed input, destructive boundaries. Skip elaborate suites
  otherwise.

## The shape

```
def main():
    args = parse_args()
    config = load_config(args)       # defaults -> file -> env -> args
    validate(args, config)           # fail fast, before touching anything
    targets = find_targets(config)   # discovery: safe, side-effect-free
    if args.dry_run:
        report_plan(targets); return 0
    results = process(targets, config)   # bounded-concurrent if warranted
    report_summary(results)
    return 0 if not any(r.failed for r in results) else 1
```

## Nine months later

Before calling it done: if you rediscovered this script nine months from now
with zero memory of writing it, could you rerun it safely, tell what it
touched, and debug a failure — using only the script itself, from any directory?

Expanded, example-annotated version of each cluster: `reference/checklist.md`.
