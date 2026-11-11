#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ./bootstrap.sh [--dry-run] [--yes] [--update] [--skip-git-config]

Install Zsh prerequisites and the newest stable mise, then apply the declared setup.
Mise clones Oh My Zsh and its plugins before installing Docker and development tools.
Mise also creates project folders and makes Zsh the default login shell.
Run as your regular Ubuntu user; package installation uses sudo when needed.
Requires Ubuntu 26.04 amd64 on WSL 2.
On WSL, enable systemd in /etc/wsl.conf before installing services.

  --dry-run          Preview without installing anything or changing configuration.
                     If mise is absent, only the initial setup steps can be previewed.
  --yes              Accept mise's package installation prompts.
  --update           Refresh package metadata and fast-forward managed repositories.
  --skip-git-config  Skip the interactive Git name and email questions.
USAGE
}

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

ensure_wsl_systemd() (
  # Use a subshell so cleanup does not replace the mise installer's EXIT trap.
  config_file=/etc/wsl.conf
  input_file=$config_file
  if [[ ! -e $config_file && ! -L $config_file ]]; then
    input_file=/dev/null
  fi
  updated_config=$(mktemp)
  trap 'rm -- "$updated_config"' EXIT
  awk -f "$repo_dir/scripts/enable-systemd.awk" "$input_file" > "$updated_config"
  if cmp -s -- "$input_file" "$updated_config"; then
    printf 'WSL configuration already enables systemd.\n'
  elif "$dry_run"; then
    printf 'Would merge [boot] systemd=true into /etc/wsl.conf, preserving other settings.\n'
  else
    if [[ -e $config_file && ! -e $config_file.pre-wsl-dev-setup && ! -L $config_file.pre-wsl-dev-setup ]]; then
      sudo cp --archive --no-clobber -- "$config_file" "$config_file.pre-wsl-dev-setup"
    fi
    sudo install -m 0644 -- "$updated_config" "$config_file"
    printf 'Enabled systemd in /etc/wsl.conf.\n'
  fi
)

report_wslg_status() {
  [[ -n ${WSL_DISTRO_NAME:-} || -n ${WSL_INTEROP:-} ]] || return 0
  local x11_ready=false wayland_ready=false wayland_socket
  if [[ ${DISPLAY:-} =~ ^:([0-9]+)(\.[0-9]+)?$ ]]; then
    [[ -S /tmp/.X11-unix/X${BASH_REMATCH[1]} ]] && x11_ready=true
  fi
  if [[ -n ${WAYLAND_DISPLAY:-} ]]; then
    if [[ $WAYLAND_DISPLAY == /* ]]; then
      wayland_socket=$WAYLAND_DISPLAY
    else
      wayland_socket="${XDG_RUNTIME_DIR:-/mnt/wslg/runtime-dir}/$WAYLAND_DISPLAY"
    fi
    [[ -S $wayland_socket ]] && wayland_ready=true
  fi
  if "$x11_ready" || "$wayland_ready"; then
    printf 'WSLg display sockets detected (X11: %s, Wayland: %s). Launch installed GUI apps by name.\n' "$x11_ready" "$wayland_ready"
  else
    printf 'WSLg display sockets not detected. See the Linux GUI apps section in README.md for Windows setup.\n'
  fi
}

dry_run=false
skip_git_config=false
mise_args=()
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=true; mise_args+=("$arg") ;;
    --yes|--update) mise_args+=("$arg") ;;
    --skip-git-config) skip_git_config=true ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $arg" ;;
  esac
done

[[ $EUID -ne 0 ]] || die 'Run this script as your regular user, without sudo.'
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
bash "$repo_dir/scripts/check-platform.sh"
# shellcheck source=/etc/os-release
source /etc/os-release
[[ -z ${MISE_GLOBAL_CONFIG_FILE:-} ]] || die 'Unset MISE_GLOBAL_CONFIG_FILE before running this setup.'

config_dir=${MISE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/mise}
mise_bin="$HOME/.local/bin/mise"
oh_my_zsh_dir="$HOME/.oh-my-zsh"

# Check before installing anything. An empty directory is safe to replace.
if [[ -e $config_dir || -L $config_dir ]]; then
  if [[ $(readlink -f -- "$config_dir") != "$repo_dir" ]]; then
    if [[ ! -d $config_dir || -L $config_dir || -n $(find "$config_dir" -mindepth 1 -maxdepth 1 -print -quit) ]]; then
      die "Existing mise configuration at $config_dir. Move or merge it before running this setup."
    fi
  fi
fi

if [[ -e $oh_my_zsh_dir || -L $oh_my_zsh_dir ]]; then
  [[ -f $oh_my_zsh_dir/oh-my-zsh.sh ]] || die "Existing unrelated or incomplete Oh My Zsh directory at $oh_my_zsh_dir. Move it before running this setup."
fi

# Configure future distro starts even when systemd is already running now.
if [[ -n ${WSL_DISTRO_NAME:-} || -n ${WSL_INTEROP:-} ]]; then
  ensure_wsl_systemd
  if [[ $(ps -p 1 -o comm=) != systemd ]]; then
    if "$dry_run"; then
      printf 'Would stop here until this WSL distro is restarted with systemd.\n'
    else
      printf '\nRestart this distro before continuing. Save your work, then run in Windows PowerShell:\n'
      if [[ -n ${WSL_DISTRO_NAME:-} ]]; then
        printf '  wsl --terminate "%s"\n' "$WSL_DISTRO_NAME"
      else
        printf '  wsl --shutdown\n'
      fi
      printf 'Reopen Ubuntu and rerun ./bootstrap.sh to install Docker and the remaining tools.\n'
    fi
    exit 0
  fi
else
  [[ $(ps -p 1 -o comm=) == systemd ]] || die 'Docker Engine needs systemd running as PID 1.'
fi
for path in /usr/bin/docker /var/run/docker.sock; do
  if [[ $(readlink -f -- "$path" 2>/dev/null || true) == /mnt/wsl/docker-desktop/* ]]; then
    die 'Disable Docker Desktop WSL integration for this distro before installing native Docker Engine.'
  fi
done

conflicting_packages=()
for package in docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc; do
  if [[ $(dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null || true) == installed ]]; then
    conflicting_packages+=("$package")
  fi
done
if ((${#conflicting_packages[@]})); then
  die "Conflicting Docker packages installed: ${conflicting_packages[*]}. Review and remove them before using Docker CE."
fi

missing_packages=()
for package in zsh ca-certificates curl git; do
  if [[ $(dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null || true) != installed ]]; then
    missing_packages+=("$package")
  fi
done

if "$dry_run"; then
  printf 'Preview: Ubuntu %s, user %s\n' "$VERSION_ID" "$(id -un)"
  report_wslg_status
  if ((${#missing_packages[@]})); then
    printf 'Would install prerequisites with apt: %s\n' "${missing_packages[*]}"
  fi
  printf 'Would install or update mise to the newest stable release at %s\n' "$mise_bin"
  printf 'Would link %s -> %s\n' "$config_dir" "$repo_dir"
  printf 'Would configure Docker group access in the final mise bootstrap task.\n'
  if ! "$skip_git_config"; then
    printf 'Would ask for Git name and email in an interactive terminal and save them in your global Git config.\n'
  fi
  if [[ -x $mise_bin ]]; then
    preview_mise=$mise_bin
  elif command -v mise >/dev/null 2>&1; then
    preview_mise=$(command -v mise)
  else
    printf 'Mise is not installed yet. See config.toml for the packages and dotfiles to apply.\n'
    exit 0
  fi
  cd -- "$repo_dir"
  MISE_CONFIG_DIR="$repo_dir" "$preview_mise" bootstrap --only repos "${mise_args[@]}"
  MISE_CONFIG_DIR="$repo_dir" "$preview_mise" bootstrap --skip repos "${mise_args[@]}"
  exit 0
fi

if ((${#missing_packages[@]})); then
  sudo apt-get update
  sudo apt-get install -y --no-install-recommends "${missing_packages[@]}"
fi

installer=$(mktemp)
trap 'rm -- "$installer"' EXIT
curl --fail --silent --show-error --location https://mise.run --output "$installer"
# Resolve the latest stable release on every run, without an inherited version
# pin or the installer's default release-age delay. Current/newer installs stay.
env -u MISE_VERSION MISE_SELF_UPDATE_MINIMUM_RELEASE_AGE=0s \
  MISE_INSTALL_PATH="$mise_bin" sh "$installer"

mkdir -p -- "$(dirname -- "$config_dir")"
if [[ ! -L $config_dir && $config_dir != "$repo_dir" ]]; then
  if [[ -d $config_dir ]]; then rmdir -- "$config_dir"; fi
  ln -s -- "$repo_dir" "$config_dir"
fi

cd -- "$repo_dir"
# Clone the shell framework before Docker packages and tools, without updating
# the same checkouts twice when --update is requested.
MISE_CONFIG_DIR="$repo_dir" "$mise_bin" bootstrap --only repos "${mise_args[@]}"
WSL_DEV_SETUP_SKIP_GIT_CONFIG="$skip_git_config" MISE_CONFIG_DIR="$repo_dir" \
  "$mise_bin" bootstrap --skip repos "${mise_args[@]}"
printf '\nSetup applied. Reopen Ubuntu to activate Zsh and Docker group access.\nThen run: ./scripts/verify-setup.sh\n'
printf 'Oh My Posh icons need a Nerd Font installed on Windows and selected in your terminal. See README.md.\n'
report_wslg_status
