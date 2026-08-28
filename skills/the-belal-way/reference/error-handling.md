# Error Handling

- **Never swallow errors** — no empty catches, no `catch` without re-throw or typed handling, no silently ignored rejected promises.
- **Typed errors** — never throw raw strings; use custom Error subclasses or discriminated union result types so callers can handle failures exhaustively.
