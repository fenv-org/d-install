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

set -e

D_INSTALL_DEBUG=${D_INSTALL_DEBUG:-0}
if [[ "$D_INSTALL_DEBUG" == "1" ]]; then
  set -x
fi

# If no arguments provided, install latest version
if [[ $# -eq 0 ]]; then
  D_VERSION=$(\
    git -c 'versionsort.suffix=-' ls-remote \
      --tags \
      --sort='v:refname' \
      git@github.com:fenv-org/d.git \
    | cut -f2 \
    | sed 's#refs/tags/##')
else
  D_VERSION="$1"
fi

D_INSTALL_DIR=${D_INSTALL_DIR:-$HOME/.d}

export DENO_INSTALL="$D_INSTALL_DIR/deno"
export DENO_DIR="$DENO_INSTALL"

DENO="$DENO_DIR/bin/deno"
D_HOME="$D_INSTALL_DIR"
D_BIN="$D_HOME/bin"
RAW_CODE_BASE_URL="https://raw.githubusercontent.com/fenv-org/d/$D_VERSION"
DENO_INSTALLER="https://gist.githubusercontent.com/LukeChannings/09d53f5c364391042186518c8598b85e/raw/ac8cd8c675b985edd4b3e16df63ffef14d1f0e24/deno_install.sh"

function main() {
  reinstall_deno_if_needed
  install_d
}

function install_d() {
  echo "Installing d version: '$D_VERSION' to: '$D_INSTALL_DIR'"
  mkdir -p "$D_BIN"
  bundle_script \
    "$RAW_CODE_BASE_URL/driver/main.ts" \
    "$D_BIN/main.js"
  $DENO compile \
    --allow-all \
    --allow-read \
    --allow-write \
    --allow-env \
    --allow-net \
    --allow-run \
    --no-prompt \
    --output "$D_BIN/d" \
    "$D_BIN/main.js"
  rm "$D_BIN/main.js"
}

function reinstall_deno_if_needed() {
  local deno_version
  deno_version="$(retrieve_deno_version)"

  if should_remove_existing_deno "$deno_version"; then
    rm -rf "$DENO_INSTALL"
  fi

  if [[ ! -d "$DENO_INSTALL" ]]; then
    echo "Installing deno at: $DENO_INSTALL"
    curl -fsSL "$DENO_INSTALLER" \
      | sh -s "v$deno_version" \
      > /dev/null
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
  local url="$RAW_CODE_BASE_URL/lib/version/src/deno_version.ts"
  
  # The content of the file looks like:
  # export const DENO_VERSION = '1.37.0'
  #
  # Extracts "1.37.0" from the file.
  curl -sSL "$url" \
  | sed -n "s/.*'\([^']*\)'.*/\1/p"
}

function bundle_script() {
  echo "
import { bundle } from 'https://deno.land/x/emit/mod.ts'
import * as fs from 'https://deno.land/std/fs/mod.ts'
import * as path from 'https://deno.land/std/path/mod.ts'

const _path = '$1'.startsWith('http')
  ? '$1'
  : path.resolve('$1')
const { code, map } = await bundle(
  new URL(_path, import.meta.url)
)

if ('$2') {
  fs.ensureDirSync(path.dirname(path.resolve('$2')))
  Deno.writeTextFileSync('$2', \`// deno-fmt-ignore-file
// deno-lint-ignore-file
// This code was bundled using 'deno_emit' and 
// it's not recommended to edit it manually

\` + code)
} else {
  console.log(code)
}
" | \
  $DENO run \
    --allow-read \
    --allow-write \
    --allow-net \
    --allow-env=DENO_DIR,HOME,DENO_AUTH_TOKENS \
    -
}

main "$@"
