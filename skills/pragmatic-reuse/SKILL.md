---
name: pragmatic-reuse
description: Write reusable code without over-engineering — search for existing logic before adding new, extract on real (not anticipated) duplication, apply the reuse-relevant parts of SOLID (single responsibility, dependency inversion, composition over inheritance) pragmatically, and stop before abstraction costs more than it saves. Use when adding a function/helper/class/module, when you notice repeated logic, or when deciding whether to introduce an abstraction.
---

# Pragmatic Reuse

Maximize reuse of *readable* code. Reuse comes from small, single-purpose,
loosely-coupled units — not from speculative frameworks. Apply SOLID where it earns
its keep; ignore it where it just adds layers.

## Rule 1 — Reuse before you create

Before writing any new function/helper/util/type, search the repo for something that
already does it (or 80% of it). Then decide, in order:

1. **Reuse** it as-is.
2. **Extend** it (add a parameter, generalize slightly) if the change is clean.
3. **Consolidate** — if you find two near-duplicates, merge them while you're here.
4. **Create** only if none of the above fit.

A second copy of logic is a smell; a third is a bug waiting to happen.

## Rule 2 — Extract on real duplication, not anticipated duplication

- **Rule of three:** the first time, write it inline. The second, note the dup. The
  third, extract. Two similar-looking blocks that may diverge are often better left
  separate (false DRY couples unrelated things).
- Extract when the duplicated logic is *the same decision* in multiple places —
  change it once, it changes everywhere correctly.
- Don't extract when the blocks merely *look* alike but answer different questions;
  coupling them forces future conditionals into the shared helper.

## Rule 3 — Single Responsibility = the unit of reuse

A function/module you can name precisely ("parses X", "validates Y") is reusable;
one named "handleStuff" is not. Keep units small and cohesive:
- One reason to change per unit.
- Separate **pure logic** (compute, transform, decide) from **I/O and side effects**
  (network, disk, DB, DOM). Pure functions are the most reusable and testable code
  you can write — push logic into them, keep the shell thin.

## Rule 4 — Depend on abstractions at real seams (DIP), not everywhere

Invert a dependency only where it buys something concrete: swapping an
implementation, testing without the real thing, or crossing a module boundary.

```js
// ✅ inject the seam that actually varies / needs mocking
function makeReport(fetchRows) {           // fetchRows is the seam
  return format(summarize(fetchRows()));
}
// ❌ don't wrap every concrete call in an interface "for flexibility"
```

Signs you've gone too far: interfaces with one implementation and no test double,
factories that only ever build one thing, config for things that never vary.

## Rule 5 — Composition over inheritance

Reuse by combining small pieces (functions, objects, higher-order functions), not by
deep class hierarchies. Inheritance couples subclasses to a base's internals;
composition lets each piece be reused independently. Reach for inheritance only for a
true, stable "is-a" with shared substitutable behavior.

## Rule 6 — Stop before the abstraction costs more than the duplication

Every abstraction has a carrying cost: a name to learn, indirection to trace, a
contract to keep. It pays off only when reused enough to amortize that cost.
- Prefer a little duplication over the *wrong* abstraction — a wrong abstraction is
  far more expensive to undo than a copy is to dedupe later.
- Don't add generality, config, or layers for hypothetical futures (YAGNI).
- If explaining the abstraction takes longer than the code it replaces, inline it.

## Checklist before adding code

1. Did I search for existing logic and choose reuse/extend/consolidate/create?
2. Is this the *third* occurrence, or am I extracting prematurely?
3. Can I name the unit by its single job? Is pure logic separated from I/O?
4. If I added an interface/injection/base class — does it wrap a *real* varying seam?
5. Is the abstraction reused enough to pay for its indirection, or should it stay inline?

## Canary

Code-style canary: `BELAL_REUSE_A63B`
