#!/usr/bin/env bash
set -euo pipefail

ASDF_VERSION="0.20.2"
ASDF_BIN_DIR="${ASDF_BIN_DIR:-$HOME/.local/bin}"
ASDF_DATA_DIR="${ASDF_DATA_DIR:-$HOME/.asdf}"
export ASDF_DATA_DIR

install_asdf() {
  if command -v asdf >/dev/null 2>&1; then
    return
  fi

  if ! command -v curl >/dev/null 2>&1 || ! command -v tar >/dev/null 2>&1; then
    echo "curl and tar are required to install asdf." >&2
    exit 1
  fi

  local os arch archive url
  case "$(uname -s)" in
    Linux) os=linux ;;
    Darwin) os=darwin ;;
    *) echo "Unsupported operating system: $(uname -s)" >&2; exit 1 ;;
  esac
  case "$(uname -m)" in
    x86_64|amd64) arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
  esac

  archive="asdf-v${ASDF_VERSION}-${os}-${arch}.tar.gz"
  url="https://github.com/asdf-vm/asdf/releases/download/v${ASDF_VERSION}/${archive}"
  mkdir -p "$ASDF_BIN_DIR"
  curl --fail --location --silent --show-error "$url" | tar -xz -C "$ASDF_BIN_DIR" asdf
  chmod 0755 "$ASDF_BIN_DIR/asdf"
  export PATH="$ASDF_BIN_DIR:$PATH"
  echo "Installed asdf v${ASDF_VERSION} in $ASDF_BIN_DIR"
}

# Prints the rc file for the user's login shell, or nothing if unsupported.
shell_rc_file() {
  case "$(basename "${SHELL:-}")" in
    zsh) echo "${ZDOTDIR:-$HOME}/.zshrc" ;;
    bash)
      # macOS Terminal opens login shells, which read .bash_profile.
      if [ "$(uname -s)" = Darwin ]; then
        echo "$HOME/.bash_profile"
      else
        echo "$HOME/.bashrc"
      fi
      ;;
  esac
}

# Writes an idempotent PATH block so new terminals find asdf and its shims.
# Set SETUP_SKIP_SHELL_CONFIG=1 to manage the shell configuration yourself.
persist_shell_config() {
  local marker_start="# >>> asdf (exirc-exercises setup) >>>"
  local marker_end="# <<< asdf (exirc-exercises setup) <<<"
  local rc_file

  if [ "${SETUP_SKIP_SHELL_CONFIG:-0}" = 1 ]; then
    echo "Skipping shell configuration. Add $ASDF_BIN_DIR and $ASDF_DATA_DIR/shims to PATH yourself."
    return
  fi

  rc_file="$(shell_rc_file)"
  if [ -z "$rc_file" ]; then
    echo "Unsupported shell '${SHELL:-unknown}'. Add $ASDF_BIN_DIR and $ASDF_DATA_DIR/shims to PATH yourself."
    return
  fi

  if [ -f "$rc_file" ] && grep -qF "$marker_start" "$rc_file"; then
    echo "Shell configuration already present in $rc_file"
    return
  fi

  {
    echo ""
    echo "$marker_start"
    echo "export ASDF_DATA_DIR=\"$ASDF_DATA_DIR\""
    echo "export PATH=\"\$ASDF_DATA_DIR/shims:$ASDF_BIN_DIR:\$PATH\""
    echo "$marker_end"
  } >>"$rc_file"
  echo "Added asdf to PATH in $rc_file. Open a new terminal or run: source $rc_file"
}

install_build_deps() {
  if [ "$(uname -s)" != Darwin ]; then
    return
  fi

  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is required to install Erlang build dependencies on macOS." >&2
    exit 1
  fi

  # The asdf-erlang plugin passes these Homebrew prefixes to the Erlang build,
  # even when the formulae are not installed.
  brew install openssl@3 unixodbc
}

install_build_deps
install_asdf
export PATH="$ASDF_DATA_DIR/shims:$ASDF_BIN_DIR:$PATH"

asdf plugin list | grep -qx erlang || asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git
asdf plugin list | grep -qx elixir || asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git

asdf install
asdf reshim
elixir --version
persist_shell_config
echo "BEAM toolchain installed."
