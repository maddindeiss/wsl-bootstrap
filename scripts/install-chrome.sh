#!/usr/bin/env bash
set -euo pipefail

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
[[ $EUID -ne 0 ]] || die 'Run as your regular user, without sudo.'
[[ $# -le 1 ]] || die 'Usage: bash scripts/install-chrome.sh [--dry-run]'
case "${1:-}" in
  '') dry_run=false ;;
  --dry-run) dry_run=true ;;
  *) die 'Usage: bash scripts/install-chrome.sh [--dry-run]' ;;
esac

# shellcheck source=/etc/os-release
source /etc/os-release
[[ $ID == ubuntu ]] || die 'This Chrome installer currently supports Ubuntu.'
[[ $(dpkg --print-architecture) == amd64 ]] || die 'This Chrome installer currently targets Ubuntu amd64.'

if [[ $(dpkg-query -W -f='${db:Status-Status}' google-chrome-stable 2>/dev/null || true) == installed ]]; then
  printf 'Google Chrome Stable is already installed.\n'
  exit 0
fi

download_url=https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
if "$dry_run"; then
  printf 'Would download Google Chrome Stable from %s\n' "$download_url"
  printf 'Would refresh apt metadata and install Chrome with its native dependencies using sudo.\n'
  exit 0
fi

# Authenticate before downloading. The package configures Google's update repository.
sudo -v
package_file=$(mktemp /tmp/wsl-dev-chrome.XXXXXXXX.deb)
trap 'rm -- "$package_file"' EXIT
curl --fail --silent --show-error --location "$download_url" --output "$package_file"
# Allow apt's unprivileged download user to read the local package.
chmod 0644 -- "$package_file"
sudo apt-get update
sudo apt-get install -y --no-install-recommends -- "$package_file"
google-chrome --version
