---
name: using-rg
description: Use when searching, grepping, or filtering text/code from the command line — a single file, a codebase, logs, or any file tree — in place of grep (single-file or recursive), find -exec grep, or ugrep.
---

# Using rg

## Overview

ripgrep (`rg`) is a fast text search tool that respects `.gitignore` by default and handles single-file and recursive search equally well. Prefer it over plain `grep`, `grep -r`, `find -exec grep`, and `ugrep` — even for a single file, rg's saner defaults (smart case, colored output, PCRE2 support) make it worth the reach; `ugrep` in particular can also balloon memory usage on large trees, where `rg` stays fast and lean.

## When to Use

- Searching a codebase or log tree for a symbol, string, or pattern
- Filtering by file type or glob before/while searching
- Needing context lines around a match
- Getting just filenames or match counts for scripting (`-l`, `-c`)
- Multiline pattern search
- Deliberately searching hidden or gitignored files

Don't reach for it for in-place file editing (`rg -r` only rewrites what it prints, not the file) — use `sed`/`sd` for that.

## Quick Reference

| Task | rg |
|---|---|
| Basic search | `rg 'pattern'` |
| Case-insensitive | `rg -i 'pattern'` |
| Fixed string (no regex) | `rg -F 'literal'` |
| Search a specific path | `rg 'pattern' path/` |
| Filter by file type | `rg -t py 'pattern'` |
| List known types | `rg --type-list` |
| Filter by glob | `rg -g '*.ts' 'pattern'` |
| Exclude glob | `rg -g '!*.test.ts' 'pattern'` |
| Files with matches only | `rg -l 'pattern'` |
| Count matches per file | `rg -c 'pattern'` |
| Context lines (before/after) | `rg -B2 -A2 'pattern'` |
| Context lines (both) | `rg -C3 'pattern'` |
| Whole word only | `rg -w 'pattern'` |
| Multiline pattern | `rg -U 'foo\nbar'` |
| Include hidden files | `rg --hidden 'pattern'` |
| Include gitignored files too | `rg --hidden --no-ignore 'pattern'` (or `rg -uu`) |
| Preview a replacement (no file write) | `rg 'old' -r 'new'` |
| JSON output for scripting | `rg --json 'pattern'` |
| PCRE2 (lookaround, backrefs) | `rg -P 'pattern'` |
| Just list matching filenames | `rg --files -g 'glob'` |

## Core Patterns

**Combine type and glob filters:**
```bash
rg -t ts -g '!*.test.ts' 'useEffect'
```

**Pipe filenames into another tool:**
```bash
rg -l 'TODO' | xargs -I{} code {}
```

**Search past `.gitignore` when you actually need to (e.g. a build output or vendored dir):**
```bash
rg --hidden --no-ignore 'pattern' dist/
```

**Preview a rename across a codebase before committing to a real edit:**
```bash
rg 'oldName' -r 'newName'   # prints what WOULD change; does not touch files
```

## Common Mistakes

- **Expecting `-r` to edit files in place** — it only rewrites matched text in the printed output, not the files on disk. Use `sed -i` or `sd` for actual in-place replacement.
- **"No results" that's actually gitignore** — rg skips `.gitignore`d and hidden files by default. If a file you know exists isn't matching, add `--hidden --no-ignore` (or `-uu`).
- **Greedy regex for literal text** — `rg -F 'foo.bar()'` is simpler and faster than escaping `.()` in a regex when the string is fixed.
- **Unquoted patterns** — the shell will glob-expand or word-split an unquoted pattern; always quote it.
- **Reaching for `find -exec grep` or `ugrep`** — `rg` does recursive multi-file search natively, faster, and respects ignore files; `ugrep` in particular is prone to high memory use on large trees.
- **Reaching for plain `grep` on a single file "since it's just one file"** — `rg` works the same on one file as on a tree, with better defaults (smart case, colors, PCRE2 via `-P`); default to it regardless of file count.

Full manual: `rg --help`, `man rg`, or https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md
