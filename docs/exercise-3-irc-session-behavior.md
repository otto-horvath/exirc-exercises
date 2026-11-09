# Exercise 3 — IRC session behavior

This exercise added a long-lived session process on top of the TCP connection
and registration flow from Exercise 2. The session registers over a passive
socket, then switches to active socket messages so it can answer later `PING`s
without blocking inside `recv`. Complete IRC messages are framed and parsed
before the session responds to `PING` or forwards a `NOTICE` to an observer
process.

## Learning goals

- Answer server `PING`s with `PONG` carrying the same parameters.
- Continue handling server input after registration and its `001` welcome.
- Use a GenServer process to own a long-lived connection and its state.
- Understand passive reads versus active TCP messages and how socket ownership
  chooses the receiving process.
- Preserve framing state across TCP chunks and process each complete message
  once.
- Send parsed events to an observer without coupling IRC behavior to a terminal
  or web interface.

## Architecture and state

```text
IRC server ⇄ Connection ⇄ Session GenServer ──IRC events──► observer / future UI
                 │             │
                 │             ├─ registration lifecycle
                 │             ├─ PING → PONG
                 │             └─ persistent session state
                 ├─ socket
                 ├─ incomplete-byte buffer
                 └─ complete-message queue
```

`Connection` remains the value that carries the socket and framing fields; the
session process is the socket's controlling process. The GenServer state became
a map containing both the connection and an optional observer:

```elixir
%{connection: connection, observer: observer}
```

That is the session state, not a replacement connection. A callback updates the
connection while carrying the observer forward. This lets connection concerns
stay in `Connection` while the session retains the extra data it needs between
callbacks.

The message queue is treated as **pending complete input**, not as history.
Messages are parsed and handled once, then the queue is cleared. The incomplete
tail stays in `buffer` for the next TCP chunk. `PONG` is an outbound response,
not another incoming message, so it does not belong in that queue. Handling a
message directly in the session callback was sufficient; casting it back to the
same GenServer would add another mailbox step without changing the owner.

## Sequence: connect, register, then listen actively

```mermaid
sequenceDiagram
    participant Caller
    participant Session as Session GenServer
    participant Connection
    participant Registration
    participant Server as IRC server

    Caller->>Session: start_link(host, port, registration)
    Session->>Connection: connect (passive socket)
    Connection-->>Session: connection
    Session->>Registration: register(connection, registration)
    Registration->>Server: NICK / USER
    Server-->>Registration: 001 welcome
    Registration-->>Session: registered connection
    Session->>Session: process any complete queued messages
    Session->>Connection: set active mode
    Server-->>Session: {:tcp, socket, bytes}
    Session->>Session: frame bytes, parse complete IRC messages
    Session->>Server: PONG with matching PING parameters
```

`init/1` connects while the session process is the socket's controlling
process. A `handle_continue/2` callback performs registration after
initialization. The connection stays passive during this phase because
`Registration.register/3` uses `Connection.recv_message/2`, which calls
`:gen_tcp.recv/3`. After the welcome, the session switches the socket to active
mode and receives `{:tcp, socket, bytes}` in `handle_info/2`.

The transition matters: setting `active: true` in `Connection.connect/3` would
make the socket active before the passive registration reader uses it. Keeping
the switch in the session preserves the existing connection and registration
contracts.

## Sequence: server input after registration

```mermaid
sequenceDiagram
    participant Server as IRC server
    participant Session as Session GenServer
    participant Connection
    participant Observer

    Server-->>Session: {:tcp, socket, "PING :token\\r\\n"}
    Session->>Connection: frame bytes and parse message
    Session->>Server: PONG :token
    Server-->>Session: {:tcp, socket, NOTICE bytes}
    Session->>Connection: frame bytes and parse message
    Session-->>Observer: {:irc_message, notice}
```

A TCP delivery is a chunk of bytes, not necessarily one IRC message. It can
contain a partial line or several lines. `MessageFraming.feed/2` combines the
saved buffer with each new chunk, returns complete raw lines, and preserves an
incomplete tail. `MessageParser.parse/1` turns each complete line into a
`%Message{}`. `PING` is handled internally by sending `PONG`; a `NOTICE` is sent
to the observer as `{:irc_message, message}`. This keeps the session independent
of the eventual terminal and LiveView adapters.

The first notification contract is deliberately small: the observer behavior is
tested for `NOTICE`, while `PING` is internal session behavior. Broader event
types and UI delivery can build on this boundary in later exercises.

## Passive and active socket input

With the passive socket used by the connection and registration flow, a caller
must invoke `Connection.recv_message/2`; that call waits for bytes and returns
one parsed message. This is convenient for a bounded protocol exchange such as
registration, but a GenServer blocked in `recv` cannot process other mailbox
messages in the meantime.

With active socket input, Erlang sends each received byte chunk to the socket's
controlling process as a `{:tcp, socket, bytes}` message. The session can handle
that message in `handle_info/2` and remain available to process other messages.
The process that opens the TCP socket controls it, which is why the session
connects inside its own initialization. This milestone uses `active: true` for
simplicity; `active: :once` and backpressure are resilience concerns for a later
step.

Active mode changes only the source of bytes. The framing and parsing boundary
does not change. The session still needs to retain the partial-line buffer and
must not treat one `{:tcp, ...}` tuple as one IRC message.

## Queueing and one-time handling

Registration may read the welcome and additional complete lines in a single
passive socket read. `Connection.recv_message/2` returns the welcome and leaves
the extra complete lines queued on the updated connection. The session handles
those before switching the socket to active mode.

Later, `handle_info/2` combines any queued complete lines with newly framed
ones, parses and handles them, then clears the pending queue in the returned
state. The buffer is retained because its bytes are not yet a complete message.
An initial attempt to retain processed messages caused earlier events to be
dispatched again when another TCP chunk arrived. A test that sends two notices
in separate deliveries caught the duplicate; the focused test then passed 100
consecutive runs with ExUnit's `--repeat-until-failure` option.

## Design retrospective: proposed, achieved, and next improvements

### Proposed design

The design proposed during the exercise was to keep the existing
`%Connection{}` responsible for the socket and framing state, and add a
long-lived `Session` GenServer to own the connection lifecycle. Registration
would stay passive because it uses `Connection.recv_message/2`; after the
welcome, the session would switch to active TCP messages. The session would
reuse `MessageFraming` and `MessageParser`, answer `PING` internally, and send
other server events to an observer instead of depending on a UI. The observer
made the GenServer state larger than a connection alone, so the suggested shape
was a session state containing both connection and observer.

### What was achieved

The implementation follows that path: `init/1` connects, `handle_continue/2`
runs registration, and the session switches the socket to active mode afterward.
The callback state is a map containing `%Connection{}` and the observer.
`handle_info/2` frames incoming chunks, parses complete messages, replies to
`PING`, forwards `NOTICE` to the observer, and clears messages after handling
them while keeping the incomplete buffer. Fake-server tests cover the PING/PONG
exchange, observer delivery, and exactly-once dispatch across separate TCP
deliveries.

### What can improve

The session is intentionally a first implementation, not the final architecture.
The callback state could become a dedicated session-state struct so each
callback clearly updates one part while preserving the rest. The meaning of
`Connection.messages` can be made more explicit—pending input and handled
history should not share one queue if both are needed. Socket-mode changes might
belong behind a `Connection` function rather than being performed directly in
`Session`. Message handling is also called from more than one callback; keeping
callbacks as thin adapters that delegate to one private session operation may
make the flow easier to follow and test. Pure decisions about parsed messages
can be tested separately, while fake-server tests continue to verify socket
behavior. Broader event dispatch and graceful handling of other TCP messages
remain follow-up work.

These are review questions for a later refactoring step, not claims that the
current tests already cover those improvements.

## Testing and discoveries

The tests continue to use `FakeIRCServer`, so they exercise real local TCP
delivery without depending on a public IRC service. They cover:

- registration followed by a server `PING` and a matching `PONG`;
- a parsed server `NOTICE` delivered to the observer;
- two `NOTICE`s arriving in separate TCP deliveries, each dispatched only once.

The first attempt to make the connection active at connect time conflicted with
registration's passive `recv_message/2` flow. Moving the active-mode transition
to the session after registration kept the connection API usable by both
registration and the long-lived session.

Registration was first performed directly during initialization. Since
`start_link/3` waits for `init/1` to finish, the test could not get the session
pid and then drive the fake server through the welcome before registration's
timeout. Returning the connected state with a continuation moved registration
to `handle_continue/2`, separating process initialization from the blocking
registration exchange.

The UDP socket used in an existing registration send-error test exposed an
operating-system difference rather than a registration behavior difference.
Under Ubuntu 24.04 with OTP 29.1.1, `:gen_tcp.send/2` returned `:einval`; on
macOS with the same OTP it returned `:eaddrnotavail`. The test is temporarily
marked with ExUnit's `@tag :skip`. The next session should revisit its contract
and replace the UDP stand-in with a deterministic TCP failure setup.

Final checks on macOS with Elixir 1.20.4 and Erlang/OTP 29.1.1:

- `mix test` — 69 passed, 1 skipped.
- `mix format --check-formatted` — passed.
- `mix compile --force` — passed without warnings.
- The message-dispatch regression test — 100 repeated runs passed.
- Ubuntu 24.04 with OTP 29.1.1 — the focused registration send-error test
  passed with its expected `:einval` result.

## References

### IRC protocol

- [Modern IRC client protocol](https://modern.ircdocs.horse/)
- [`PING` message](https://modern.ircdocs.horse/#ping-message)
- [`PONG` message](https://modern.ircdocs.horse/#pong-message)
- [`NOTICE` message](https://modern.ircdocs.horse/#notice-message)

### Elixir and Erlang/OTP APIs

- [`GenServer`](https://hexdocs.pm/elixir/GenServer.html), including
  [`start_link/3`](https://hexdocs.pm/elixir/GenServer.html#start_link/3),
  [`handle_continue/2`](https://hexdocs.pm/elixir/GenServer.html#c:handle_continue/2),
  [`handle_info/2`](https://hexdocs.pm/elixir/GenServer.html#c:handle_info/2), and
  [`stop/1`](https://hexdocs.pm/elixir/GenServer.html#stop/1)
- [`:gen_tcp`](https://www.erlang.org/doc/apps/kernel/gen_tcp.html), including
  [`connect/4`](https://www.erlang.org/doc/apps/kernel/gen_tcp.html#connect/4),
  [`recv/3`](https://www.erlang.org/doc/apps/kernel/gen_tcp.html#recv/3),
  [`send/2`](https://www.erlang.org/doc/apps/kernel/gen_tcp.html#send/2), and
  [active-mode socket messages](https://www.erlang.org/doc/apps/kernel/gen_tcp.html#connect/4)
- [`:inet.setopts/2`](https://www.erlang.org/doc/apps/kernel/inet.html#setopts/2)
- [`Kernel.send/2`](https://hexdocs.pm/elixir/Kernel.html#send/2)
- [`Map`](https://hexdocs.pm/elixir/Map.html) and [`Enum`](https://hexdocs.pm/elixir/Enum.html)
- [`Process.alive?/1`](https://hexdocs.pm/elixir/Process.html#alive?/1)
- [`ExUnit.Case` tags](https://hexdocs.pm/ex_unit/ExUnit.Case.html#module-tags)
- [`ExUnit.Assertions`](https://hexdocs.pm/ex_unit/ExUnit.Assertions.html)
- [`mix test` options](https://hexdocs.pm/mix/Mix.Tasks.Test.html)

## Remo's strip

| <img src="assets/remo.svg" width="120" alt="Remo building"> | <img src="assets/remo-red.svg" width="120" alt="Remo red"> | <img src="assets/remo-green.svg" width="120" alt="Remo green"> |
|---|---|---|
| **Built it:** a session process registered, answered `PING`, and forwarded `NOTICE` to an observer | **Broke it:** processed messages stayed queued and were dispatched again on the next TCP chunk | **Fixed it:** drain the pending queue after handling messages while preserving the incomplete-byte buffer |
