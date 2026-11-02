# IRC protocol and compatibility notes

## Which protocol should the client implement?

Use the living [Modern IRC client protocol specification](https://modern.ircdocs.horse/)
as the core client-server reference. It describes current deployed behavior
and best practices in one place, including behavior that evolved beyond the
historical RFCs. It is not a newly published IETF standard or a separate
version of IRC.

The historical [RFC 2812](https://www.rfc-editor.org/rfc/rfc2812) is useful
background, but it dates from 2000 and identifies itself as informational.
IRCv3 is a set of separately specified extensions to the core protocol, not a
single protocol-version switch. The client should implement the core needed
for useful chat first, then negotiate a deliberate subset of stable IRCv3
capabilities.

## Runtime discovery

Servers do not generally provide one definitive “IRC version” value. The
client should discover and record the behavior relevant to it:

- **`CAP LS`**: capabilities the server offers during connection capability
  negotiation.
- **`005` / `RPL_ISUPPORT`**: server-advertised parameters such as `CASEMAPPING`,
  `CHANTYPES`, and nickname/channel limits.
- **`VERSION`**: normally describes the server software/version; it is not a
  complete declaration of protocol or extension support.

Capture the actual responses from each network in manual integration notes.
Capabilities may differ by network or change over time. Do not infer support
from the daemon version alone.

## Message parameters: middle and trailing

The spec's grammar for parameters:

```abnf
parameters ::= *( SPACE middle ) [ SPACE ":" trailing ]
middle     ::= nospcrlfcl *( ":" / nospcrlfcl )
trailing   ::= *( ":" / " " / nospcrlfcl )
nospcrlfcl ::= any character except NUL, CR, LF, ":" and SPACE
```

- A **middle** parameter has no spaces, is not empty, and does not start with
  `:` (a colon later in it is fine).
- A **trailing** parameter is the final parameter written with a leading `:`.
  The colon is a marker and is not part of the value. It may contain spaces and
  colons and may be empty. After parsing, it is an ordinary entry in the
  parameter list.

When sending, the colon on the final parameter is **required** if the value
contains a space, is empty, or starts with `:`; otherwise it is optional, so
`NICK remo` and `NICK :remo` are the same message. Put differently, the final
parameter must be trailing when it could not be written as a middle parameter.
Only the final parameter can be trailing, and no parameter may contain CR, LF
or NUL. A sender that accepts user text should reject those characters, since a
CRLF inside a parameter would let the text inject another command.

## Connection registration over a TCP stream

### The exchange

After the TCP connection opens, the client registers by sending a few lines;
the server answers with replies, possibly preceded by notices:

```text
      CLIENT (remo)                                   SERVER (irc.test)
          │                                                  │
          │──── TCP connect (SYN / SYN-ACK / ACK) ──────────▶│  no IRC yet, just an open pipe
          │                                                  │
          │──── PASS <password>\r\n ────────────────────────▶│  only if the network requires it
          │──── NICK remo\r\n ──────────────────────────────▶│
          │──── USER remo 0 * :Remo the Chameleon\r\n ──────▶│
          │                                                  │
          │◀─── :irc.test NOTICE * :*** Looking up your...── │  optional notices
          │◀─── :irc.test 001 remo :Welcome to ... remo ──── │  registered
          │◀─── :irc.test 002 remo :Your host is ... ─────── │  usually in the same
          │◀─── :irc.test 005 remo CHANTYPES=# ... ───────── │  burst as 001
```

`PASS` must come before `NICK` and `USER`. In `USER`, the `0` and `*` are
historical placeholders that clients still send. Instead of `001`, the server
may reply with an error numeric such as `433` (`ERR_NICKNAMEINUSE`) or send
`ERROR` and close the connection. Some servers send `PING` before `001` and
withhold registration until the client answers with `PONG`.

### Failures and early `PING`

Registration can end without `001`. The numeric replies the client handles while
registering:

| Reply | Parameters | Meaning |
|---|---|---|
| `433` `ERR_NICKNAMEINUSE` | `<client> <nick> :<text>` | The requested nickname is taken. |
| `464` `ERR_PASSWDMISMATCH` | `<client> :<text>` | A required `PASS` was missing or wrong. |
| `ERROR` | `:<reason>` | The server is closing the connection. It is a command, not a numeric. |

The first parameter of a numeric reply is the client's own nick, or `*` while the
client has none yet, so the nickname that is taken is the **second** parameter of
`433`.

Some servers, including InspIRCd, send `PING :<token>` before `001` and do not
finish registration until the client answers `PONG :<token>`. The `PONG` echoes
the token. The colon is optional on the wire when the token has no spaces, so a
test should compare the parsed message, not the exact line. Answering `PING`
only during registration is a minimal case: after `001`, replies depend on
something reading the socket continuously.

A client should also bound how long registration may take. A timeout on each
read is not enough, because a server that keeps sending notices without `001`
never trips it; use one deadline for the whole registration and give each read
the time remaining.

### Reads are not messages

TCP carries a byte stream, not messages. The server's burst arrives as one
sequence of bytes:

```text
:irc.test NOTICE * :*** Looking...\r\n:irc.test 001 remo :Welcome...\r\n:irc.test 002 ...
```

Packet sizes, the operating system's receive buffer, and timing decide how much
each `:gen_tcp.recv(socket, 0)` returns. A length of `0` means “whatever bytes
are available,” so a read can be shorter than a message, contain several
messages, or end partway through one. There is no fixed read size to rely on.

For example, if reads happened to return at most 10 bytes of
`:irc.test 001 remo :Hi\r\n:irc.test 002 remo :Yo\r\n`:

| Read | Bytes received | Buffer after framing | Complete messages |
|---|---|---|---|
| 1 | `:irc.test ` | `":irc.test "` | none |
| 2 | `001 remo :` | `":irc.test 001 remo :"` | none |
| 3 | `Hi\r\n:irc.t` | `":irc.t"` | `:irc.test 001 remo :Hi` |
| 4 | `est 002 re` | `":irc.test 002 re"` | none |
| 5 | `mo :Yo\r\n` | `""` | `:irc.test 002 remo :Yo` |

The opposite is just as common: one read returns
`…001 remo :Hi\r\n:irc.test 002 remo :Yo\r\n:irc.te`, which contains two
complete messages and the start of a third.

The client therefore keeps two kinds of state between reads:

- **Incomplete bytes** (`:irc.te`), which wait in the framing buffer until the
  rest of the line arrives.
- **Complete messages not yet handled** (`002` when the caller asked only for
  the next message), which must not be dropped. Otherwise the client may
  block waiting for bytes it has already received.

Receiving the next message is then a loop: return a waiting complete message if
there is one; otherwise read, frame with the buffer, and repeat until at least
one complete message is available.

The protocol limits message size, not read size: a message is at most 512 bytes
including CRLF, plus up to 8191 bytes of IRCv3 tags. A client can use that
limit to stop a misbehaving server from growing the buffer without bound.

## Real-world integration targets

### BrasIRC

The official site lists the client endpoint as `irc.brasirc.com.br:6667` and
TLS on port `6697` ([BrasIRC](https://brasirc.com.br/)). Its 2026 migration
article reports an upgrade from InspIRCd 2 to InspIRCd 4
([migration note](https://brasirc.com.br/update-ircd/)). This is useful
implementation context, but InspIRCd 4 is server software, not a protocol
version. Confirm the current endpoint, TLS certificate behavior, capabilities,
and `005` values during the exercise. Plain TCP on port 6667 can be used for a
manual registration check with the current client; use a private local
configuration for the nickname and any password.

### Libera.Chat

Libera.Chat documents TLS access at `irc.libera.chat:6697` and has a guide for
SASL account authentication ([connection guide](https://libera.chat/guides/connect)).
Use the guide for current connection/authentication details; do not place a
real SASL password in repository files or test fixtures. The server requires
TLS, so a manual check waits for the TLS milestone.

## Testing policy

Use three layers deliberately:

1. **Pure tests** for message parsing, formatting, and protocol state decisions.
2. **Local integration tests** against a deterministic fake IRC server for TCP
   framing, registration, `PING`/`PONG`, and session behavior. The fake server
   listens on loopback with an OS-assigned port, is driven line by line from the
   test, and can send raw bytes to exercise split and combined reads.
3. **Manual network checks** against BrasIRC and Libera.Chat for real-world
   compatibility and comparing advertised capabilities.

The automated suite should pass offline and must not depend on public servers,
network availability, or personal accounts. Manual observations should note
the date and redact nicknames, channels, or account data the user does not
want recorded.

## References

- [Modern IRC client protocol](https://modern.ircdocs.horse/)
- [IRCv3 specifications](https://ircv3.net/irc/)
- [Modern IRC: connection registration](https://modern.ircdocs.horse/#connection-registration)
- [Modern IRC: message format and size limits](https://modern.ircdocs.horse/#messages)
- [Modern IRC: parameters](https://modern.ircdocs.horse/#parameters)
- [`:gen_tcp.recv/3`](https://www.erlang.org/doc/apps/kernel/gen_tcp.html#recv/3)
- [RFC 2812](https://www.rfc-editor.org/rfc/rfc2812)
- [BrasIRC](https://brasirc.com.br/)
- [BrasIRC InspIRCd migration note](https://brasirc.com.br/update-ircd/)
- [Libera.Chat connection guide](https://libera.chat/guides/connect)
