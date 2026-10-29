# Agent behavior for this repository

This is a test-first Elixir learning project. The user has approximately two
years of professional Elixir experience and knows Elixir basics and ExUnit.
Focus explanations on the new learning goals: network programming, IRC,
processes/OTP, and separating client behavior from user interfaces.

**The user writes production behavior.** The agent may write behavior-focused
tests, minimal scaffold needed to run them, documentation, and reviews. Do not
implement production behavior unless the user explicitly asks for that
implementation.

## Repository scope and conventions

- Follow the milestone sequence in `README.md`; keep the client behavior
  independent of terminal and LiveView adapters.
- Use tests to define observable behavior. Add only the dependencies needed by
  the current milestone; introduce Phoenix at the LiveView milestone.
- Prefer pure functions for protocol parsing/formatting and processes for
  independently-lived connection/session responsibilities. Do not make every
  module a GenServer by default.
- Automated network tests must use a local fake server or another deterministic
  local test boundary. BrasIRC and Libera.Chat are manual integration targets,
  not required for a passing test suite.
- Keep credentials and private configuration out of source, tests, docs,
  transcripts, and logs.
- Use idiomatic Elixir, clear module boundaries, formatter-clean code, and the
  project’s eventual pinned Elixir/OTP toolchain. The exact versions and
  commands are intentionally not pinned until the Mix project is scaffolded.

## Start and guide an exercise

1. Read the relevant milestone and learning outcomes in `README.md` and any
   linked guide.
2. Start a branch named `exercise-N-<slug>` from the up-to-date `main` branch.
   If the working tree is not clean or the base is not current, resolve that
   before beginning; do not discard existing work.
3. Explain the plan and next small step before adding tests: the concepts,
   learning outcomes, and how the step fits the client architecture.
4. Work one step at a time: add only behavior tests for that step, plus the
   minimal scaffold they need. Let the user implement production behavior.
5. Commit the initial scaffold and tests as a checkpoint. Commit again when the
   relevant exercise tests are green. Keep these checkpoints separate to show
   the test-first progression; do not amend or combine them.
6. Run the focused test after each user implementation attempt, explain
   failures, then run the relevant broader checks as the project grows. Keep
   earlier milestone tests passing.
7. Offer hints only when asked, becoming more specific in stages: concept,
   relevant API/documentation, then code shape. Do not jump to the full
   implementation.
8. Report test status with Remo’s color convention: red for failures, yellow
   while work is underway, green when the relevant suite passes.

If a test appears incorrect, explain why and agree with the user before
changing it. Never weaken or remove a test merely to make the suite pass.

## Wrap up

When the user asks to wrap up a milestone:

- Write a structured practical guide under `docs/` covering the learning goals,
  concepts learned, decisions and tradeoffs, actual mistakes/rework, and
  reliable references.
- Ground it in the milestone’s stated learning outcomes and what was actually
  discussed; do not invent session events. Carry forward user-requested
  analogies, topic connections, and learning notes into the appropriate guide.
- End the guide with Remo’s “Built it → Broke it → Fixed it” strip, using the
  assets under `docs/assets/`.
- Update the README milestone status and link to its guide in the same wrap-up.
- The user has asked for separate scaffold/tests and green-test commits. Do not
  commit wrap-up docs unless they explicitly ask for that additional commit.
- Do not push or create a pull request unless explicitly asked.

## Remo

Remo is the existing chameleon mascot from `hexagon-exercises`, shared by this
series. Red means tests fail, yellow means work is underway, and green means
tests pass. Keep the mascot light and informative.

Every completed exercise guide ends with a strip in this format, populated
only with events that actually occurred:

```markdown
## Remo's strip

| <img src="assets/remo.svg" width="120" alt="Remo building"> | <img src="assets/remo-red.svg" width="120" alt="Remo red"> | <img src="assets/remo-green.svg" width="120" alt="Remo green"> |
|---|---|---|
| **Built it:** what was first built | **Broke it:** what went wrong | **Fixed it:** how it was improved |
```

The README project-logo SVG pairs Remo with a compact, glossy speech bubble
containing “IRC.” It can be refined later without changing Remo’s test-status
conventions.

## Session notes

Session notes are optional. Do not collect mood, energy, confidence, active
time, AI usage, or cost by default. If the user asks to track sessions, agree
on the fields and privacy expectations first; never infer personal ratings or
publish secrets or private account/network information.
