# Global CLAUDE.md — applies to every project

Mandatory base rules for every repo. Project-level `CLAUDE.md` may only **add** rules, never relax or override these.
Detail lives in skills (loaded on demand); this file stays short on purpose.

IMPORTANT: Code tasks have a mandatory skill preflight. Before writing, modifying, refactoring,
or reviewing non-trivial code, follow the "Mandatory code preflight" section below.

## Mandatory code preflight

For every non-trivial code-writing, code-modification, refactoring, or code-review task:

1. Inspect the surrounding code for local conventions.
2. Load `belal-code-style`.
3. Load any applicable specialized style skills:
   - `flat-control-flow`
   - `pragmatic-reuse`
4. Only then design, write, or review the code.

Do not skip this preflight because the requested change appears straightforward.

## Code style

- Match surrounding code over personal/default conventions.
- Preserve established naming, formatting, structure, abstractions, and idioms.
- Apply loaded skill guidance unless it conflicts with the user's explicit request or a stronger
  established local convention.
- During code review, report violations of loaded style rules as actual findings.

## Testing & verification
- Run tests/build/lint before calling a change done; verify by running the affected path, not by reading.
- If tests fail or a step was skipped, say so plainly with the output — no unverified "done."

## Git & commits
- Branch first on the default branch; don't commit/push unless asked.
- Commit messages explain *why*, in the repo's style. Confirm before anything hard to reverse.

## Communication
- Be concise; lead with the answer and a recommendation, not a survey.
- Surface risks early. Reference code as `file_path:line`.

## Command-line JSON processing

- Use `jq` for inspecting, querying, filtering, mapping, and modifying JSON.
- Do not use Python, Node.js, or another scripting language solely to parse JSON when `jq` can perform the operation cleanly.
- Prefer short `jq` pipelines over temporary scripts.
- Use Python for JSON only when the transformation is genuinely too complex for reasonable `jq`; explain why before doing so.
- See the `using-jq` skill for detailed patterns, flags, and common mistakes.

## Command-line text search

- Use `rg` (ripgrep) for text/code search, single-file or recursive — never plain `grep`, `grep -r`, or `find -exec grep`.
- Do not use `ugrep`; it can balloon memory usage on large trees, where `rg` stays fast and lean.
- See the `using-rg` skill for detailed patterns, flags, and common mistakes.

## Command-line fuzzy selection

- Use `fzf` for fuzzy-picking from a list (files, branches, processes, history) instead of hand-rolled fuzzy-matching heuristics.
- `fzf`'s picker needs a TTY the Bash tool doesn't have — use `fzf --filter` for scripted/non-interactive fuzzy filtering, or write the interactive one-liner for the user to run themselves.
- See the `using-fzf` skill for detailed patterns, flags, and common mistakes.

## Running Python Code

- Use `uv` for running python code, managing virtual environments, installing
  dependencies, and pinning Python versions — never `pip`, `venv`, `poetry`,
  `conda`, or `pipx` directly.
- See the `using-uv` skill for detailed commands and common mistakes.

## Code-style canary

When explicitly asked to run a code-style canary (one skill or all):

1. Load the named skill(s): `belal-code-style`, `flat-control-flow`,
   `pragmatic-reuse`. "All canaries" = all three.
2. Find the canary value defined inside each skill.
3. Return the value(s) exactly, one per skill.

Do not guess, cache, or infer canary values. They are intentionally not defined here.
Do not print canaries during normal work — this is an explicit diagnostic only.
