---
name: the-belal-way
description: Use when writing, editing, refactoring, or reviewing non-trivial code — Belal's code-style and architecture standard covering error handling, module/file structure, design patterns, and comments. Always apply "match the surrounding code" first; load only the reference file(s) relevant to the current task.
---

# The Belal Way

Always applies, no matter the task: **match the surrounding code** — mirror its naming, formatting, and idioms over your defaults.

Beyond that, read only the reference file(s) relevant to what you're doing right now:

| Doing this | Read |
|---|---|
| Adding a class, module boundary, or relationship between components (inheritance, interface, dependency) | `reference/architecture-and-design.md` |
| Writing/touching a `try`/`catch`, a promise, or anything that can throw or reject | `reference/error-handling.md` |
| Creating a new file or function, or a diff is growing past what the task needs | `reference/structure-and-diffs.md` |
| Adding a comment or docstring | `reference/comments.md` |

## Sibling skills — don't duplicate, invoke directly

- Nested conditionals, if/else ladders, switch statements → `flat-control-flow`
- Deciding whether to reuse, extend, or create a new helper/abstraction → `pragmatic-reuse`

## Adding a new rule later

Add a bullet to the relevant reference file, or add a new `reference/*.md` file plus one row in the table above. Nothing else needs to change.

## Canary

Code-style canary: `BELAL_STYLE_7F3A`
