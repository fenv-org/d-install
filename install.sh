#!/usr/bin/env bash

# Install `https://github.com/fenv-org/d` CLI tool
#
# How to use:
#
# - Install latest version
#   curl -sSL https://raw.githubusercontent.com/fenv-org/d/master/install.sh \
#     | bash
#
# - Install specific version to specific directory
#   curl -sSL https://raw.githubusercontent.com/fenv-org/d/master/install.sh \
#     | D_INSTALL_DIR=another_path bash -s vX.Y.Z
#
# Environment variables:
#  D_INSTALL_DIR - directory to install `d` to (default: $HOME/.d)

set -euo pipefail

D_INSTALL_DEBUG=${D_INSTALL_DEBUG:-0}
if [[ "$D_INSTALL_DEBUG" == "1" ]]; then
  set -x
fi

# If no arguments provided, install latest version
if [[ $# -eq 0 ]]; then
  D_VERSION="latest"
else
  D_VERSION="$1"
fi

D_INSTALL_DIR=${D_INSTALL_DIR:-$HOME/.d}

export DENO_INSTALL="$D_INSTALL_DIR/deno"
export DENO_DIR="$DENO_INSTALL"

DENO="$DENO_DIR/bin/deno"
CURL="curl -fsSL"

D_HOME="$D_INSTALL_DIR"
D_BIN="$D_HOME/bin"
D_CLI=${D_CLI:-d}
RELEASE_BASE_URL="https://github.com/fenv-org/d/releases"
DENO_INSTALLER="https://gist.githubusercontent.com/LukeChannings/09d53f5c364391042186518c8598b85e/raw/ac8cd8c675b985edd4b3e16df63ffef14d1f0e24/deno_install.sh"
if [[ "$D_VERSION" == "latest" ]]; then
  DOWNLOAD_BASE_URL="$RELEASE_BASE_URL/latest/download"
else
  DOWNLOAD_BASE_URL="$RELEASE_BASE_URL/download/$D_VERSION"
fi

function main() {
  reinstall_deno_if_needed
  install_d
  cleanup
  show_instruction
}

function install_d() {
  echo "Installing d version: '$D_VERSION' to: '$D_INSTALL_DIR'"
  mkdir -p "$D_BIN"
  $CURL --output "$D_BIN/main.js" "$DOWNLOAD_BASE_URL/main.js"
  rm -f "$D_BIN/d"
  rm -f "$D_BIN/$D_CLI"
  $DENO compile \
    --allow-all \
    --allow-read \
    --allow-write \
    --allow-env \
    --allow-net \
    --allow-run \
    --no-prompt \
    --output "$D_BIN/$D_CLI" \
    "$D_BIN/main.js"
}

function cleanup() {
  rm -rf "$DENO_INSTALL"
  rm -f "$D_BIN/main.js"
}

function reinstall_deno_if_needed() {
  local deno_version
  deno_version="$(retrieve_deno_version)"

  if should_remove_existing_deno "$deno_version"; then
    rm -rf "$DENO_INSTALL"
  fi

  if [[ ! -d "$DENO_INSTALL" ]]; then
    $CURL "$DENO_INSTALLER" | sh -s "v$deno_version" > /dev/null
    echo "$deno_version" > "$DENO_INSTALL/deno_version"
  fi
}

function should_remove_existing_deno() {
  if [[ ! -d "$DENO_INSTALL" ]]; then
    return 1
  fi

  local deno_version
  local installed_version
  local higher_version

  deno_version="$1"
  if [[ ! -f "$DENO_INSTALL/deno_version" ]]; then
    return 0
  fi

  installed_version="$(cat "$DENO_INSTALL/deno_version")"
  if [[ "$installed_version" == "$deno_version" ]]; then
    return 1
  fi

  higher_version="$(\
    echo -e "$deno_version\n$installed_version" \
    | sort --version-sort \
    | tail -n1)"
  if [[ "$higher_version" == "$deno_version" ]]; then
    return 0
  fi
  return 1
}

function retrieve_deno_version() {
  $CURL "$DOWNLOAD_BASE_URL/default.dvmrc"
}

function show_instruction() {
  local d_install_dir
  if [[ "$D_INSTALL_DIR" == "$HOME/.d" ]]; then
    d_install_dir="\$HOME/.d"
  else
    d_install_dir="$D_INSTALL_DIR"
  fi

  echo "\`d\` was installed successfully to '$d_install_dir'"
  echo ""
  echo "** To 'bash' or 'zsh' users **"
  echo "Add the following to the end of your ~/.bashrc or ~/.zshrc:"
  echo ""
  echo "export D_HOME=\"$d_install_dir\""
  echo "export PATH=\"\$D_HOME/bin:\$PATH\""
  echo ""
  echo "** To 'fish' users **"
  echo "Execute the following:"
  echo ""
  echo "mkdir -p \$HOME/.config/fish/conf.d"
  echo "echo \"set -gx D_HOME $d_install_dir\" > \$HOME/.config/fish/conf.d/d.fish"
  echo "fish_add_path \$D_HOME/bin"
}

main "$@"
