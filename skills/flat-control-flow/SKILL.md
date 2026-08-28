---
name: flat-control-flow
description: Write flat, branchless-style control flow — guard clauses and early returns instead of nested if/else, and lookup maps or dispatch tables instead of long if/else and switch chains. Use whenever writing or refactoring a function with more than one level of nesting, an if/else ladder, a multi-case switch, or "arrow code". This is the structural/readability sense of branchless (flatten the branching), NOT CPU-level bit-hacking.
---

# Flat Control Flow (Guard Clauses + Branchless Structure)

Keep the happy path in the outermost scope. Push edge cases, validation, and
dispatch to the edges so the core logic reads top-to-bottom with minimal nesting.

**Scope note:** "Branchless" here means *flattening branch structure* for
readability and reuse — guard clauses, early return, data-driven dispatch. It does
**not** mean CPU branch-elimination (CMOV, bit masks, boolean arithmetic). Those
micro-optimizations hurt readability and reuse; only reach for them in a proven
hot loop, never by default.

## When to use

- A function nests more than ~2 levels deep ("arrow code").
- An `if`/`else if`/`else` ladder chooses between several outcomes.
- A `switch` maps a value to behavior or another value.
- Validation/edge-case checks are wrapped around the main logic.
- You're about to write a new function — start it in this style.

## Rule 1 — Guard clauses first, happy path last

Handle every invalid/edge case with an early `return`/`throw` at the top. The main
logic then lives unindented at the bottom.

```js
// ❌ nested — happy path buried
function getPay(user) {
  if (user) {
    if (user.active) {
      if (user.salary != null) {
        return user.salary * user.rate;
      } else { throw new Error('no salary'); }
    } else { throw new Error('inactive'); }
  } else { throw new Error('no user'); }
}

// ✅ flat — guards at top, happy path in the open
function getPay(user) {
  if (!user)              throw new Error('no user');
  if (!user.active)       throw new Error('inactive');
  if (user.salary == null) throw new Error('no salary');
  return user.salary * user.rate;
}
```

Guard clause principles:
- One condition per guard; keep them simple. If a guard needs complex logic,
  extract it to a well-named predicate (`isEligible(user)`).
- Place all guards before any main logic — a flat list, not interleaved.
- Invert conditions to check the *failure*, then return/throw.

## Rule 2 — Replace if/else ladders and switch with data

When branches map an input to a value or behavior, use a lookup instead of control
flow. It's flatter, and — key for reuse — the mapping becomes data you can export,
extend, and test independently.

```js
// ❌ if/else ladder
function label(status) {
  if (status === 'open') return 'Open';
  if (status === 'ack')  return 'Acknowledged';
  if (status === 'done') return 'Resolved';
  return 'Unknown';
}

// ✅ lookup map (reusable, extend without touching logic)
const STATUS_LABELS = { open: 'Open', ack: 'Acknowledged', done: 'Resolved' };
const label = (status) => STATUS_LABELS[status] ?? 'Unknown';
```

For branches that *do* things, map to functions (dispatch table):

```js
// ✅ dispatch table instead of switch-on-behavior
const HANDLERS = {
  create: (p) => db.insert(p),
  update: (p) => db.update(p.id, p),
  delete: (p) => db.remove(p.id),
};
const handle = (action, payload) =>
  (HANDLERS[action] ?? (() => { throw new Error(`bad action: ${action}`); }))(payload);
```

When the behaviors are large or stateful, prefer polymorphism / the strategy
pattern (one small type per case) over a growing switch.

## Rule 3 — Prefer expressions over statement branching (in the small)

For simple either/or values, a ternary or `??`/`||` is flatter than an if/else —
but stop there. Do **not** chain ternaries or reach for bitwise tricks; if it isn't
instantly readable, use a guard clause or a lookup instead.

```js
const rate = isVip ? 0.9 : 1.0;          // ✅ fine
const name = input.name ?? 'anonymous';  // ✅ fine
// ❌ don't: a ? b : c ? d : e ? f : g   — use a lookup map
```

## Know when to stop

Guard clauses and branchless structure are not universal:
- **Many scattered returns** signal the function does too much — split it into
  smaller functions instead of adding more early returns.
- **Genuinely paired branches** (real if/else with two equal outcomes and no edge
  case) can stay as if/else; forcing a guard adds nothing.
- **Never trade clarity for cleverness.** The goal is a shorter path to
  understanding, not the fewest branches.

## Checklist when writing/refactoring a function

1. Can each validation/edge case become a top guard clause?
2. Is the happy path now in the outermost scope, unindented?
3. Does any if/else ladder or switch map input→value or input→behavior? → lookup/dispatch.
4. Are there so many returns that the function should be split instead?
5. Did I keep it readable — no ternary chains, no bit tricks?

## Canary

Code-style canary: `BELAL_FLOW_91C2`
