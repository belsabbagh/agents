# Durable Scripts — expanded checklist

Detail and worked examples for each cluster in `SKILL.md`. Load this only once
the gate says "yes" and you want a concrete pattern to copy, not just the rule.

## 1. Contract & interface

**cwd-independence, concretely.** A script that does `open('config.json')` or
`os.path.join(os.getcwd(), 'out')` works once — from the directory you happened
to be in when you wrote it — and breaks the next time it's invoked from cron, a
different repo, or a teammate's shell. Resolve paths one of these ways instead:

```python
# relative to the script itself
BASE = Path(__file__).resolve().parent

# or an explicit, required argument
parser.add_argument('--output', required=True, type=Path)

# or a discovered anchor (e.g. walk up to the nearest .git / package.json)
```

**`--help` with real examples**, not just a flag table:

```
Usage: sweep-jobs.py [OPTIONS]

Examples:
  sweep-jobs.py --since 2026-08-01 --dry-run
  sweep-jobs.py --only account=kafri --output report.json
```

## 2. Safety & idempotency

**Discovery/plan/execute split**, concretely:

```python
def find_targets(config) -> list[Target]:   # read-only, safe to call anytime
    ...

def process_target(target, config) -> Result:
    ...

targets = find_targets(config)
if args.dry_run:
    print_plan(targets)
    sys.exit(0)
results = [process_target(t, config) for t in targets]
```

`--dry-run` costs nothing extra once the split exists — it's just "stop before
`process_target`."

**Persistent identity, worked example.** A sync script pulling records from an
API into a local store needs one deliberate answer to "when are records A and
B the same record":

- `path` — file-based, identity = normalized absolute path
- `external id` — the source system's own ID (safest when available)
- `content hash` — no stable ID, dedupe on a hash of normalized content
- `(source, key)` — composite when the same key can come from multiple sources

Pick one, name it, and use it consistently for upserts *and* for detecting
"this record moved" vs. "this is a new record."

## 3. Large-data / long-running — worked example

The pattern that satisfies the hard rule (persist as you go, not at the end):

```python
with open(checkpoint_path, 'a') as ckpt:          # append, not overwrite
    for chunk in chunks(targets, size=10):
        results = fetch_concurrent(chunk, max_workers=10)
        for r in results:
            ckpt.write(json.dumps(r) + '\n')      # flushed per chunk, not buffered
            ckpt.flush()
```

If the process dies after chunk 40 of 100, the checkpoint file has 40 chunks of
real, usable data — rerun with `--resume` (skip anything already in the
checkpoint) rather than starting over.

**Rationalizations to watch for** (this rule gets negotiated under time
pressure more than any other cluster):

| Rationalization | Why it doesn't hold |
|---|---|
| "It's fast, it'll finish before anything goes wrong" | The scripts that most need this are the ones that grow from "fast" to "3 hours" without anyone revisiting the persistence strategy |
| "I'll just rerun it if it fails" | Rerunning from zero against a live API/prod system re-does the expensive/rate-limited part and risks side effects on the parts that already succeeded |
| "I'll add checkpointing once it's proven slow" | By the time it's proven slow, it's usually already run once, uncheckpointed, and lost its output on a failure — that's the actual origin story of this rule |

## 4. Observability — worked example

**Run summary, concretely:**

```
Scanned:    1,204
Eligible:     312
Succeeded:    298
Failed:        14
Failure log: /tmp/sweep-2026-08-10-failures.jsonl
```

**Skip vs. abort, concretely.** In a batch loop, distinguish "this one item is
bad, log it and continue" from "the whole run is compromised, stop now":

```python
for target in targets:
    try:
        result = process_target(target, config)
    except TransientError as e:
        log_decision(f"retrying {target.id}: {e}")
        continue  # retry logic, or skip-and-count-as-failed
    except SchemaError as e:
        # one bad record doesn't invalidate the other 1,203 — skip it
        failures.append((target.id, str(e)))
        continue
    except AuthError:
        # every subsequent call will fail the same way — stop, don't burn through the list
        log_decision(f"aborting run: {e}")
        sys.exit(1)
```

## 5. Config precedence — worked example

```python
config = DEFAULTS.copy()
config.update(load_config_file(args.config))       # file overrides defaults
config.update({k: v for k, v in os.environ.items()  # env overrides file
               if k.startswith('SWEEP_')})
config.update(vars(args))                            # explicit CLI wins
```

Secrets (API keys, tokens) live in env vars regardless of this precedence —
they never belong in a config file that might get committed.

## 6. Architecture

Keep `run(config) -> Result` callable without going through `argv` — that's
what makes the domain logic testable and reusable from a notebook or another
script:

```python
def run(config: Config) -> RunResult:
    targets = find_targets(config)
    return RunResult(process(t, config) for t in targets)

def main():
    args = parse_args()
    config = build_config(args)
    result = run(config)
    print_summary(result)
    sys.exit(0 if result.ok else 1)
```
