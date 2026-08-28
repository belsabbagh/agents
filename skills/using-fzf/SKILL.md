---
name: using-fzf
description: Use when building an interactive fuzzy-picker command (files, branches, history, processes) for the user to run, or when fuzzy-filtering a list of lines non-interactively from a script.
---

# Using fzf

## Overview

fzf is a general-purpose fuzzy finder for the command line. Piping a list into `fzf` normally opens an interactive TUI picker — but `fzf --filter` runs the same fuzzy-match scoring non-interactively, so it's scriptable too. Since an agent's Bash tool has no TTY, most fzf usage here is one of two things: (1) writing an interactive one-liner for the user to run themselves, or (2) using `--filter` to fuzzy-match a list programmatically.

## When to Use

- Building a `cmd | fzf` interactive picker for the user (files, branches, PRs, processes, shell history)
- Fuzzy-filtering a list of lines non-interactively in a script (`fzf --filter`)
- Fuzzy-matching against a messy list (typos, partial names) instead of hand-rolled regex heuristics
- Multi-select workflows (`-m`) for the user to pick several items at once
- Preview panes (`--preview`) so the user can see file/diff content while picking

Don't reach for fzf when a tool already does exact/glob filtering — `rg -g`, `find -name`, `grep` — fuzzy matching is for imprecise/human input, not exact patterns.

## Quick Reference

| Task | fzf |
|---|---|
| Interactive picker over a list | `cmd \| fzf` |
| Non-interactive fuzzy filter | `cmd \| fzf --filter 'query'` |
| Multi-select (Tab to mark) | `cmd \| fzf -m` |
| Pre-fill the query | `cmd \| fzf --query 'partial'` |
| Exact substring match (no fuzzy scoring) | `cmd \| fzf --exact` |
| Preview pane | `cmd \| fzf --preview 'cat {}'` |
| Compact reverse layout | `fzf --height 40% --layout=reverse` |
| Pick a file, open in `$EDITOR` | `f=$(fzf) && ${EDITOR:-vim} "$f"` |
| Fuzzy pick a git branch | `git branch \| fzf` |
| Fuzzy search shell history | `history \| fzf` (or bind to Ctrl-R via shell integration) |
| Fuzzy pick a running process, get PID | `ps aux \| fzf \| awk '{print $2}'` |
| Feed the pick into another command | `cmd \| fzf \| xargs -I{} <tool> {}` |
| Case-sensitive match | `fzf +i` |
| NUL-delimited input (safe with spaces/newlines) | `find . -print0 \| fzf --read0` |

## Core Patterns

**Non-interactive fuzzy filter — the only fzf mode safe to run standalone from a script/Bash tool:**
```bash
printf '%s\n' "${candidates[@]}" | fzf --filter 'partial-query'
```
Scores every line and prints matches in ranked order; no TUI, no TTY needed.

**Hand the user an interactive one-liner instead of trying to drive the TUI:**
```bash
git branch --all | fzf
```
Tell the user to run this themselves — the picker needs a TTY the Bash tool doesn't have.

**Combine with another tool for the candidate list:**
```bash
rg --files | fzf --filter 'controller'
```

**Multi-select to build a batch command:**
```bash
files=$(fzf -m < filelist.txt)
```

## Common Mistakes

- **Running plain `fzf` (no `--filter`) from a non-interactive shell** — it blocks waiting for a TTY that isn't there, or errors out. Use `--filter` for scripted use, or hand the interactive command to the user.
- **Treating `--filter` like grep** — it's fuzzy-scored and ranked, not substring matching; add `--exact` if literal substring matching is what's actually needed.
- **Not quoting the filter query** — same shell-splitting risk as any other CLI argument.
- **Piping filenames with spaces/newlines through a plain `|`** — use `-print0`/`--read0` for NUL-delimited input when filenames aren't simple.
- **Assuming fzf is installed** — unlike `jq`/`rg` it's less universally preinstalled; check with `command -v fzf` before relying on it in a script for the user.

Full manual: `man fzf`, `fzf --help`, or https://github.com/junegunn/fzf
