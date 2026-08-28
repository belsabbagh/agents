# Structure & Diffs

- **Modular file design** — one responsibility per file, keep files under ~200 lines; extract helpers, types, and constants into their own modules by concern, not by size.
- **Pure functions where practical** — same input → same output; no side effects in data-transformation code; isolate I/O at the boundaries.
- **Single Level of Abstraction / Composed Method** — every function should operate at one level of abstraction. If a function preprocesses its arguments before using them, extract that preprocessing into its own method. The caller prepares the data, the inner function does one thing only. See https://refactoring.guru/extract-method
- **Minimal, focused diffs** — no drive-by refactors or renames unless asked.
