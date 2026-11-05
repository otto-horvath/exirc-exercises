# Session 2.5 — Refactoring, API hardening, and the red-green-refactor cycle

This session was an interlude between Exercises 2 and 3. It did not add a new
IRC feature. It made the Exercise 2 code report failures honestly, tightened the
formatter boundary, and recorded where test-first refactoring helped.

Final state: **67 tests passed**, `mix format --check-formatted` clean, and
`mix compile --force` with no warnings.

## Starting point

Exercise 2 was merged through PR #2. The registration flow worked for the happy
path and the known server failures, but three things were still weak:

1. `Connection.send_message/2` always returned `{:ok, connection}`, even when
   `:gen_tcp.send/2` failed.
2. `Registration.register/3` sent its messages with `Enum.each` and ignored the
   send results. A failed send could therefore be reported as
   `{:error, :timeout}` instead of the real error.
3. `MessageFormatter.format/1` had duplicate `join_params/1` clauses and a
   nested `Enum.join/2` that merged invalid tail parameters. It accepted input
   that could not be written as a valid IRC line.

The refactor kept the public registration API small: `messages/1` remained the
pure builder and `register/3` remained the flow.

## What changed

### 1. Send failures became visible

`Connection.send_message/2` now returns the result of `:gen_tcp.send/2`:

- `{:ok, connection}` on a successful write;
- `{:error, reason}` on a failed write.

The first test closed the client socket and expected `{:error, :closed}`. It
failed with `{:ok, %Connection{}}`, then passed after the contract change.

### 2. Registration propagated send failures

The first regression test — registration on an already-closed connection — was
not enough. It passed both before and after the fix, because the old code also
failed later during `recv`. A discriminating test was needed.

A UDP socket provided the deterministic boundary:

- `:gen_tcp.send/2` on the UDP socket fails immediately with `:einval`;
- `:gen_tcp.recv/2` only times out.

The old flow ignored the send error and returned `{:error, :timeout}`. The fixed
flow returned `{:error, :einval}`.

The first implementation attempt used `Enum.reduce_while/3` with `0` as the
initial accumulator and switched it to the connection struct on success. The
reducer also used the outer `connection` instead of the accumulator. The result
was a bare `%Connection{}`, and 13 tests failed:

```text
left:  {:ok, %Connection{}, welcome}
right: %Connection{socket: ...}
```

The final version uses a private recursive helper:

```elixir
defp send_messages(connection, []), do: {:ok, connection}

defp send_messages(connection, [message | rest]) do
  with {:ok, connection} <- Connection.send_message(connection, message) do
    send_messages(connection, rest)
  end
end
```

`with` returns the first non-matching `{:error, reason}` unchanged. `register/3`
then decides to close the connection and return that error.

The `PING` branch reuses the same helper for the one-message `PONG` reply.
`await_welcome/2` matches the whole `{:ok, connection, %Message{...}}` tuple,
removing the nested `case`, and `close_with_error/2` centralizes the shared
close-and-return-error path.

### 3. The formatter validates before formatting

`MessageFormatter.format/1` now rejects invalid input with `ArgumentError`:

- every parameter must be a binary;
- CR, LF, and NUL are rejected anywhere;
- non-final parameters must be non-empty, contain no space, and not start with
  `:`.

Only the final parameter can be trailing. That removed the nested `Enum.join`
and the duplicate clauses entirely: invalid middle parameters are rejected
before formatting, and `format_last/1` is the only place that adds the colon.

This also closes the command-injection path before `PRIVMSG` starts carrying
user text in Exercise 4.

## Red-green-refactor timeline

| Step | Color | What happened |
| --- | --- | --- |
| Send-error test | red | Expected `{:error, :closed}`, got `{:ok, %Connection{}}` |
| Send-error contract | green | `send_message/2` returned the `:gen_tcp.send/2` result |
| Green checkpoint | green | Committed the working registration suite before refactoring |
| Propagation test | red | UDP test returned `{:error, :timeout}` instead of `{:error, :einval}` |
| First registration refactor | red | The `reduce_while/3` accumulator returned a bare connection and broke 13 tests |
| Green checkpoint | green | Fixed the result handling with the suite back at 60 tests |
| List-helper refactor | green | `send_messages/2`, `PING` reuse, flattened `await_welcome/2`, `close_with_error/2` |
| Formatter tests | red | Seven tests failed: six raised nothing, one raised `FunctionClauseError` |
| Formatter validation | green | Middle-parameter and CR/LF/NUL validation; only the last parameter is trailing |

The sequence shows both uses of test-first work:

- **tests as a specification:** the failing tests defined the send-error and
  validation contracts before the implementation;
- **tests as a safety net:** the existing suite caught the accumulator-shape
  mistake as soon as the refactor broke 13 call sites.

## Where AI helped — and where it did not

AI helped most with:

- turning the failure scenarios into behavior tests, especially the UDP-socket
  case that distinguished a propagated send error from a masked timeout;
- explaining why `with` returns the first non-matching error unchanged;
- pointing out that the `reduce_while/3` accumulator had changed shape and that
  the final `case` could never match `{:ok, connection}`;
- suggesting the API boundary: keep `Connection.send_message/2` single-message
  and put list semantics in the registration flow;
- implementing the requested registration refactor and writing the guide.

AI was less helpful in these moments:

- the first registration regression test passed before and after the fix, so it
  did not actually prove the send error was propagated;
- the `apply/3` workaround in the first test avoided a gradual-type warning but
  added noise; it was removed once `send_message/2` could return both shapes;
- the initial `reduce_while/3` suggestion led to a confusing accumulator. The
  recursive helper was easier to reason about and to match with `with`;
- the assistant’s default enthusiasm for refactoring needed the user’s
  cost/benefit check. A working, old module is not automatically worth changing.

## API improvements

The public registration API stayed deliberately small:

| Function | Role |
| --- | --- |
| `Registration.messages/1` | Pure builder for `PASS`/`NICK`/`USER` |
| `Registration.register/3` | Full registration flow over a connection |
| `Connection.send_message/2` | One message, returning `{:ok, connection}` or `{:error, reason}` |
| `MessageFormatter.format/1` | One validated wire line, or `ArgumentError` |

Private registration helpers — `send_messages/2`, `await_welcome/2`, and
`close_with_error/2` — are implementation details. Callers do not need to know
how the list is sent or how the welcome is awaited.

The important contract change is that failure is now part of the API, not an
invisible side effect. A caller can distinguish a successful send from a broken
connection without waiting for a later timeout.

## Refactoring old code: a cost/benefit note

The user observed that old, untouched code that has worked for a long time feels
less worth refactoring: a deep corner-case bug may justify it, and performance
work may justify it, but otherwise the time can be hard to defend, especially
when the code is buried and has no visible side effects.

This is a sound heuristic, close to “if it ain’t broke, don’t fix it” and
Chesterton’s fence, but it is not a universal rule:

- **Working code is evidence, not proof.** Untested paths can stay hidden for
  years. The formatter was used on every send, but only valid input was tested.
- **“Untouched” often means “unexercised.”** Absence of reported bugs is not the
  same as absence of defects.
- **Weigh risk against risk.** A small, pure module with good tests is cheap to
  change. A large, untested module with no upcoming change is a different bet.
- **Upcoming context changes the value.** Validation was low-value as a corner
  case today, but it matters before `PRIVMSG` accepts user text: it closes a
  command-injection path.
- **Understanding and testability have value**, but the work should be
  time-boxed and test-backed.
- **Performance refactors need measurement first.** Do not refactor for speed
  without evidence.

For this codebase, the formatter is small, pure, on every outbound send, and now
well covered by tests. The practical bug was low-value, but the validation
contract is high-value before Exercise 4. A large, stable module with no upcoming
change would be a candidate to leave alone.

The sharper rule: prioritize by risk and upcoming change, not by age alone.

## Mistakes and rework

- The first registration regression test could not distinguish “the send error
  was propagated” from “the send error was ignored and `recv` failed later.”
  The UDP-socket test fixed that.
- The first `reduce_while/3` refactor changed the accumulator shape and returned
  a bare `%Connection{}`; 13 tests caught it immediately.
- The `apply/3` call in the first connection test was a workaround for a
  gradual-type warning. It was removed after `send_message/2` gained a real
  error return.
- The formatter’s nested `Enum.join` silently merged invalid tail parameters.
  The proper fix was validation, not a smarter join.
- The formatter tests initially had no invalid-input coverage. Seven new tests
  exposed both the missing validation and a `FunctionClauseError` on non-binary
  parameters.

## Insights to carry forward

- **A green test can still be a weak test.** It must create the condition that
  distinguishes the bug from the fix.
- **Commit green before refactoring.** The 13-failure accident was easy to
  diagnose because the previous checkpoint was green.
- **Make failure part of the contract.** Returning `{:error, reason}` is more
  useful than reporting success and failing later.
- **Keep the public surface small.** Pure builders and flows can be public;
  sequencing and cleanup helpers can stay private.
- **Validate at the boundary.** The formatter is the last place where an
  invalid IRC line can be stopped before it reaches the socket.
- **Refactor by risk and upcoming change, not by age.** Old code is not
  automatically low-value, and new code is not automatically high-value.
- **Measure before performance work.** A performance refactor without evidence
  is premature optimization.

## Verification

- `mix test` — 67 tests passed.
- `mix format --check-formatted` — passed.
- `mix compile --force` — no warnings.

## References

### Elixir and Erlang/OTP APIs

- [`with`](https://hexdocs.pm/elixir/Kernel.SpecialForms.html#with/1)
- [`Enum.reduce_while/3`](https://hexdocs.pm/elixir/Enum.html#reduce_while/3)
- [`Enum.split/2`](https://hexdocs.pm/elixir/Enum.html#split/2)
- [`String.contains?/2`](https://hexdocs.pm/elixir/String.html#contains?/2)
- [`ArgumentError`](https://hexdocs.pm/elixir/ArgumentError.html)
- [`ExUnit.Assertions.assert_raise/2`](https://hexdocs.pm/ex_unit/ExUnit.Assertions.html#assert_raise/2)
- [`Task.async/1`](https://hexdocs.pm/elixir/Task.html#async/1)
- [`:gen_tcp.send/2`](https://www.erlang.org/doc/apps/kernel/gen_tcp.html#send/2)
- [`:gen_tcp.recv/3`](https://www.erlang.org/doc/apps/kernel/gen_tcp.html#recv/3)
- [`:gen_udp.open/2`](https://www.erlang.org/doc/apps/kernel/gen_udp.html#open/2)

### Refactoring and software engineering

- [Martin Fowler — Preparatory Refactoring](https://martinfowler.com/bliki/PreparatoryRefactoring.html)
- [Martin Fowler — Technical Debt](https://martinfowler.com/bliki/TechnicalDebt.html)
- [Martin Fowler — Refactoring](https://martinfowler.com/books/refactoring.html)
- [Martin Fowler — Test-Driven Development](https://martinfowler.com/bliki/TestDrivenDevelopment.html)
- [Chesterton’s fence — Wikipedia](https://en.wikipedia.org/wiki/Chesterton%27s_fence)
- [Farnam Street — Chesterton’s Fence](https://fs.blog/chestertons-fence/)
- [Michael Feathers — Working Effectively with Legacy Code](https://www.oreilly.com/library/view/working-effectively-with/0131177052/)
- [Kent Beck — Test-Driven Development by Example](https://www.oreilly.com/library/view/test-driven-development/0321146530/)
- [“If it ain’t broke, don’t fix it” — Wiktionary](https://en.wiktionary.org/wiki/if_it_ain%27t_broke,_don%27t_fix_it)
- [Program optimization — Wikipedia](https://en.wikipedia.org/wiki/Program_optimization)

## Remo's strip

| <img src="assets/remo.svg" width="120" alt="Remo building"> | <img src="assets/remo-red.svg" width="120" alt="Remo red"> | <img src="assets/remo-green.svg" width="120" alt="Remo green"> |
|---|---|---|
| **Built it:** send-error tests and a `send_message/2` contract that returns `{:error, reason}` | **Broke it:** the first `reduce_while/3` attempt returned a bare `%Connection{}` and broke 13 tests; invalid formatter input was still formatted | **Fixed it:** recursive `send_messages/2` with `with`, `close_with_error/2`, and formatter validation that rejects invalid parameters |
