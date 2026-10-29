<p align="center">
  <img src="docs/assets/logo.svg" alt="exirc-exercises: Remo the chameleon beside a glossy IRC speech bubble" width="720">
</p>

# Elixir IRC Client Exercises

[![Built with Elixir](https://img.shields.io/badge/Built%20with-Elixir-8847B9)](https://elixir-lang.org/)

A test-first learning series for building an IRC client in Elixir. The client
starts as a terminal application and grows into a Phoenix LiveView interface,
keeping IRC behavior independent of either user interface.

The goal is to learn network programming on the BEAM, implement the modern IRC
client protocol in practical steps, and use OTP to build a client that stays
responsive when connections fail. This series assumes familiarity with Elixir
basics and ExUnit; it focuses on applying them to a stateful networked system.

## What you’ll build

A client that can connect to IRC networks, list and browse channels, join and
leave channels, exchange channel messages, and hold private conversations. The
terminal client is the first complete interface. Phoenix LiveView comes later
as another adapter over the same client behavior.

BrasIRC and Libera.Chat are the intended real-world integration networks. Use a
local fake IRC server for repeatable automated tests; public networks are
manual compatibility checks, not test dependencies.

## Learning goals

- Frame and parse IRC messages from a TCP byte stream.
- Connect using TCP/TLS and implement client registration, server replies, and
  IRC commands.
- Model connection and conversation behavior with processes and OTP
  supervision where independent lifecycles justify them.
- Build channel listing, channel conversations, and private chats.
- Negotiate selected IRCv3 capabilities and adapt to server-advertised
  features.
- Separate client behavior from its terminal and LiveView interfaces.
- Explore failure handling, reconnect behavior, bounded message history, and
  useful observability.

## Protocol analogy and command map

IRC is a text protocol commonly carried over TCP, like HTTP/1.x. In both, TCP
provides an ordered byte stream, not message-sized reads, so clients must handle
messages split across reads or several messages arriving together. IRC frames
messages as CRLF-terminated lines; HTTP/1.x uses its own headers and
body-framing rules. The analogy helps explain stream framing, but the protocols'
message structures and interaction patterns differ.

We will build this command map as the milestones introduce each behavior. It is
a learning roadmap, not a promise that every IRC server or connection needs
every command; server replies are identified separately from client commands.

| Milestone | Command / reply | Direction and purpose |
| --- | --- | --- |
| 2 | `PASS` *(optional)* | Client → server; supply a connection password when the network requires one. Keep credentials in local configuration. |
| 2 | `NICK` | Client → server; request the client's nickname. |
| 2 | `USER` | Client → server; send the remaining initial registration information. |
| 2 | `001` (`RPL_WELCOME`) | Server → client; successful registration reply. |
| 3 | `PING` / `PONG` | Server → client / client → server; keep the connection responsive and answer server liveness checks. |
| 4 | `LIST` | Client → server; request the channel list. |
| 4 | `JOIN` / `PART` | Client → server; join or leave a channel. |
| 4 | `PRIVMSG` | Client ↔ server; send channel or private chat messages and receive them from the server. |
| 6 | `CAP LS` / `CAP REQ` / `CAP END` | Client ↔ server; discover, request, and finish negotiating selected IRCv3 capabilities. |
| 6 | `005` (`RPL_ISUPPORT`) | Server → client; advertise network-specific features and limits. |

The list may be refined as tests and compatibility work reveal the actual
behavior needed. Numeric replies are server messages, not commands the client
sends.

## The learning loop

Each milestone should be small and test-first: agree on one behavior, write a
test that describes it, implement the behavior, run the focused test, and keep
earlier tests passing. Use a local test server for network behavior so tests do
not rely on an Internet connection or an account on a public IRC network.

The learner writes production behavior. The assistant can prepare tests and
minimal scaffold, explain concepts, offer hints when asked, and review the
result. Each completed milestone can have a practical guide under `docs/`,
written when requested and grounded in what actually happened.

See [AGENTS.md](AGENTS.md) for the working agreement and
[docs/setup.md](docs/setup.md) for the initial toolchain requirements.

## Milestone roadmap

The order builds a usable terminal client before introducing the web UI.
Dependencies and frameworks are added only when a milestone needs them.

| # | Milestone | Main learning |
| ---: | --- | --- |
| 1 | IRC message framing and parser — complete | CRLF framing, TCP stream buffering, tags/prefixes/parameters, pure functions, ExUnit |
| 2 | TCP/TLS connection and registration | sockets, registration flow, server numerics, timeouts |
| 3 | IRC session behavior | `PING`/`PONG`, incoming events, explicit state, process messaging |
| 4 | Terminal channels and chat | `LIST`, channel browsing, `JOIN`/`PART`, `PRIVMSG`, private chats |
| 5 | Client lifecycle and resilience | supervision, multiple network connections, disconnects and reconnect policy |
| 6 | IRCv3 capability negotiation | `CAP`, selected capabilities, server-specific compatibility |
| 7 | Phoenix LiveView interface | UI events and updates over the existing client behavior |

Potential extensions include per-conversation bounded in-memory history and
logging/telemetry. They are candidates for later exercises, not prerequisites
for the initial client. Broadway is out of scope.

See the [Exercise 1 guide](docs/exercise-1-irc-message-framing-and-parser.md)
for the framing and parser concepts, decisions, and test progression.

## Protocol references and integration targets

The protocol baseline is the living [Modern IRC client protocol
specification](https://modern.ircdocs.horse/), which describes current
client-server behavior and best practices. IRCv3 extensions are specified
separately; the series will select relevant, stable capabilities rather than
trying to implement every extension.

There is no single current IRC version string that a client can rely on. At
connection time, `CAP LS` advertises supported capabilities and numeric `005`
(`RPL_ISUPPORT`) advertises network-specific behavior. A server’s `VERSION`
reply identifies server software/version, not a complete protocol version.
More detail and the real-world test notes are in
[docs/irc-protocol-notes.md](docs/irc-protocol-notes.md).

| Network | Endpoint | Notes |
| --- | --- | --- |
| BrasIRC | `irc.brasirc.com.br:6667` (plain), TLS port `6697` | Official site reports InspIRCd 4; this is server software, not an IRC protocol version. |
| Libera.Chat | `irc.libera.chat:6697` (TLS) | TLS is recommended; SASL is available for account authentication. |

Do not put passwords, SASL secrets, or other credentials in source control,
tests, documentation, or logs. Real-network testing should use private local
configuration and an account the learner controls.

## Remo 🦎

Remo is the chameleon mascot shared with
[hexagon-exercises](https://github.com/otto-horvath/hexagon-exercises). The
project logo pairs Remo with a compact, glossy IRC speech bubble. Remo's test
colors keep the series visible: **red** when tests fail, **yellow** while work
is in progress, and **green** when tests pass. Remo is a status marker and
storyteller, never filler.

The Remo artwork is by Otto Horvath and is shared under
[CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/); see its
[source project](https://github.com/otto-horvath/hexagon-exercises). The logo
adapts the character artwork for this project.

Each exercise guide should end with a “Built it → Broke it → Fixed it” strip,
using only real discoveries and rework from that milestone. See the existing
Remo conventions in `hexagon-exercises` for the visual strip pattern.

## Working with this repository

Milestone branches use the pattern `exercise-N-<slug>`, with separate commits
for the initial scaffold/tests and for the point when the relevant tests pass.
Completed milestones get a structured learning guide under `docs/`, linked
here and marked complete in the roadmap. The pinned toolchain is Elixir 1.20.4
with Erlang/OTP 29.1.1, managed with asdf. Run `bash scripts/setup.sh`; see
[docs/setup.md](docs/setup.md) for setup and workflow details.

## Guides and session notes

- [Setup and stack requirements](docs/setup.md)
- [IRC protocol and compatibility notes](docs/irc-protocol-notes.md)
- [Exercise 1 — IRC message framing and parser](docs/exercise-1-irc-message-framing-and-parser.md)
- Future exercise guides and optional session notes will live under `docs/`.

## References

- [Modern IRC client protocol](https://modern.ircdocs.horse/)
- [IRCv3 specifications](https://ircv3.net/irc/)
- [RFC 2812: Internet Relay Chat — Client Protocol](https://www.rfc-editor.org/rfc/rfc2812)
- [Elixir documentation](https://elixir-lang.org/docs.html)
- [Erlang/OTP documentation](https://www.erlang.org/docs)
- [Phoenix LiveView documentation](https://hexdocs.pm/phoenix_live_view/welcome.html)
- [Libera.Chat connection guide](https://libera.chat/guides/connect)
- [BrasIRC](https://brasirc.com.br/)

## License

Licensing is split by material; see [LICENSES.md](LICENSES.md) for details.
Future client source code will use Apache-2.0. The README, exercise guides, and
Remo artwork are shared under CC BY-NC-SA 4.0. Remo is an existing character by
Otto Horvath reused from
[hexagon-exercises](https://github.com/otto-horvath/hexagon-exercises); the
logo adapts the character artwork.
