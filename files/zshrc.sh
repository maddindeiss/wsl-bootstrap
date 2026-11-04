# Loaded from ~/.zshrc. Add shared Zsh settings and aliases here.

case "$PATH" in
  "$HOME/.local/bin"|"$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# Include ASP.NET development certificates without duplicating the trust path
# when this file is sourced again or a nested shell inherits the environment.
export SSL_CERT_DIR="${SSL_CERT_DIR:-/usr/lib/ssl/certs}"
case ":$SSL_CERT_DIR:" in
  *":$HOME/.aspnet/dev-certs/trust:"*) ;;
  *) export SSL_CERT_DIR="$SSL_CERT_DIR:$HOME/.aspnet/dev-certs/trust" ;;
esac

if [[ -x "$HOME/.local/bin/mise" ]]; then
  eval "$("$HOME/.local/bin/mise" activate zsh)"
fi

# Activate mise first so its Oh My Posh installation is available on PATH.
export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
# Extend fpath before Oh My Zsh runs compinit. Do not load zsh-completions
# through the plugins array, which would initialize completions a second time.
if [[ -d "${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-completions/src" ]]; then
  typeset -U fpath
  fpath=("${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-completions/src" $fpath)
fi

if command -v oh-my-posh >/dev/null 2>&1; then
  # Oh My Zsh supplies plugins and completions; Oh My Posh supplies the prompt.
  ZSH_THEME=""
else
  ZSH_THEME="${ZSH_THEME-robbyrussell}"
fi

# Existing .zshrc files may have already loaded Oh My Zsh.
if [[ -f "$ZSH/oh-my-zsh.sh" ]] && (( ! $+functions[omz] )); then
  if (( ! ${+plugins} )); then
    plugins=(git)
  fi
  source "$ZSH/oh-my-zsh.sh"
fi

# Register mise completion after Oh My Zsh has initialized compdef.
if [[ -x "$HOME/.local/bin/mise" ]] && (( $+functions[compdef] )); then
  source <("$HOME/.local/bin/mise" completion zsh)
fi

if command -v entire >/dev/null 2>&1 && (( $+functions[compdef] )); then
  source <(entire completion zsh)
fi

# Use the Windows OpenSSH client and agent when running in WSL.
if [[ -n ${WSL_DISTRO_NAME:-} || -n ${WSL_INTEROP:-} ]] && command -v ssh.exe >/dev/null 2>&1 && command -v ssh-add.exe >/dev/null 2>&1; then
  alias ssh-add='ssh-add.exe'
  unalias ssh 2>/dev/null || true
  function ssh {
    if ! command ssh-add.exe -l >/dev/null; then
      command ssh-add.exe || return $?
      printf '\033[92mSSH key(s) are now available in your Windows SSH agent.\033[0m\n'
    fi
    command ssh.exe "$@"
  }
fi

if command -v fzf >/dev/null 2>&1 && (( ! $+functions[fzf-history-widget] )); then
  source <(fzf --zsh)
fi

if [[ -f "${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && (( ! $+functions[_zsh_autosuggest_start] )); then
  source "${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

if command -v oh-my-posh >/dev/null 2>&1; then
  # Resolve through PATH so mise upgrades do not leave a stale executable path.
  eval "$(oh-my-posh init zsh --strict --config "$HOME/.config/wsl-dev-setup/wsl-dev.omp.json")"
fi

# Syntax highlighting must load after plugins and integrations that define widgets.
if [[ -f "${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && (( ! $+functions[_zsh_highlight] )); then
  source "${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
