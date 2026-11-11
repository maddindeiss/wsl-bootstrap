#!/usr/bin/env bash
set -euo pipefail

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

# Check the target before bootstrap changes WSL, packages, or user configuration.
# shellcheck source=/etc/os-release
source /etc/os-release
[[ ${ID:-} == ubuntu && ${VERSION_ID:-} == 26.04 ]] || \
  die "This setup requires Ubuntu 26.04; detected ${PRETTY_NAME:-unknown Linux}."
architecture=$(dpkg --print-architecture)
[[ $architecture == amd64 ]] || \
  die "This setup requires amd64; detected $architecture."
kernel_release=$(uname -r)
[[ ${kernel_release,,} == *microsoft*wsl2* ]] || \
  die "This setup requires WSL 2; detected kernel $kernel_release. Check wsl --list --verbose in PowerShell."

printf 'Supported platform: Ubuntu 26.04 amd64 on WSL 2.\n'
