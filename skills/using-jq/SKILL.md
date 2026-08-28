---
name: using-jq
description: Use when querying, filtering, transforming, or reshaping JSON from the command line — API responses, config files, log lines, or any JSON blob that needs inspecting or piping through a shell pipeline.
---

# Using jq

## Overview

jq is a command-line JSON processor: filter, map, and reshape JSON as fast as `grep`/`sed`/`awk` handle text. Prefer it over writing a Python/Node script to parse JSON.

## When to Use

- Extracting a field or list of fields from JSON output (API responses, `kubectl get -o json`, `gh api`, `docker inspect`)
- Filtering or selecting entries in an array by a condition
- Reshaping JSON into different JSON, CSV, or plain text for piping into other tools
- Merging JSON files/objects, or editing a JSON file's fields
- Building JSON from scratch or from shell variables
- Learning the shape of an unfamiliar JSON file before writing a filter against it (see below) — cheaper than reading the raw file

Don't reach for jq when the transformation needs stateful loops across unrelated documents or heavy string parsing — a short script may be clearer then.

**Before reading an unfamiliar JSON file directly (with the Read tool or `cat`), infer its schema instead** (see below). Reading a large or deeply-nested blob to figure out its field names burns context for no reason — the inferred schema gives you the same field names and structure in a fraction of the size, and you still write the actual filter with plain `jq`/`jq -r` once you know the shape. This applies doubly to files too large to fit in memory at all: check size with `ls -la file.json`, and if it's large or unknown, use `jq --stream` (below) so memory use tracks the output, not the input.

## Quick Reference

| Task | jq |
|---|---|
| Pretty-print | `jq .` |
| Extract field | `jq '.field'` |
| Extract nested | `jq '.a.b.c'` |
| Raw string (no quotes) | `jq -r '.field'` |
| One array element | `jq '.[0]'` |
| Stream all elements | `jq '.[]'` |
| Map over array | `jq 'map(.field)'` |
| Filter array | `jq '[.[] | select(.age > 30)]'` |
| Length / keys | `jq 'length'` / `jq 'keys'` |
| Build an object | `jq '{name: .user.name, id: .user.id}'` |
| Default on missing/null | `jq '.field // "default"'` |
| Compact output | `jq -c .` |
| Slurp multiple docs into an array | `jq -s .` |
| Sort / group / dedupe by field | `jq 'sort_by(.f)'` / `jq 'group_by(.f)'` / `jq 'unique_by(.f)'` |
| Merge two objects (deep) | `jq -s '.[0] * .[1]' a.json b.json` |
| Top N by field | `jq '[sort_by(.rating) | reverse | .[:5]]'` |
| Count per group | `jq 'group_by(.cat) | map({cat: .[0].cat, n: length})'` |
| Array → NDJSON (one line each) | `jq -c '.[]'` |
| Current time / format timestamp | `jq -n 'now'` / `jq -r '.ts | strftime("%Y-%m-%d")'` |
| CSV / TSV output | `jq -r '[.a,.b] | @csv'` / `@tsv` |
| Inject a shell string var | `jq --arg v "$V" '.name = $v'` |
| Inject a shell JSON/number var | `jq --argjson n "$N" '.count = $n'` |
| Build JSON with no input | `jq -n '{a:1,b:2}'` |
| Exit non-zero if result is false/null | `jq -e '.ok'` |

## Core Patterns

**Filter + project:**
```bash
curl -s "$URL" | jq '[.items[] | select(.status == "active") | {id, name}]'
```

**Inject shell variables safely — never string-interpolate into the filter:**
```bash
jq --arg key "$KEY" '.[$key]' data.json
```

**Update a field and write back (edit-in-place needs a temp file):**
```bash
jq --arg v "$NEW_VERSION" '.version = $v' package.json > tmp.json && mv tmp.json package.json
```

**Array of objects → TSV for a shell loop:**
```bash
jq -r '.[] | [.id, .name] | @tsv' data.json | while IFS=$'\t' read -r id name; do ...; done
```

**Combine multiple JSON files:**
```bash
jq -s 'add' *.json                   # concat if inputs are arrays
jq -s '.[0] * .[1]' a.json b.json    # deep-merge two objects
```

## Unfamiliar or Large JSON: Infer the Schema First

Two separate reasons to reach for this, either one is enough on its own:

1. **Context economy.** Reading a whole JSON file just to learn its field names wastes context on data you're about to discard — you only needed the shape, not the values. Infer the schema instead, read that (it's tiny), then write the real `jq` filter against the actual file.
2. **Memory.** Plain `jq '...' file.json` parses the whole document into memory before filtering. For a large file (tens of MB+) that can exhaust memory or stall. `jq --stream` emits `[path, leaf-value]` events incrementally instead, so memory use tracks what you keep, not the input size.

**Infer the structure of a JSON file without reading or loading it whole:**
```bash
jq --stream -n -f scripts/infer-schema.jq file.json > schema.json
```
(`scripts/` is relative to this skill's own directory, wherever the skill is installed.)

This merges schemas across every array element (numeric indexes collapse into a single `items` schema) and unions types seen for the same field (e.g. a field that's sometimes `null`, sometimes `string` → `"type": ["null", "string"]`). It's a **structural** inference, not full JSON Schema — no `required`, `enum`, `const`, string formats, or min/max bounds. Good enough to know what fields exist and how they nest before writing a real filter.

## Common Mistakes

- **String-interpolating shell vars into the filter** (`jq ".[\"$KEY\"]"`) breaks on special characters and is an injection risk. Use `--arg`/`--argjson`.
- **Forgetting `-r`** leaves output JSON-quoted (`"value"`), which breaks downstream string use.
- **Missing `-s` (slurp)** when the input is multiple JSON documents (e.g. one per line) but the filter expects a single array — `.[]` only sees the first document.
- **Chaining `.a.b.c` through a possibly-null `.a`** crashes. Use `.a.b.c? // default` or `.a?.b?.c`.
- **Editing in place with a single `>`** (`jq '...' file.json > file.json`) truncates the file to empty before jq reads it. Always write to a temp file, then `mv`.

Full manual: `man jq`, `jq --help`, or https://jqlang.org/manual/
