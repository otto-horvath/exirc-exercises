# Setup and stack requirements

This document records the toolchain and local workflow for the exercise series.
The project pins the BEAM toolchain in `.tool-versions` and uses asdf, a
version-manager workflow common in the Elixir ecosystem. Run
`bash scripts/setup.sh` from the repository root. On macOS, the script first
uses Homebrew to install `openssl@3` and `unixodbc`, which the Erlang build
expects. It then installs the official asdf release binary when asdf is missing, adds the Erlang and Elixir
plugins, and installs the versions pinned in `.tool-versions`.

When the script installs asdf, it places the binary in `$HOME/.local/bin` by
default. Add both that directory and `$HOME/.asdf/shims` to your shell's `PATH`
to use the installed tools in future terminals. Erlang compilation may require
platform build tools and libraries listed by
the [asdf-erlang plugin](https://github.com/asdf-vm/asdf-erlang#before-installing).

## Required stack

| Component | Requirement for the series |
| --- | --- |
| Elixir | 1.20.4, pinned in `.tool-versions`; Mix requires `~> 1.20.0`. |
| Erlang/OTP | 29.1.1, pinned in `.tool-versions`; supported by Elixir 1.20.4. |
| Mix | Ships with Elixir; use it for dependencies, compilation, tests, and project tasks. |
| ExUnit | Ships with Elixir; use it for behavior-focused unit and integration tests. |
| Formatter | Elixir formatter (`mix format`) with project formatting rules committed alongside the project. |
| Version manager | asdf with the Erlang and Elixir plugins; `.tool-versions` is also understood by mise. |
| Network access | Needed for optional manual checks against BrasIRC and Libera.Chat; automated tests should not require public network access. |
| Phoenix / LiveView | Introduced only when the series reaches its LiveView milestone. |

No third-party IRC protocol library is selected for the initial learning path:
implementing the client protocol is part of the learning goal. If a dependency
is later proposed, document what it replaces and what remains learner-built.

## Version policy

Neither Elixir nor Erlang/OTP has a formal LTS release channel. Elixir publishes
stable releases; Erlang/OTP provides security fixes for its three latest release
branches. We use the latest stable Elixir release and a compatible, supported
OTP release, pinning exact versions for reproducibility.

The pins are refreshed deliberately, not automatically. When updating them,
check the [Elixir supported versions](https://elixir-lang.org/docs.html) and
[Erlang/OTP version support](https://www.erlang.org/versions), verify their
compatibility, and update `.tool-versions` and this document together. Recheck
compatibility when adding Phoenix/LiveView; do not silently change the baseline
toolchain mid-series.

## Mix commands

Once the setup script has installed the toolchain, use Mix directly:

```shell
mix deps.get
mix test
mix format
mix format --check-formatted
mix run
```

A later milestone may add focused test commands, local-server tasks, and
separate terminal/web run instructions.

## Network configuration

Real-network settings should be supplied through local, untracked configuration
or environment variables. Do not commit passwords, SASL credentials, client
certificate keys, or private channel details. Prefer TLS when the network
supports it. Record public endpoint/port information in documentation only
after verifying it against the network’s own guidance.

Targets for manual integration checks:

- BrasIRC: `irc.brasirc.com.br`, plain port `6667`, TLS port `6697`.
- Libera.Chat: `irc.libera.chat`, TLS port `6697`.
