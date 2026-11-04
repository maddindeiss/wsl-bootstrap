#!/usr/bin/env bash
set -euo pipefail

# Called by mise's bootstrap task after packages and tools are installed.
[[ $EUID -ne 0 ]] || { printf 'Run as your regular user, without sudo.\n' >&2; exit 1; }

configure_docker_access() {
  local current_user
  current_user=$(id -un)
  if [[ " $(id -nG "$current_user") " != *' docker '* ]]; then
    sudo usermod -aG docker "$current_user"
  fi
  if [[ " $(id -nG) " != *' docker '* ]]; then
    printf '\nDocker group access needs a new login session. Reopen WSL before running Docker without sudo.\n'
  fi
}

configure_git_identity() {
  if [[ ${WSL_DEV_SETUP_SKIP_GIT_CONFIG:-false} == true ]]; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    printf '\nGit identity questions skipped: no interactive terminal.\n'
    return 0
  fi

  local current_name current_email git_name git_email
  current_name=$(git config --global --get user.name || true)
  current_email=$(git config --global --get user.email || true)

  printf '\nGit identity (saved in your global Git config, outside this repository).\n'
  printf 'Press Enter to keep an existing value or leave an unset value unconfigured.\n'
  if ! read -r -p "Git name${current_name:+ [$current_name]}: " git_name; then
    printf '\nGit identity unchanged: input ended.\n'
    return 0
  fi
  if ! read -r -p "Git email${current_email:+ [$current_email]}: " git_email; then
    printf '\nGit identity unchanged: input ended.\n'
    return 0
  fi

  if [[ -n $git_name && $git_name != "$current_name" ]]; then
    git config --global -- user.name "$git_name"
  fi
  if [[ -n $git_email && $git_email != "$current_email" ]]; then
    git config --global -- user.email "$git_email"
  fi
}

configure_docker_access
configure_git_identity
