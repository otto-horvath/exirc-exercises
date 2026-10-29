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
  echo "Add $ASDF_BIN_DIR to PATH in your shell configuration to use asdf later."
}

install_asdf
export PATH="$ASDF_DATA_DIR/shims:$ASDF_BIN_DIR:$PATH"

asdf plugin list | grep -qx erlang || asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git
asdf plugin list | grep -qx elixir || asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git

asdf install
asdf reshim
elixir --version
echo "BEAM toolchain installed. Add $ASDF_BIN_DIR and $ASDF_DATA_DIR/shims to PATH in your shell configuration to use it in a new terminal."
