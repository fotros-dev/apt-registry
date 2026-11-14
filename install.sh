#!/bin/sh
set -eu

DEFAULT_BASE="https://raw.githubusercontent.com/fotros-dev/apt-registry"
BIN_PATH="/usr/local/bin/apt-registry"
COMPLETION_DIR="/usr/share/bash-completion/completions"
COMPLETION_PATH="$COMPLETION_DIR/apt-registry"
APT_HELPER="/usr/lib/apt/apt-helper"
EXPECTED_SHEBANG="#!/usr/bin/env bash"

say() {
  printf 'apt-registry install: %s\n' "$*" >&2
}

die() {
  printf 'apt-registry install: error: %s\n' "$*" >&2
  exit 1
}

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    die "installing to $BIN_PATH needs root, and sudo is not installed; run this installer as root"
  fi
}

pick_downloader() {
  if command -v curl >/dev/null 2>&1; then
    echo curl
  elif command -v wget >/dev/null 2>&1; then
    echo wget
  elif [ -x "$APT_HELPER" ]; then
    echo apt-helper
  else
    die "need curl, wget or $APT_HELPER to download files"
  fi
}

download() {
  download_url=$1
  download_target=$2
  case $DOWNLOADER in
    curl) curl -fsSL -o "$download_target" "$download_url" ;;
    wget) wget -q -O "$download_target" "$download_url" ;;
    apt-helper) "$APT_HELPER" download-file "$download_url" "$download_target" >"$WORK_DIR/apt-helper.log" 2>&1 ||
      { cat "$WORK_DIR/apt-helper.log" >&2; return 1; } ;;
  esac
}

fetch() {
  fetch_name=$1
  fetch_target=$2
  fetch_url="$BASE/$REF/$fetch_name"
  download "$fetch_url" "$fetch_target" || die "could not download $fetch_url"
}

install_alternatives_hint() {
  echo "Check APT_REGISTRY_BASE and APT_REGISTRY_REF, or install the .deb from https://github.com/fotros-dev/apt-registry/releases instead."
}

verify_downloaded_script() {
  script_path=$1
  first_line=$(head -n 1 "$script_path" | cut -c 1-60)
  if [ "$first_line" != "$EXPECTED_SHEBANG" ]; then
    die "the download from $BASE/$REF/apt-registry is not the apt-registry script (first line: '$first_line'). $(install_alternatives_hint)"
  fi
  if ! bash "$script_path" version >/dev/null 2>&1; then
    die "the downloaded apt-registry does not run ('apt-registry version' failed). $(install_alternatives_hint)"
  fi
}

installed_version() {
  if [ -x "$BIN_PATH" ]; then
    "$BIN_PATH" version 2>/dev/null || true
  fi
}

install_files() {
  as_root install -d -m 0755 "$(dirname "$BIN_PATH")" "$COMPLETION_DIR"
  as_root install -m 0755 "$WORK_DIR/apt-registry" "$BIN_PATH"
  as_root install -m 0644 "$WORK_DIR/apt-registry.bash" "$COMPLETION_PATH"
}

report_installation() {
  previous_version=$1
  new_version=$("$BIN_PATH" version) || die "$BIN_PATH was installed but 'apt-registry version' failed"
  say "downloaded from $BASE/$REF with $DOWNLOADER"
  if [ -z "$previous_version" ]; then
    say "installed $BIN_PATH ($new_version)"
  elif [ "$previous_version" = "$new_version" ]; then
    say "reinstalled $BIN_PATH ($new_version, unchanged)"
  else
    say "updated $BIN_PATH ($previous_version -> $new_version)"
  fi
  say "installed $COMPLETION_PATH"
}

main() {
  REF=${APT_REGISTRY_REF:-main}
  BASE=${APT_REGISTRY_BASE:-$DEFAULT_BASE}
  BASE=${BASE%/}
  DOWNLOADER=$(pick_downloader)
  WORK_DIR=$(mktemp -d)
  chmod 0755 "$WORK_DIR"
  trap 'rm -rf "$WORK_DIR"' EXIT
  trap 'exit 1' INT TERM

  fetch apt-registry "$WORK_DIR/apt-registry"
  fetch completions/apt-registry.bash "$WORK_DIR/apt-registry.bash"
  verify_downloaded_script "$WORK_DIR/apt-registry"

  previous_version=$(installed_version)
  install_files
  report_installation "$previous_version"

  if [ -n "${APT_REGISTRY_URL:-}" ]; then
    say "running: apt-registry set $APT_REGISTRY_URL"
    as_root "$BIN_PATH" set "$APT_REGISTRY_URL"
  fi
}

main "$@"
