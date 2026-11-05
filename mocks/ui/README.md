# exirc UI mocks

Clickable, dependency-free HTML mocks for the BrasIRC web client. They simulate an
IRC session in the browser: no socket is opened, no credentials are sent, and all
messages are fictional demo data.

## Run it

From the repository root:

```sh
python3 -m http.server 8080
```

Open <http://localhost:8080/mocks/ui/>.

There is no build step, package install, or external network request. You can also
open `mocks/ui/app.html` directly; without a saved session it starts as `guest`.

## What is here

| File | Purpose |
| --- | --- |
| `index.html` | Connect screen: nickname, optional channel, advanced password fields. |
| `app.html` | Main IRC shell: server status, top tabs, topic bar, message log, composer, member sidebar, demo panel, dialogs. |
| `styles.css` | Rosé Pine dark palette, Cascadia Mono stack, classic dense IRC layout, responsive drawer. |
| `connect.js` | Local validation and the handoff through `sessionStorage`. |
| `app.js` | Simulated session state, tabs, messages, members, shortcuts, commands, and demo events. |

## Try

- Connect as any nickname; the demo button uses `otter` and `#brasirc`.
- Click a nickname in the member list or a message to open a private tab.
- Use <kbd>Alt</kbd> + <kbd>1…9</kbd> to jump to a tab.
- Use <kbd>Alt</kbd> + <kbd>←</kbd>/<kbd>→</kbd> to cycle tabs.
- Type part of a nickname in the composer and press <kbd>Tab</kbd> to complete it.
  Press <kbd>Tab</kbd> again to cycle matches.
- Use the **Demo events** panel to add messages, mentions, joins, parts, DMs, and
  connection changes.
- Join another channel with the `+` button.
- Try `/me`, `/msg`, `/join`, `/clear`, and `/help` in the composer.
- On a narrow screen, open **Members** or **Demo** to use the drawer.

## Design decisions

- Classic IRC direction: dark, dense, monospace, no avatars and no chat bubbles.
- Top tabs are the only conversation navigation. They scroll horizontally when
  needed.
- The member list is a right sidebar on desktop and a drawer below 900px.
- The demo panel is visible on desktop inside the sidebar, so simulated server
  events are discoverable without a hidden menu.
- The UI is English. The server target is BrasIRC at `irc.brasirc.com.br:6697`
  (TLS), but the mock never contacts it.
- Rosé Pine colours are used as CSS custom properties. `#6e6a86` and `#31748f` are
  reserved for borders, icons, and secondary decoration because they are below AA
  contrast for normal text.
- Cascadia Mono is first in the font stack, with DejaVu Sans Mono and system
  monospace fallbacks.

## Simulation boundaries

- There is no IRC TCP client in the browser. The real application will need an
  Elixir/Phoenix process to hold the connection and push events to the UI.
- The connect form stores only the nickname and channel in `sessionStorage`.
  Password fields are intentionally unused and cleared before navigation.
- The reconnect flow is a 900ms local timer, not an actual connection attempt.
- Messages, members, channels, and private tabs live in memory and reset on reload.
- The sample nicknames, topics, and messages are fictional. Do not put real
  credentials or private BrasIRC content into the mock.

## Accessibility notes

- The top tabs use `role="tablist"`, `role="tab"`, roving `tabindex`, and
  arrow-key navigation.
- Dialogs use the native `<dialog>` element and close on Escape.
- The status pill, message log, and toast expose live updates.
- The mobile drawer returns focus to its trigger when closed.
- All controls are reachable by keyboard; `<kbd>Tab</kbd>` in the composer is
  intentionally reserved for nickname completion rather than focus traversal.

## Known limitations

- No persistence, history paging, tab closing, nick changes, or real IRC state.
- No automatic ambient events; use the demo controls.
- The member list is a small fixed array; channel rank and voice prefixes are
  visual only.
- The file is a design proposal, not production UI code.
