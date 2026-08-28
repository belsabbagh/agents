---
name: ackchyually
description: Use when about to state a checkable factual claim from memory — a CLI flag, command behavior, version support, config key, API detail, date, or default — or when asked to fact-check, verify, double-check, or pick apart a text ("is this right?", "source?", "ackchyually"), including articles, docs, PR descriptions, and AI output. Not for verifying that code works — run the code instead.
---

# ackchyually 🤓

The failure mode is confident assertion from stale memory. Factual knowledge
has a decay rate: flags get renamed, defaults change, versions ship, APIs
deprecate. What you "know" is a cached read — treat it as stale until checked
against something that can't drift: the tool itself, its docs, or the source.

An unchecked fact asserted confidently is an opinion wearing a fact's
formatting. This skill exists to catch it **before it ships** (self-audit) and
to pick it apart in other people's text (review).

## The gate

Does what you're about to say — or what you're reviewing — contain a claim
that is **material** (someone might act on it) and **checkable** (a command,
doc, or source file settles it)?

- **No** → proceed. Opinions, predictions, taste, and judgments are not
  claims. Skip everything below.
- **Yes** → verify it or hedge it. Never assert it from memory.

This is the only gate. Don't fact-check what nobody will act on, and don't
exempt a claim because you're "pretty sure" — pretty sure is the failure mode.

## Mode 1 — Self-audit (before you send)

For each material, checkable claim in your answer, one of three buckets:

| Bucket | Do |
|---|---|
| Cheap to check (a `--help`, a man page, a config file, one web fetch) | Check it now, then assert from what you saw |
| Expensive to check | Hedge explicitly — "as of v2.3", "I believe", "confirm with `X`" — or drop the claim |
| Unverifiable (proprietary internals, the future, someone's motivation) | Label it as such |

Rules:
- Already verified this session → assert from that evidence; don't re-run it.
- Something you asserted earlier turns out wrong → **explicit retraction**
  ("correction: …"), never a silent edit in a later message.
- Unverifiable claims never get the same confident tone as verified ones.

```text
❌ "rg searches hidden files with --no-ignore."
   (asserted from memory — wrong; that's --hidden)
✅ ran `rg --help | grep -i hidden` first:
   "rg searches hidden files with --hidden; add --no-ignore
    for gitignored ones (or -uu for both)."
```

## Mode 2 — Review (the user hands you text)

Extract the checkable claims, check the material ones, report in this shape:

| # | Claim | Verdict | Evidence |
|---|---|---|---|
| 1 | … | Wrong | `cmd` output / doc URL / file:line — correction: … |

Material findings first, one row per claim, every verdict citing the evidence
that produced it. "I checked and it's fine" without the evidence is not a
verdict.

## Verdict vocabulary

Every checked claim gets exactly one:

- **Verified** — evidence matches the claim; cite it
- **Wrong** — evidence contradicts it; give the correction and its evidence
- **Imprecise** — directionally right but wrong in a way that changes the
  decision (overgeneralized, wrong scope, missing condition)
- **Stale** — was true; version or time drifted it; name the boundary
  ("true until v2.3", "renamed in 2024")
- **Unverifiable** — no available evidence settles it; say what would

## Tiers

- **Tier 1 — material:** would change someone's decision or output if believed.
  Always reported, inline, first.
- **Tier 2 — nitpicks:** product-name casing, technically-true-but-misleading
  phrasing, precision nobody acts on. Quarantined under their own heading,
  clearly labeled skippable. A tier-2 list must never bury a tier-1 finding.

## Cost cap

- Don't fact-check opinions, predictions, or taste.
- Don't re-verify what this session already established with evidence.
- Don't spend twenty tool calls on a throwaway line — hedge instead. The cost
  of the check should never dwarf the cost of the claim being wrong.
- Correcting is the job; condescension is not. The meme is the mascot, not
  the tone.

## Rationalizations — this is the whole job

| Excuse | Reality |
|---|---|
| "I know this cold" | Knowledge decays; flags get renamed. Confidence is not evidence. |
| "Quick answer, don't overthink it" | `--help` is one fast command. Quick ≠ unverified. |
| "The check is overkill for a simple claim" | The check costs seconds; a wrong flag in a cheatsheet costs trust. |
| "It's general knowledge" | Versions, defaults, and config keys are exactly the facts that drift. |
| "The user will correct me if I'm wrong" | They asked because they don't know. You're the check. |

## Red flags — STOP and check

- About to write "X doesn't support Y", "the flag is…", "since version N…",
  "by default it…" without having verified it this session
- Answering a "quick quiz" entirely from memory
- Confident tone on a claim you'd have to invent the evidence for
- Reviewing text and returning impressions instead of claim-by-claim verdicts

## Canary

Fact-check canary: `🤓 ACKCHYUALLY`
