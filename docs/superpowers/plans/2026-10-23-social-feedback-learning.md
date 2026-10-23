# Social Feedback Learning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let nearby Norns learn when they observe another Norn receive Praise or Scold.

**Architecture:** Once an eligible response is recorded for the actor, roll the existing simulation RNG once per nearby observer using that observer's sociability. Noticed feedback adjusts the observer's existing object association by a bounded signed amount and creates a memory-bearing event linked to the actor's feedback event.

**Tech Stack:** Self-contained HTML, CSS, and JavaScript; no dependencies.

**Spec:** `docs/superpowers/specs/2026-10-23-social-feedback-learning-design.md`

## Global Constraints

- Keep the standalone static HTML build and local simulation.
- Reuse validated sociability, event/memory storage, and existing persistence fields.
- No automated tests may be added or run under the standing session instruction; use source inspection, JavaScript syntax validation, diff checks, review, and deployment verification.

## Review Focus

- Observer outside 330 units or actor itself: no social feedback event and no association change.
- Sociability at 0 and 1: the existing `[0, 1)` RNG boundary makes observation impossible at 0 and certain at 1.
- Noticed Praise and Scold: only the observer's matching object association changes by +0.12 or −0.12, clamped to [0, 1]; actor's ±0.2 path stays the same.
- Ineligible or duplicate feedback: the existing feedback guard prevents another event or observer roll.
- Association already at a limit: observation remains represented accurately without claiming the value changed.
- Observer event memory links to the feedback event and uses existing saved fields; no schema migration is needed.

---

### Task 1: Social learning from feedback

**Files:**
- Modify: `index.html`
- Modify: `README.md`

**Interfaces:**
- Consumes `applyPraise`, `applyScold`, `recordEvent`, `state.rng`, `state.norns`, `distance`, and existing sociability/association fields.
- Produces `shareFeedbackObservation(actor, object, feedback, feedbackEvent)` using the existing event and memory format.

- [x] Add the bounded, sociability-gated observation helper for eligible nearby observers.
- [x] Call it only after recording a valid actor feedback event; leave direct feedback eligibility and ±0.2 effects intact.
- [x] Record truthful observer text/memory, including unchanged-at-limit cases, and link it to the actor's feedback event.
- [x] Update README to explain that nearby Norns can learn from observed Praise and Scold.
- [x] Inspect distance, random boundary, duplicate-response, feedback direction/limits, linked-event, and unchanged-save paths.
- [x] Run `git diff --check` and `node --check` against the extracted inline script. Do not add or run automated tests.
- [ ] Commit implementation/docs, obtain fresh scoped review, then publish and verify the Pages response.

**Check:** Static source review, `git diff --check`, inline-script syntax validation, a fresh scoped code review, successful Pages workflow, and cache-busted HTTP verification.
