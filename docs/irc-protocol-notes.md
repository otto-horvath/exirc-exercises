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

## Real-world integration targets

### BrasIRC

The official site lists the client endpoint as `irc.brasirc.com.br:6667` and
TLS on port `6697` ([BrasIRC](https://brasirc.com.br/)). Its 2026 migration
article reports an upgrade from InspIRCd 2 to InspIRCd 4
([migration note](https://brasirc.com.br/update-ircd/)). This is useful
implementation context, but InspIRCd 4 is server software, not a protocol
version. Confirm the current endpoint, TLS certificate behavior, capabilities,
and `005` values during the exercise.

### Libera.Chat

Libera.Chat documents TLS access at `irc.libera.chat:6697` and has a guide for
SASL account authentication ([connection guide](https://libera.chat/guides/connect)).
Use the guide for current connection/authentication details; do not place a
real SASL password in repository files or test fixtures.

## Testing policy

Use three layers deliberately:

1. **Pure tests** for message parsing, formatting, and protocol state decisions.
2. **Local integration tests** against a deterministic fake IRC server for TCP
   framing, registration, `PING`/`PONG`, and session behavior.
3. **Manual network checks** against BrasIRC and Libera.Chat for real-world
   compatibility and comparing advertised capabilities.

The automated suite should pass offline and must not depend on public servers,
network availability, or personal accounts. Manual observations should note
the date and redact nicknames, channels, or account data the user does not
want recorded.

## References

- [Modern IRC client protocol](https://modern.ircdocs.horse/)
- [IRCv3 specifications](https://ircv3.net/irc/)
- [RFC 2812](https://www.rfc-editor.org/rfc/rfc2812)
- [BrasIRC](https://brasirc.com.br/)
- [BrasIRC InspIRCd migration note](https://brasirc.com.br/update-ircd/)
- [Libera.Chat connection guide](https://libera.chat/guides/connect)
