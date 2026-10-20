# Setup and stack requirements

This document records the intended setup for the exercise series. The current
repository draft is documentation-only: there is no `mix.exs`, lockfile,
`.tool-versions`, CI workflow, or runnable code yet. Exact version pins and
commands should be confirmed when the first implementation scaffold is made,
not guessed in advance.

## Required stack

| Component | Requirement for the series |
| --- | --- |
| Elixir | Current stable release selected when the Mix project is created; pin it for local development and CI. |
| Erlang/OTP | A supported OTP release compatible with the selected Elixir version; record the tested version alongside Elixir. |
| Mix | Ships with Elixir; use it for dependencies, compilation, tests, and project tasks. |
| ExUnit | Ships with Elixir; use it for behavior-focused unit and integration tests. |
| Formatter | Elixir formatter (`mix format`) with project formatting rules committed alongside the project. |
| Network access | Needed for optional manual checks against BrasIRC and Libera.Chat; automated tests should not require public network access. |
| Phoenix / LiveView | Introduced only when the series reaches its LiveView milestone. |

No third-party IRC protocol library is selected for the initial learning path:
implementing the client protocol is part of the learning goal. If a dependency
is later proposed, document what it replaces and what remains learner-built.

## Version policy

When the Mix project is scaffolded:

1. Select a current stable Elixir release and a compatible supported OTP
   release.
2. Record exact versions in a tool-version file or equivalent, and use those
   versions in CI.
3. State the supported version range in this file and the README.
4. Recheck compatibility when adding Phoenix/LiveView; do not silently change
   the baseline toolchain mid-series.

## Planned commands

Once a Mix project exists, document and verify the exact commands for:

```shell
mix deps.get
mix test
mix format
mix format --check-formatted
mix run
```

These are the expected Mix workflow, not commands that work in this
documentation-only draft. A later milestone may add focused test commands,
local-server tasks, and separate terminal/web run instructions.

## Network configuration

Real-network settings should be supplied through local, untracked configuration
or environment variables. Do not commit passwords, SASL credentials, client
certificate keys, or private channel details. Prefer TLS when the network
supports it. Record public endpoint/port information in documentation only
after verifying it against the network’s own guidance.

Targets for manual integration checks:

- BrasIRC: `irc.brasirc.com.br`, plain port `6667`, TLS port `6697`.
- Libera.Chat: `irc.libera.chat`, TLS port `6697`.
