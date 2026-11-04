# Loaded from ~/.bashrc. Add shared Bash settings and aliases here.

# Keep the user installation of mise ahead of system installations.
case "$PATH" in
  "$HOME/.local/bin"|"$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

if [ -x "$HOME/.local/bin/mise" ]; then
  eval "$("$HOME/.local/bin/mise" activate bash)"
fi
