# Exercise 2 — TCP connection and registration

This exercise connected the pure protocol code from Exercise 1 to a real TCP
socket. The client can now open a connection to a server, register with
`PASS`/`NICK`/`USER`, read the server's replies, and end registration with a
welcome, an error, or a timeout. Everything is tested against a local fake IRC
server; BrasIRC and Libera.Chat were not needed for the suite. TLS was not
covered here; it is planned as an optional later milestone.

## Learning goals

- Open a TCP connection from Elixir and exchange IRC lines over it.
- Understand why a socket read is not an IRC message, and keep framing state
  between reads.
- Implement client registration: send the right messages in the right order and
  recognize the server's answer.
- Handle server numerics and failures, and bound how long registration can take.
- Test network code deterministically with a local fake server.
- Keep protocol logic independent of the socket, ready for a session process and
  user interfaces later.

## From bytes to a registered client

The pipeline from Exercise 1 now has both ends:

```text
socket → MessageFraming → MessageParser → registration → (session, Exercise 3) → UI
UI → (session) → registration → MessageFormatter → socket
```

The modules, from the outside in:

| Module | Responsibility |
| --- | --- |
| `Exirc.IRC.MessageFormatter` | Turns a `%Message{}` into a CRLF-terminated line. Pure. |
| `Exirc.IRC.Registration` | `messages/1` builds `PASS`/`NICK`/`USER` (pure); `register/3` runs the flow on a connection. |
| `Exirc.IRC.Connection` | Owns the socket and the framing state: `connect/3`, `send_message/2`, `recv_message/2`, `close/1`. |
| `Exirc.Test.FakeIRCServer` (test support) | A local server driven step by step from a test. |

## Speaking IRC: formatting and registration

### Middle and trailing parameters

The spec names the two kinds of parameter. A **middle** parameter is written
as-is: it cannot contain a space, be empty, or start with `:`. A **trailing**
parameter is the final one written with a leading `:`; the colon marks where it
starts and is not part of its value. After parsing, a trailing parameter is an
ordinary entry in `params`, which is why the struct has no separate field for
it.

The formatter has to decide when the final parameter needs the colon. It is
required when the value contains a space, is empty, or starts with `:`;
otherwise it is optional. In other words: if the last parameter could not be a
middle parameter, it must be trailing. `NICK remo` and `NICK :remo` are the same
message. Only the last parameter can be trailing, so a space in an earlier
parameter is an invalid message rather than something to merge.
`MessageFormatter.format/1` now enforces this: a non-final parameter that is
empty, contains a space, or starts with `:` raises `ArgumentError`, as does CR,
LF, or NUL in any parameter.

### Registration order

`Registration.messages/1` returns `PASS` (only when a password is set), then
`NICK`, then `USER`:

```text
PASS <password>
NICK remo
USER remo 0 * :Remo the Chameleon
```

In `USER`, the `0` and `*` are historical placeholders that clients still send;
the real realname is the trailing parameter. The function matches the required
keys (`nick`, `username`, `realname`) in its head, so a missing one raises
`FunctionClauseError` at the call instead of producing `NICK` with a `nil`.
The optional password is read with `Map.get/2`, so a missing key and `nil` both
mean "no `PASS`".

`register/3` accepts a keyword list, the idiomatic shape for options, and
converts it with `Map.new/1` before calling `messages/1`.

## TCP: reads are not messages

TCP delivers a byte stream. Each `:gen_tcp.recv(socket, 0)` returns whatever
bytes are available, which can be less than one message, several messages, or
end partway through one. The full walkthrough, with a byte-by-byte table, is in
the [protocol notes](irc-protocol-notes.md#connection-registration-over-a-tcp-stream).

The connection therefore carries two kinds of state:

```elixir
defstruct [:socket, buffer: "", messages: []]
```

- `buffer`: incomplete bytes (`":irc.te"`), waiting for the rest of the line.
- `messages`: complete lines from a read that have not been returned yet.

`recv_message/2` has two clauses. When `messages` is empty it reads the socket,
feeds the bytes to `MessageFraming.feed/2` together with the saved `buffer`,
stores the results, and calls itself again. When a message is waiting it
returns it without touching the socket. If a read yields no complete line, the
second call lands in the reading clause again, which is the read loop. The
"several messages in one write" test exists to make sure the second message is
not lost, and not waited for on a socket that has already delivered it.

The Erlang `gen_tcp` documentation shows a similar recursive `do_recv/2` loop
with an accumulator. The difference is the stopping rule: that example reads
until the peer closes the socket, which fits a protocol whose message ends when
the connection does. IRC connections stay open, so CRLF framing decides where a
message ends, and the loop stops as soon as one complete message exists.

The socket is opened with `[:binary, active: false]`: passive mode, so the
caller decides when to read. The fake server also uses `packet: :line`, which
lets the operating system split input into lines. The client must not use it,
because splitting the stream is the framing module's job.

## Testing network code

`FakeIRCServer` is a plain struct driven by the test process, not a GenServer.

- `listen/0` listens on `127.0.0.1` with port `0`, so the OS picks a free port
  and tests can run concurrently without touching a real network.
- `accept/2` waits for one client; `recv_line/2` returns the next client line
  without its CRLF and fails the test on a bad line ending, a timeout, or a
  closed socket.
- `send_line/2` adds CRLF; `send_raw/2` sends bytes unchanged, for split or
  combined lines; `close/1` simulates a hang-up; `assert_closed/2` checks that
  the client closed the connection.
- Its own tests use a bare `:gen_tcp` client, so the helper is verified before
  it is used to test client code.

`connect/3` returns once the operating system has queued the connection, so
`Connection` tests run in a single process. `register/3` blocks until the server
replies, so those tests run the client in a `Task` while the test process plays
the server. The task also opens the socket, because a socket belongs to the
process that created it and closes when that process exits. The failure tests
keep the client process alive after `register/3` returns, so a closed socket can
only mean that `register/3` closed it.

## Design decisions and tradeoffs

**Connect first, then register.** The first scaffold had one
`Connection.register/3` that opened the socket and registered. It was split:
`Connection` handles bytes and messages, `Registration` runs the IRC flow on top
of it. Later steps need the gap: capability negotiation (Exercise 6) happens
between connecting and registering, and a reconnect is "connect again, register
again".

**Value, not process (yet).** `%Connection{}` is a struct passed through
functions and returned updated, not a GenServer. This is close to how the Mint
HTTP client represents a connection. `Plug.Conn` shares the "explicit value"
idea, but a `Plug.Conn` lives for one request and the web server reads the
socket for it; an IRC connection lives for hours and our code reads it. A
process arrives in Exercise 3, when the session has its own lifecycle. There,
the socket would switch to active mode (incoming bytes as messages, with
`active: :once` for backpressure) so one process can handle server data and user
commands without blocking on `recv`. The framing logic stays the same; only the
source of the bytes changes.

**Errors as tagged tuples.** Failures are returned, not raised:

| Situation | Result | Where |
| --- | --- | --- |
| nothing listening | `{:error, :econnrefused}` | `Connection.connect/3` |
| server hangs up | `{:error, :closed}` | `recv_message/2`, `register/3` |
| nothing complete in time | `{:error, :timeout}` | `recv_message/2`, `register/3` |
| sending a message fails | `{:error, reason}` | `send_message/2`, `register/3` |
| `433` nickname in use | `{:error, {:nickname_in_use, nick}}` | `register/3` |
| `464` wrong password | `{:error, :password_mismatch}` | `register/3` |
| `ERROR :reason` | `{:error, {:server_error, reason}}` | `register/3` |

In a numeric reply the first parameter is the client's own nick (or `*` before
registration), so the nick that is taken is the second parameter of `433`.
`register/3` closes the socket on these failures, on a send failure, and on a
timeout.

**A deadline, not a per-read timeout.** `recv_message/2` takes a timeout for one
read. If `register/3` gave each read the full timeout, a server that kept sending
notices but never `001` would keep registration alive forever. `register/3` now
computes one deadline from `System.monotonic_time/1` and gives each read only
the time remaining, never below zero because `:gen_tcp.recv/3` rejects negative
timeouts. The monotonic clock never goes backwards, unlike wall-clock time. The
default is 30 seconds rather than `:infinity`, which also could not be added to a
number.

**Answering `PING` before `001`.** Some servers, including InspIRCd, ping the
client during registration and wait for the matching `PONG`. `register/3`
answers with the same token and keeps waiting under the same deadline. This is
only the minimal case: after `001` nobody reads the socket until the session
process exists, so general `PING`/`PONG` handling belongs to Exercise 3.

**Deferred.** TLS was dropped from this exercise to keep it focused; it is
planned as an optional milestone after resilience. The lazy-stream alternative
for "find the first `001`" (`Stream.unfold/2` with `Enum.find/2`) was discussed
and the simpler recursive loop was chosen; its tradeoffs are left for a later
exercise. The framing buffer is not bounded yet; the protocol limits a message to
512 bytes plus up to 8191 bytes of IRCv3 tags, which a later step can use to
stop a misbehaving server from growing it.

## Protocols and `String.Chars`

An idea that came up: implement `String.Chars` for `%Message{}` so that
`to_string(message)` gives the wire line, as `URI` does for URIs. It was
postponed. `String.Chars` also runs on interpolation and in `Logger` calls, so a
CRLF in it would leak into logs. The workable version has `to_string/1` return
the line without CRLF and the socket write append it, mirroring how framing
strips CRLF before parsing. A custom protocol (for example an `Encodable`) is not
justified while one struct implements it. Typespecs (`@type t` on `Message`,
`@spec` on the public functions) are cheap to add; Elixir's type checker already
infers struct usage without them. The simple `MessageFormatter.format/1`, which
appends CRLF itself, is what the code uses for now.

## Elixir notes from this exercise

- **`alias`, not `import`, for a struct.** `alias Exirc.IRC.Message` lets you
  write `%Message{}` in patterns; `import` is for functions and macros.
- **No pattern for the last list element.** Lists are linked lists, so a pattern
  only matches from the front. Options: `Enum.split(list, -1)`,
  `List.pop_at(list, -1)`, or recursion with a `[last]` clause before
  `[head | tail]`.
- **Cons is not append.** `[x | y]` builds a cell with head `x` and tail `y`;
  with a non-list tail it creates an improper list. Prepend is cheap, `++` copies
  the left side. Nested and improper lists are valid iodata, converted once with
  `IO.iodata_to_binary/1`.
- **Removing `nil`s:** `Enum.reject(list, &is_nil/1)`.
- **Default arguments and clauses.** A function is its name plus arity.
  Several clauses with the same arity form one function, tried top to bottom. With
  several clauses, declare the default once in a bodiless function head
  (`def recv_message(connection, timeout \\ :infinity)`).
- **Anonymous functions need `fn ... end`;** `x -> ...` alone is only valid
  inside `fn`, `case`, `receive`, and similar.
- **`with`** chains `{:ok, _}` results and is the usual alternative to nested
  `case`; `Plug` avoids it by keeping errors inside its `conn`, which does not fit
  a long-lived connection.

## Test progression and result

Formatter tests cover no parameters, middle parameters, trailing parameters for
a space, an empty value, a leading colon and a lone parameter, and a parse
round trip. Registration tests cover the order with and without a password, a
`nil` password, a missing required field, and the formatted lines. `Connection`
tests cover sending a CRLF-terminated line, receiving one parsed message,
several messages in one write, a message split across writes, a partial message
kept between calls, a closed connection, a timeout, a waiting message returned
without a read, and a refused connection. Registration flow tests cover the
welcome, `PASS`, notices before the welcome, messages after the welcome staying
on the connection, `433`, `464`, `ERROR`, a close before the welcome, a timeout,
the whole-registration deadline, and `PING` answered one or more times.

### Mistakes and rework

- The first formatter used `Enum.split/2` to isolate the last parameter and
  special-cased a lone parameter without a colon. A test for a lone parameter with
  spaces exposed it, and the formatter was rewritten as recursion with a
  `trailing?/1` check.
- The first design had a single `Connection.register/3`; it was split into
  `Connection` and `Registration`, with the earlier scaffold kept in history.
- `recv_message/2` first fed `""` instead of the saved buffer, discarding partial
  lines, and assumed every read produced a complete message, so a split write
  raised `MatchError`. The fix was to store all framed messages, even none, and
  recurse.
- A `433` clause that matched exactly two parameters never matched the real
  three, so registration silently kept waiting.
- A per-read timeout let a chatty server keep registration alive; the deadline
  test caught it.
- A `PING` branch that returned `send_message/2`'s result ended registration after
  the first ping instead of continuing to wait.
- Two mistakes in the test setup: a `PONG :token` assertion over-specified the
  formatter's output, since the colon is optional for a token without spaces, and
  was changed to compare the parsed message; a fail-fast test passed a literal map
  that the type checker already knew could not match, and now builds the map at
  runtime. `Connection.close/1` was committed one commit after its first use.

Final checks for this milestone:

- `mix test` — 67 tests passed after the follow-up send-error and formatter
  refactors.
- `mix format --check-formatted` — passed.
- `mix compile --force` — no warnings.

Pending refactors in the exercise code are tracked in
[notes for next session](notes-for-next-session.md).

## References

### IRC protocol

- [Modern IRC client protocol — connection registration](https://modern.ircdocs.horse/#connection-registration)
- [Modern IRC client protocol — parameters](https://modern.ircdocs.horse/#parameters)
- [Modern IRC client protocol — message format and size limits](https://modern.ircdocs.horse/#messages)
- [`ERR_NICKNAMEINUSE (433)`](https://modern.ircdocs.horse/#errnicknameinuse-433)
- [`ERR_PASSWDMISMATCH (464)`](https://modern.ircdocs.horse/#errpasswdmismatch-464)
- [`ERROR`](https://modern.ircdocs.horse/#error-message)
- [Numeric replies](https://modern.ircdocs.horse/#numerics)

### Elixir and Erlang/OTP APIs used or explored

- [`:gen_tcp`](https://www.erlang.org/doc/apps/kernel/gen_tcp.html) — see
  [`connect/4`](https://www.erlang.org/doc/apps/kernel/gen_tcp.html#connect/4),
  [`send/2`](https://www.erlang.org/doc/apps/kernel/gen_tcp.html#send/2),
  [`recv/3`](https://www.erlang.org/doc/apps/kernel/gen_tcp.html#recv/3),
  [`close/1`](https://www.erlang.org/doc/apps/kernel/gen_tcp.html#close/1),
  [`controlling_process/2`](https://www.erlang.org/doc/apps/kernel/gen_tcp.html#controlling_process/2)
- [`:inet.setopts/2`](https://www.erlang.org/doc/apps/kernel/inet.html#setopts/2) (`active`, `packet`)
- [`System.monotonic_time/1`](https://hexdocs.pm/elixir/System.html#monotonic_time/1)
- [`Task.async/1`](https://hexdocs.pm/elixir/Task.html#async/1)
- [`Enum.reject/2`](https://hexdocs.pm/elixir/Enum.html#reject/2), [`Enum.split/2`](https://hexdocs.pm/elixir/Enum.html#split/2), [`Enum.reduce/3`](https://hexdocs.pm/elixir/Enum.html#reduce/3)
- [`List.pop_at/3`](https://hexdocs.pm/elixir/List.html#pop_at/3)
- [`Map.new/1`](https://hexdocs.pm/elixir/Map.html#new/1), [`Map.get/3`](https://hexdocs.pm/elixir/Map.html#get/3)
- [`Keyword.get/3`](https://hexdocs.pm/elixir/Keyword.html#get/3)
- [`String.to_charlist/1`](https://hexdocs.pm/elixir/String.html#to_charlist/1), [`String.contains?/2`](https://hexdocs.pm/elixir/String.html#contains?/2)
- [`IO.iodata_to_binary/1`](https://hexdocs.pm/elixir/IO.html#iodata_to_binary/1)
- [`Kernel.++/2`](https://hexdocs.pm/elixir/Kernel.html#++/2), [`Kernel.max/2`](https://hexdocs.pm/elixir/Kernel.html#max/2), [`Kernel.is_nil/1`](https://hexdocs.pm/elixir/Kernel.html#is_nil/1)
- [`with`](https://hexdocs.pm/elixir/Kernel.SpecialForms.html#with/1), [`alias`](https://hexdocs.pm/elixir/Kernel.SpecialForms.html#alias/2)
- [`Stream.unfold/2`](https://hexdocs.pm/elixir/Stream.html#unfold/2), [`Enum.find/3`](https://hexdocs.pm/elixir/Enum.html#find/3)
- [`ExUnit.Assertions.flunk/1`](https://hexdocs.pm/ex_unit/ExUnit.Assertions.html#flunk/1)
- [Default arguments](https://hexdocs.pm/elixir/modules-and-functions.html#default-arguments), [structs](https://hexdocs.pm/elixir/structs.html), [lists and tuples](https://hexdocs.pm/elixir/lists-and-tuples.html), [anonymous functions](https://hexdocs.pm/elixir/anonymous-functions.html)
- [Mix `elixirc_paths`](https://hexdocs.pm/mix/Mix.Tasks.Compile.Elixir.html)

### Protocols, types, and related libraries

- [Protocols](https://hexdocs.pm/elixir/protocols.html), [`String.Chars`](https://hexdocs.pm/elixir/String.Chars.html), [`URI`](https://hexdocs.pm/elixir/URI.html)
- [Typespecs](https://hexdocs.pm/elixir/typespecs.html), [gradual set-theoretic types](https://hexdocs.pm/elixir/gradual-set-theoretic-types.html)
- [`GenServer.handle_info/2`](https://hexdocs.pm/elixir/GenServer.html#c:handle_info/2) (preview of Exercise 3)
- [`Mint.HTTP`](https://hexdocs.pm/mint/Mint.HTTP.html), [Mint architecture](https://hexdocs.pm/mint/architecture.html), [`Plug.Conn`](https://hexdocs.pm/plug/Plug.Conn.html)

## Remo's strip

| <img src="assets/remo.svg" width="120" alt="Remo building"> | <img src="assets/remo-red.svg" width="120" alt="Remo red"> | <img src="assets/remo-green.svg" width="120" alt="Remo green"> |
|---|---|---|
| **Built it:** a formatter, registration messages, and a `recv_message` that returned one line | **Broke it:** a chatty server kept a "timed" registration alive forever, and split or combined reads exposed lost bytes | **Fixed it:** a saved buffer plus waiting messages, and one deadline computed once and shared by every read |
