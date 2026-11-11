#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ./scripts/verify-setup.sh [--offline]

Check the installed WSL setup without installing or changing configuration.
Run as your regular user after reopening Ubuntu following bootstrap.

  --offline  Skip DNS lookups; local service and Windows agent checks still run.
  --help     Show this help.

Exit status: 0 when required checks pass (warnings are allowed), 1 on failure.
USAGE
}

offline=false
for argument in "$@"; do
  case "$argument" in
    --offline) offline=true ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; printf 'Unknown argument: %s\n' "$argument" >&2; exit 1 ;;
  esac
done
[[ $EUID -ne 0 ]] || { printf 'Run as your regular user, without sudo.\n' >&2; exit 1; }

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd -- "$repo_dir"
passed=0
warnings=0
failures=0
pass() { printf 'PASS %s\n' "$*"; passed=$((passed + 1)); }
warn() { printf 'WARN %s\n' "$*"; warnings=$((warnings + 1)); }
fail() { printf 'FAIL %s\n' "$*"; failures=$((failures + 1)); }
check() {
  local label=$1
  shift
  if timeout 15s "$@" >/dev/null 2>&1; then pass "$label"; else fail "$label"; fi
}

if ! command -v timeout >/dev/null 2>&1; then
  printf 'FAIL timeout is missing; install Ubuntu coreutils before verifying.\n' >&2
  exit 1
fi

if platform=$(bash "$repo_dir/scripts/check-platform.sh" 2>&1); then
  pass "$platform"
else
  fail "$platform"
fi

# Read package declarations so checks stay in sync with config.toml.
if packages=$(python3 - "$repo_dir/config.toml" 2>/dev/null <<'PY'
import sys, tomllib
with open(sys.argv[1], 'rb') as source:
    config = tomllib.load(source)
for package in config['bootstrap']['packages']:
    if package.startswith('apt:'):
        print(package.removeprefix('apt:'))
PY
); then
  while IFS= read -r package; do
    if [[ $(dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null || true) == installed ]]; then
      pass "Package $package"
    else
      fail "Package $package is missing; rerun ./bootstrap.sh"
    fi
  done <<< "$packages"
else
  fail 'Cannot read package declarations; Python 3 with tomllib is required'
fi
check 'Python venv and ensurepip modules' python3 -c 'import venv, ensurepip'

# Resolve installed binaries directly: do not run shims that could auto-install.
# Keep mise queries offline and disable any automatic self-update setting.
export MISE_OFFLINE=1 MISE_SELF_UPDATE_AUTO=false
mise_bin="$HOME/.local/bin/mise"
if [[ -x $mise_bin ]]; then
  check 'Mise executable' "$mise_bin" --version
  for tool in node go dotnet pnpm oh-my-posh fzf entire codex claude; do
    if tool_path=$(timeout 15s "$mise_bin" which "$tool" 2>/dev/null) && [[ -x $tool_path ]]; then
      case "$tool" in
        node|pnpm) version_args=(--version) ;;
        go) version_args=(version) ;;
        dotnet) version_args=(--list-sdks) ;;
        *) pass "Mise tool $tool"; continue ;;
      esac
      if version=$(timeout 15s "$tool_path" "${version_args[@]}" 2>/dev/null) && [[ -n $version ]]; then
        pass "$tool: ${version%%$'\n'*}"
      else
        fail "$tool is installed but cannot report its runtime/SDK version"
      fi
    else
      fail "Mise tool $tool is missing; rerun ./bootstrap.sh"
    fi
  done
else
  fail 'Mise is missing from ~/.local/bin; rerun ./bootstrap.sh'
fi

if [[ $(ps -p 1 -o comm=) == systemd ]]; then pass 'systemd is PID 1'; else fail 'systemd is not PID 1; restart the WSL distro'; fi
check 'Docker service is active' systemctl is-active --quiet docker
check 'Docker service is enabled' systemctl is-enabled --quiet docker
check 'containerd service is active' systemctl is-active --quiet containerd
check 'Local Docker daemon works without sudo (reopen Ubuntu if this fails)' \
  docker --host unix:///var/run/docker.sock info --format '{{.ServerVersion}}'
check 'Docker Compose plugin' docker compose version
check 'Docker Buildx plugin' docker buildx version

check 'Windows OpenSSH client runs from WSL' ssh.exe -V
check 'Windows SSH agent has a loaded key (run ssh-add.exe in PowerShell if needed)' ssh-add.exe -l
if [[ $(git config --get core.sshCommand || true) == ssh.exe ]]; then
  pass 'Git uses Windows OpenSSH'
else
  fail 'Git core.sshCommand must be ssh.exe'
fi
for setting in user.name user.email; do
  if [[ -n $(git config --get "$setting" || true) ]]; then pass "Git $setting is configured"; else warn "Git $setting is unset"; fi
done
if login_entry=$(getent passwd "$(id -u)") && [[ ${login_entry##*:} == */zsh ]]; then
  pass 'Default login shell is Zsh'
else
  fail 'Default login shell is not Zsh; rerun ./bootstrap.sh'
fi

if "$offline"; then
  printf 'SKIP DNS lookups (--offline)\n'
else
  for hostname in mise.run github.com; do
    check "DNS resolves $hostname" getent ahosts "$hostname"
  done
fi

check 'Google Chrome executable' google-chrome --version
gui_ready=false
if [[ ${DISPLAY:-} =~ ^:([0-9]+)(\.[0-9]+)?$ ]] && [[ -S /tmp/.X11-unix/X${BASH_REMATCH[1]} ]]; then
  gui_ready=true
fi
if [[ -n ${WAYLAND_DISPLAY:-} ]]; then
  wayland_socket=$WAYLAND_DISPLAY
  [[ $wayland_socket == /* ]] || wayland_socket="${XDG_RUNTIME_DIR:-/mnt/wslg/runtime-dir}/$wayland_socket"
  [[ ! -S $wayland_socket ]] || gui_ready=true
fi
if "$gui_ready"; then pass 'WSLg display socket is available'; else warn 'No WSLg display socket; check Windows GUI support before opening Chrome'; fi

# Certificates are optional personal setup. Inspect public PEM files only;
# running dotnet dev-certs could initialize or change the user's certificate store.
trust_dir="$HOME/.aspnet/dev-certs/trust"
certificate_ready=false
shopt -s nullglob
for certificate in "$trust_dir"/*.pem; do
  if timeout 15s openssl x509 -in "$certificate" -noout -checkend 0 >/dev/null 2>&1; then
    certificate_ready=true
    break
  fi
done
if "$certificate_ready"; then
  pass 'An unexpired ASP.NET development certificate PEM is present'
  case ":${SSL_CERT_DIR:-}:" in
    *":$trust_dir:"*) pass 'SSL_CERT_DIR includes the development certificate directory' ;;
    *) warn 'SSL_CERT_DIR does not include the development certificate directory; reopen Zsh' ;;
  esac
else
  warn 'No unexpired ASP.NET development certificate PEM found; configure HTTPS certificates if needed'
fi

printf '\nVerification: %s passed, %s warnings, %s failed.\n' "$passed" "$warnings" "$failures"
[[ $failures -eq 0 ]]
