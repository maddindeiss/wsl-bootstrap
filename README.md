# WSL bootstrap

Set up an Ubuntu development environment with mise, Zsh, Docker, and Chrome.

**Target:** Ubuntu 26.04 amd64 on WSL 2, using the Windows OpenSSH client and agent.

## Quick start

Keep Docker Desktop's WSL integration disabled for this distro; setup installs native Docker Engine.

Run inside Ubuntu as your regular user:

```bash
sudo apt-get update
sudo apt-get install -y --no-install-recommends ca-certificates curl git
mkdir -p ~/projects/private
git clone https://github.com/maddindeiss/wsl-bootstrap.git ~/projects/private/wsl-bootstrap
cd ~/projects/private/wsl-bootstrap
./bootstrap.sh --dry-run
./bootstrap.sh
```

If you already cloned the repo, run the last two commands from your checkout.

- **WSL restart:** bootstrap enables systemd. If it pauses for a restart, run the printed command in Windows PowerShell, reopen Ubuntu, and rerun bootstrap.
- **Git identity:** enter your name and email when prompted. They stay in your local `~/.gitconfig`; use a GitHub noreply email for public commits.
- **After setup:** reopen Ubuntu to activate the default Zsh shell and Docker group access. Set a [Nerd Font](#terminal-font) for prompt icons.

Package installation may ask for your sudo password. The `docker` group grants root-level access through the Docker daemon.

## What's included

| Area | Setup |
| --- | --- |
| Runtimes | Latest Node.js, Go, .NET SDK, and pnpm through mise |
| Shell | Zsh as the default, Oh My Zsh, and the `git` plugin |
| Shell helpers | Autosuggestions, syntax highlighting, extra completions, and fzf |
| Prompt | Local `wsl-dev` theme based on marcduiker, with blank lines and Docker/Aspire segments |
| Containers | Native Docker Engine, Compose, and Buildx, started through systemd |
| Browser | Google Chrome Stable for WSLg and Playwright |
| Agent tooling | Entire CLI, with Zsh completion |
| Git and SSH | [Shared Git defaults](files/gitconfig), Windows OpenSSH, and the Windows SSH agent |
| Project folders | `~/projects/work` and `~/projects/private`, both with mode `0755` |

Mise and Entire have Tab completion. fzf adds **Ctrl+R** for history, **Ctrl+T** for files, and **Alt+C** for directories. Press **Right Arrow** to accept a history suggestion.

Zsh also adds `~/.aspnet/dev-certs/trust` to `SSL_CERT_DIR`. The Aspire prompt segment needs the Aspire CLI on `PATH` for running-status detection; this setup does not install that CLI.

## Everyday commands

Update this setup from GitHub and apply it:

```bash
git pull --ff-only
./bootstrap.sh
```

| Action | Command |
| --- | --- |
| Refresh apt metadata and update shell repositories | `./bootstrap.sh --update` |
| Upgrade managed tool versions | `mise upgrade node go dotnet pnpm oh-my-posh fzf entire` |
| Apply only shared configuration files | `mise bootstrap --only dotfiles --yes` |
| Skip Git name/email questions | `./bootstrap.sh --skip-git-config` |
| Accept mise installation prompts | `./bootstrap.sh --yes` |
| Check installed state | `mise bootstrap status` |
| Diagnose mise activation | `mise doctor` |
| Reload Zsh | `exec zsh -l` |
| Enable Entire capture in the current Git repo | `entire enable` |

Ordinary bootstrap runs keep existing shell checkouts at their current commits. `--update` fast-forwards them; local changes or an unexpected origin stop the operation. `--yes` still allows sudo and Git identity prompts.

## Windows integration

### SSH

Configure the Windows SSH agent and register your public key with GitHub. Both Git and interactive SSH use `ssh.exe`.

```bash
ssh-add.exe -l             # List loaded keys
ssh-add.exe                # Load keys when needed
ssh.exe -T git@github.com  # Test GitHub authentication
```

The interactive `ssh` wrapper loads keys when the agent is empty. Git calls `ssh.exe` directly, so load keys with `ssh-add.exe` before Git operations if needed.

### Terminal font

Install a Nerd Font **on Windows**, then select it in Windows Terminal's Ubuntu profile under **Appearance → Font face**. Meslo is recommended. Set the font in your editor's terminal too.

See the [Oh My Posh font guide](https://ohmyposh.dev/docs/installation/fonts).

### GUI apps and Playwright

Run `google-chrome` to open a browser through WSLg. Bootstrap reports whether display sockets are available; Windows-side GUI support is configured separately. See [WSLg setup](https://learn.microsoft.com/en-us/windows/wsl/tutorials/gui-apps).

For Playwright, install the dependency in your project and select the `chrome` channel. The browser is available at `/usr/bin/google-chrome`; `headless: false` opens a WSLg window. See the [Playwright browser guide](https://playwright.dev/docs/browsers#google-chrome--microsoft-edge).

## Customize

| File | Change here |
| --- | --- |
| [config.toml](config.toml) | Tools, Ubuntu packages, repositories, folders, services, and login shell |
| [files/zshrc.sh](files/zshrc.sh) | Zsh plugins, aliases, completions, and certificate paths |
| [files/bashrc.sh](files/bashrc.sh) | Shared Bash settings |
| [files/gitconfig](files/gitconfig) | Shared Git defaults; personal settings stay in `~/.gitconfig` |
| [files/wsl-dev.omp.json](files/wsl-dev.omp.json) | Prompt colors, spacing, and segments |
| [.mise-version](.mise-version) | The mise release installed by bootstrap |

Put machine-specific overrides in `config.local.toml`, which Git ignores. Keep credentials outside the checkout; [.gitignore](.gitignore) excludes common credential files, while `.env.example` is allowed for placeholders.

Rerun bootstrap after changing declarations. Keep the checkout in place: `~/.config/mise` and the shared files link to it. Removing a package declaration does not uninstall the package.

Most setup is declared in mise. The wrapper handles initial installation and WSL/Docker checks; small helpers handle Chrome's first install and the final Docker/Git setup. Shell repositories are applied first to keep Oh My Zsh ahead of Docker and the development tools.

For optional modules and native repository adoption, see [mise modules](https://mise.jdx.dev/bootstrap/modules.html) and [bootstrap from a repository](https://mise.jdx.dev/bootstrap/from-repository.html). Use `./bootstrap.sh` for the initial WSL preparation.

## Troubleshooting

| Problem | Check |
| --- | --- |
| Ubuntu still opens Bash | Reopen Ubuntu or run `exec zsh -l`. Remove any explicit `bash` command from the terminal profile. |
| Prompt icons appear as boxes | Select the installed Windows Nerd Font in your terminal. |
| Git fails while `ssh -T` works | Run `ssh-add.exe -l` and `git config --show-origin --get core.sshCommand`; Git should use `ssh.exe`. |
| Docker needs sudo | Reopen the WSL login session after group setup. Keep Docker Desktop integration disabled. |
| Another Ubuntu release fails to install .NET dependencies | Replace `libicu78` in `config.toml` with that release's ICU runtime package. Chrome installation targets amd64. |
| Bootstrap refuses an existing mise configuration | Merge or move it first; the script requires `~/.config/mise` to be empty or already linked to this checkout. |
| Zsh settings do not load with a custom `ZDOTDIR` | This setup manages startup files in your home directory; leave `ZDOTDIR` unset or point it there. |

WSL configuration changes preserve other settings and save the first backup at `/etc/wsl.conf.pre-wsl-dev-setup`. Bootstrap never restarts WSL automatically.

## License

[MIT](LICENSE). The adapted Oh My Posh theme retains its [upstream copyright and license notice](files/wsl-dev.omp.LICENSE).
