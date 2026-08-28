---
name: using-uv
description: Use when running Python code, managing virtual environments, installing dependencies, pinning a Python version, or running a Python-based CLI tool — any task that would otherwise reach for pip, venv, poetry, conda, or pipx.
---

# Using uv

## Overview

uv is a single fast binary that replaces pip, venv, virtualenv, poetry, pipx, and pyenv. Prefer it over any of those directly — one tool, one lockfile format, no separate venv-activation step for routine runs.

## When to Use

- Running a Python script or one-off snippet
- Creating/using a virtual environment for a project
- Adding, removing, or syncing project dependencies
- Running a Python CLI tool (formatter, linter, generator) without polluting the project env
- Pinning or installing a specific Python interpreter version
- Initializing a new Python project

Don't reach for uv when there's no Python involved — it's a Python toolchain replacement, not a general task runner.

## Quick Reference

| Task | uv |
|---|---|
| Run a script (auto-creates/uses `.venv`) | `uv run script.py` |
| Run with inline deps, no project needed | `uv run --with requests script.py` |
| Start a new project | `uv init` |
| Create a venv manually | `uv venv` |
| Add a dependency | `uv add requests` |
| Add a dev-only dependency | `uv add --dev pytest` |
| Remove a dependency | `uv remove requests` |
| Install deps from lockfile | `uv sync` |
| Regenerate the lockfile | `uv lock` |
| Install into current env like `pip install` | `uv pip install requests` |
| Run a Python-based CLI tool once, isolated | `uvx ruff check .` |
| Install a CLI tool persistently | `uv tool install ruff` |
| Install/pin a Python version | `uv python install 3.12` / `uv python pin 3.12` |
| List available/installed Python versions | `uv python list` |
| Build a package | `uv build` |
| Publish a package | `uv publish` |

## Core Patterns

**One-off script, no project setup:**
```bash
uv run script.py
```

**Script needing a dependency not in any project:**
```bash
uv run --with pandas analyze.py
```

**Project workflow — add a dep, then run:**
```bash
uv add requests
uv run main.py
```

**Reproducible install from an existing lockfile (CI, fresh clone):**
```bash
uv sync
```

**Run a formatter/linter without adding it to the project's deps:**
```bash
uvx black .
```

**Pin the interpreter version for a project:**
```bash
uv python pin 3.12
```

## Common Mistakes

- **Calling `pip install` / `python -m venv` / `poetry add` directly** — uv replaces all of these; mixing them creates two sources of truth for the environment.
- **Forgetting `uv run`** and invoking `python script.py` directly — this uses whatever interpreter is on `PATH`, not the project's pinned venv/version.
- **`uv pip install` for project dependencies** — that mutates the environment without touching `pyproject.toml`/the lockfile, so the change doesn't persist for the next `uv sync`. Use `uv add` for anything the project should track.
- **Installing a CLI tool with `uv add`** — that makes it a project dependency. Use `uvx` (one-off) or `uv tool install` (persistent) for tools you invoke, not import.
- **Assuming a venv needs manual activation** — `uv run` and `uv pip`/`uv add`/`uv sync` all target the project's `.venv` automatically; activation is rarely needed.

Full manual: `uv --help`, or https://docs.astral.sh/uv/
