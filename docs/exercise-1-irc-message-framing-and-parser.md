# Exercise 1 — IRC message framing and parser

This exercise built the pure protocol boundary between arbitrary TCP reads and
the rest of an IRC client. TCP socket code, connection lifecycle, command
handling, and user interfaces remain later milestones; here, the inputs are
deterministic binary chunks and already-framed message lines.

## Learning goals

- Understand that TCP delivers an ordered byte stream, not one IRC message per
  read.
- Frame CRLF-delimited IRC lines while retaining incomplete input between
  reads.
- Parse the common IRC message structure: optional tags, optional source
  (often called a prefix), command, and parameters.
- Keep framing and parsing as pure functions, separate from sockets and user
  interfaces.
- Use tests to grow the implementation from concrete protocol examples.

## From TCP chunks to parsed messages

The eventual client pipeline is:

```text
TCP/TLS socket → message framing → message parser → IRC session → UI adapter
```

TCP provides a reliable, ordered byte stream, but its read boundaries do not
carry application meaning. A read may end halfway through an IRC line, contain
several lines, or split the `CRLF` delimiter across two reads. The framing
function therefore accepts both the previous incomplete `buffer` and a new
`chunk`:

```elixir
MessageFraming.feed(buffer, chunk)
```

It joins those bytes, emits complete lines without their `CRLF`, and returns
the incomplete remainder as the next buffer. Empty CRLF-delimited lines are
ignored, so an empty line does not become a bogus command for the parser.

IRC and HTTP/1.x are both text protocols commonly transported over TCP, so the
stream-boundary problem is analogous. Their framing rules are not interchangeable:
IRC uses CRLF-delimited messages, while HTTP/1.x has headers and separate
body-framing rules. IRC also isn’t generally a request/response conversation;
servers can send asynchronous messages such as channel chat.

## Why the code moved from strings to bytes

The first framing approach joined the chunks, used `String.split/2`, and used
`Enum.split/2` with a negative count to separate the final incomplete segment
from complete lines. It made the framing cases visible and passed the initial
tests. We then explored byte-oriented APIs because the boundary is specifically
the two bytes `CRLF`, not a Unicode character boundary.

The final framing implementation searches the combined binary with
`:binary.match/2`. Its result gives the byte offset and matched delimiter
length; `binary_part/3` takes the message bytes before the delimiter and the
remaining bytes after it. The delimiter is named once as `@crlf`. Messages are
collected in reverse order and reversed once before returning, preserving their
wire order.

This is an explicit byte-level implementation, not a benchmark-proven
performance optimization. `Enum.split/2` was not inherently incorrect; the
recursive binary search avoids first materializing all split segments and then
walking that segment list to peel off the remainder. Both approaches still
process the input linearly, and the final message list must be returned in
order.

Elixir strings are UTF-8 binaries, while Erlang/OTP’s `:binary` module provides
operations directly on binaries. Using `:binary` here makes the framing
boundary explicit. This exercise did not yet open a socket or call `:gen_tcp`;
that belongs to the next milestone.

## IRC message structure

The protocol describes a CRLF-terminated unit as an IRC **message**. Framing
removes CRLF; parsing turns the remaining line into an `%Exirc.IRC.Message{}`:

```text
[@tags ] [:source ] COMMAND [middle parameters...] [:trailing parameter]
```

The order is tags, optional source, command, then parameters. Tags start with
`@`; a source starts with `:`. The `!user@host` part can appear inside a user
source, but it is not a message delimiter. For example:

```text
@time=2026-10-29T12:00:00Z :friend1!user@host PRIVMSG #brasil :Olá, pessoal!
```

This becomes a message with a `time` tag, source `friend1!user@host`, command
`PRIVMSG`, and parameters `#brasil` and `Olá, pessoal!`. Spaces separate
ordinary (“middle”) parameters. A colon at the beginning of the final parameter
marks the rest of the line as one trailing parameter; the marker is removed,
while spaces in the text are retained. The `#` in `#brasil` is part of the
target value, not a parser delimiter.

Tags are optional IRCv3 metadata, not command parameters. A tag may have a
value or be key-only; key-only tags are represented with an empty string value.
Tag values use escape sequences so spaces, semicolons, backslashes, CR, and LF
can be represented without confusing the message delimiters. Parsing tags here
does not negotiate the `message-tags` capability; capability negotiation comes
later.

The parser is generic: it extracts the message structure rather than having a
separate line parser for `PRIVMSG`, `CAP`, or each other command. It accepts
commands with no parameters and returns a struct with `tags`, `prefix`,
`command`, and `params`. It does not validate whether a command is known or
supported by a particular server.

## Parser strategy and decisions

- `MessageFraming.feed/2` is the public framing boundary; `MessageParser.parse/1`
  is the public parser boundary. Both are pure and do not depend on a socket or
  UI.
- The parser processes optional tags first, then an optional source prefix, then
  the command and parameter text. This follows the protocol’s fixed message
  order.
- `String.split/3` with `parts: 2` separates the next token while leaving the
  remainder intact. This is important for the trailing parameter, which may
  contain spaces.
- Parameter parsing recurses over middle parameters and recognizes a colon
  only when it starts the next parameter. Thus text such as `:-)` keeps its
  colon as content after the marker is removed: `PRIVMSG #chan ::-)` has the
  trailing parameter `:-)`.
- A small `%Exirc.IRC.Message{}` struct gives callers a named result type. The
  parser remains one module with private helpers; tags, prefix, and parameters
  are parts of one grammar, not separate public parsing APIs.
- Tests define specific protocol cases. They do not imply full validation of
  malformed input, server command support, message length limits, or live
  network behavior; those concerns can be scoped in later exercises.

## Test progression and result

The framing tests cover a complete line, input split between reads, multiple
lines plus an incomplete tail, CRLF split between reads, and empty lines. Parser
tests cover a `PRIVMSG` trailing parameter with spaces, several middle
parameters, a source prefix, tags, tag-plus-prefix ordering, escaped tag values,
and a command with no parameters.

The implementation changed as the tests exposed assumptions: the first parser
split assumed a single middle parameter; a prefixed line was initially treated
as if its source were the command; the parser’s output moved from an anonymous
map to a named struct; and tag values initially remained escaped. The empty-line
test also showed that framing was emitting an empty string, so framing was
updated to skip it while preserving neighboring messages.

Final checks for this milestone:

- `mix test` — 13 tests passed.
- `mix format --check-formatted` — passed.

## References

### IRC protocol

- [Modern IRC client protocol — message format](https://modern.ircdocs.horse/#message-format)
- [Modern IRC client protocol — parameters](https://modern.ircdocs.horse/#parameters)
- [Modern IRC client protocol — `PRIVMSG`](https://modern.ircdocs.horse/#privmsg-message)
- [IRCv3 Message Tags specification](https://ircv3.net/specs/extensions/message-tags)

### Elixir and Erlang/OTP APIs used or explored

- [`String.split/3`](https://hexdocs.pm/elixir/String.html#split/3)
- [`Enum.split/2`](https://hexdocs.pm/elixir/Enum.html#split/2)
- [`Enum.reverse/1`](https://hexdocs.pm/elixir/Enum.html#reverse/1)
- [`:binary.split/3`](https://www.erlang.org/doc/apps/stdlib/binary.html#split/3)
- [`:binary.match/2`](https://www.erlang.org/doc/apps/stdlib/binary.html#match/2)
- [`Kernel.binary_part/3`](https://hexdocs.pm/elixir/Kernel.html#binary_part/3)
- [`Map.new/2`](https://hexdocs.pm/elixir/Map.html#new/2)
- [`IO.iodata_to_binary/1`](https://hexdocs.pm/elixir/IO.html#iodata_to_binary/1)
- [`String` and UTF-8 binaries](https://hexdocs.pm/elixir/String.html)

## Remo's strip

| <img src="assets/remo.svg" width="120" alt="Remo building"> | <img src="assets/remo-red.svg" width="120" alt="Remo red"> | <img src="assets/remo-green.svg" width="120" alt="Remo green"> |
|---|---|---|
| **Built it:** a CRLF framer and generic IRC message representation | **Broke it:** positional parsing missed multiple parameters and prefixes; escaped tags and empty lines exposed more gaps | **Fixed it:** focused tests drove byte-oriented framing, generic parameter parsing, tags, prefixes, and a green 13-test suite |
