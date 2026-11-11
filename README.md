# WSL bootstrap

Set up an Ubuntu development environment with mise, Zsh, Docker, and Chrome.

**Target:** Ubuntu 26.04 amd64 on WSL 2, using the Windows OpenSSH client and agent.

## Prepare Windows

### Ubuntu distro

On an x64 Windows 11 machine, open **PowerShell as Administrator** and install the target distro:

```powershell
wsl --install --distribution Ubuntu-26.04
```

Restart Windows if requested. Open Ubuntu and create your regular Linux username and password; use this account for bootstrap and verification.

In a normal PowerShell window, update WSL and check the installed distro:

```powershell
wsl --update
wsl --set-default-version 2
wsl --list --verbose
wsl --set-default Ubuntu-26.04
wsl --distribution Ubuntu-26.04
```

The distro should show **VERSION 2**. If an existing installation shows version 1, close its applications and run `wsl --set-version Ubuntu-26.04 2` in PowerShell. Use `wsl --list --online` to check available distro names; this repository requires Ubuntu 26.04 rather than whichever release the unversioned `Ubuntu` entry installs.

Before bootstrapping Ubuntu, complete the [Windows OpenSSH](#windows-openssh) and [Terminal/font](#terminal-font) steps below. Keep project checkouts in the Linux filesystem, such as `~/projects`.

See Microsoft's [WSL installation guide](https://learn.microsoft.com/en-us/windows/wsl/install) and [command reference](https://learn.microsoft.com/en-us/windows/wsl/basic-commands).

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

Then run `./scripts/verify-setup.sh` from the checkout. See [Verify the setup](#verify-the-setup) for what it checks.

Package installation may ask for your sudo password. The `docker` group grants root-level access through the Docker daemon.

## What's included

| Area | Setup |
| --- | --- |
| Runtimes | Latest Node.js, Go, .NET SDK, and pnpm through mise |
| Build tools | GCC/G++, make, pkg-config, Python 3, and Python venv support |
| Utilities | jq, ripgrep (`rg`), fd-find (`fdfind`), GitHub CLI (`gh`), tmux, and rsync |
| Shell | Zsh as the default, Oh My Zsh, and the `git` plugin |
| Shell helpers | Autosuggestions, syntax highlighting, extra completions, and fzf |
| Prompt | Local `wsl-dev` theme based on marcduiker, with blank lines and Docker/Aspire segments |
| Containers | Native Docker Engine, Compose, and Buildx, started through systemd |
| Browser | Google Chrome Stable for WSLg and Playwright |
| Agent tooling | OpenAI Codex CLI (`codex`), Claude Code (`claude`), and Entire CLI with Zsh completion |
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
| Upgrade managed tool versions | `mise upgrade node go dotnet pnpm oh-my-posh fzf entire codex claude` |
| Apply only shared configuration files | `mise bootstrap --only dotfiles --yes` |
| Skip Git name/email questions | `./bootstrap.sh --skip-git-config` |
| Accept mise installation prompts | `./bootstrap.sh --yes` |
| Check installed state | `mise bootstrap status` |
| Verify the complete setup after reopening Ubuntu | `./scripts/verify-setup.sh` |
| Diagnose mise activation | `mise doctor` |
| Reload Zsh | `exec zsh -l` |
| Enable Entire capture in the current Git repo | `entire enable` |

Every normal bootstrap run checks for and installs the newest stable mise release, without a release-age delay. It keeps an existing current or newer version. `--dry-run` previews this step without downloading or updating mise. The `min_version` in `config.toml` is a compatibility floor, not a version pin.

Ordinary bootstrap runs keep existing shell checkouts at their current commits. `--update` fast-forwards them; local changes or an unexpected origin stop the operation. `--yes` still allows sudo and Git identity prompts.

## Windows integration

### ChatGPT desktop app

Bootstrap exposes the mise-managed Codex CLI and Claude Code at `~/.local/bin/codex` and `~/.local/bin/claude`. The ChatGPT desktop app checks this directory for Codex when running its agent in WSL. If you already ran bootstrap, run `mise bootstrap --only tools --yes` in Ubuntu to add the launchers.

### Windows OpenSSH

In **PowerShell as Administrator**, install the Windows OpenSSH client if needed and start its agent automatically:

```powershell
$sshClient = Get-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
if ($sshClient.State -ne 'Installed') {
    Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
}
Set-Service -Name ssh-agent -StartupType Automatic
Start-Service ssh-agent
Get-Service ssh-agent
```

In **normal PowerShell under your Windows account**, create a key only if you do not already have one, choose a passphrase, and load it. Adjust the path if your existing key has another name:

```powershell
$sshKey = Join-Path $env:USERPROFILE '.ssh\id_ed25519'
if (-not (Test-Path $sshKey)) {
    & "$env:WINDIR\System32\OpenSSH\ssh-keygen.exe" -t ed25519 -f $sshKey
}
& "$env:WINDIR\System32\OpenSSH\ssh-add.exe" $sshKey
Get-Content "$sshKey.pub"
```

Add the printed **public key** to [GitHub's SSH keys](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account). The private key stays on Windows. This setup uses the Windows OpenSSH client and agent for Git and interactive SSH.

Reopen Ubuntu and check:

```bash
command -v ssh.exe ssh-add.exe
ssh-add.exe -l             # List loaded keys
ssh.exe -T git@github.com  # Test GitHub authentication
```

The [GitHub connection test](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/testing-your-ssh-connection) should identify your account; GitHub returns exit code 1 even after successful authentication because it does not provide shell access. On the first connection, verify the host fingerprint before accepting it.

The interactive `ssh` wrapper loads keys when the agent is empty. Git calls `ssh.exe` directly, so load your key through Windows `ssh-add.exe` before Git operations if needed. Leave WSL's Windows interop and Windows PATH integration enabled so these executables remain available.

See Microsoft's [Windows OpenSSH key and agent guide](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement).

### Terminal font

1. Install **Windows Terminal** from the Microsoft Store if it is missing, then open **Settings**.
2. Select the **Ubuntu-26.04** profile and optionally make it the default under **Startup → Default profile**. Its command line should be `wsl.exe --distribution Ubuntu-26.04`; leave out any explicit `bash` command so the configured login shell can take effect.
3. Download the Meslo Nerd Font from [Nerd Fonts](https://www.nerdfonts.com/font-downloads), extract the archive, and install its `.ttf` files **on Windows**. Restart Windows Terminal so it sees the new font.
4. In the Ubuntu profile, open **Appearance → Font face**, select the installed Meslo Nerd Font family, and save. Set your editor's terminal to the same font; in VS Code the setting is `terminal.integrated.fontFamily`.

Open a new Ubuntu tab after bootstrap. The Zsh prompt should show icons instead of boxes. Font rendering needs a manual visual check; the verification command cannot inspect the host terminal's selected font.

See the [Oh My Posh font guide](https://ohmyposh.dev/docs/installation/fonts) and [Windows Terminal appearance settings](https://learn.microsoft.com/en-us/windows/terminal/customize-settings/profile-appearance).

### GUI apps and Playwright

Run `google-chrome` to open a browser through WSLg. Bootstrap reports whether display sockets are available; Windows-side GUI support is configured separately. See [WSLg setup](https://learn.microsoft.com/en-us/windows/wsl/tutorials/gui-apps).

For Playwright, install the dependency in your project and select the `chrome` channel. The browser is available at `/usr/bin/google-chrome`; `headless: false` opens a WSLg window. See the [Playwright browser guide](https://playwright.dev/docs/browsers#google-chrome--microsoft-edge).

## Verify the setup

Reopen Ubuntu after bootstrap, then run as your regular user from the checkout:

```bash
./scripts/verify-setup.sh
```

The command checks the supported platform, Ubuntu packages declared in `config.toml`, the base mise tools, runtime/SDK commands, Python venv support, the default shell, Docker services and local daemon access, Compose/Buildx, Windows SSH client and loaded agent keys, Git settings, DNS, Chrome, WSLg display sockets, and unexpired development certificate PEM files.

It reports **PASS**, **WARN**, or **FAIL** and returns exit code 1 if any required check fails. Missing Git identity, GUI sockets, and development certificates produce warnings because they involve personal or Windows-side setup. Certificate checks inspect existing public files and `SSL_CERT_DIR`; browser trust, GitHub authentication, and font rendering still need manual checks.

Verification does not install tools, start services, pull container images, import certificates, or contact GitHub over SSH. DNS checks resolve `mise.run` and `github.com`; skip them when offline:

```bash
./scripts/verify-setup.sh --offline
```

## Backup and restore

Before reinstalling, commit and push your repositories and save any uncommitted work. Keep a separate secure backup of Windows SSH keys and `%UserProfile%\.wslconfig`; a distro export does not contain Windows-side files.

For a consistent distro snapshot, save your work and stop applications first, then run in PowerShell. This terminates only the named distro:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\WSL-Backups"
wsl --terminate Ubuntu-26.04
wsl --export Ubuntu-26.04 "$env:USERPROFILE\WSL-Backups\Ubuntu-26.04.tar"
```

Restore to a **new distro name** and an unused installation directory so you can check it alongside the original:

```powershell
wsl --import Ubuntu-26.04-Restored "$env:LOCALAPPDATA\WSL\Ubuntu-26.04-Restored" "$env:USERPROFILE\WSL-Backups\Ubuntu-26.04.tar" --version 2
wsl --distribution Ubuntu-26.04-Restored --user "your-linux-user"
```

Replace `your-linux-user` with your original Ubuntu username. Check `/etc/wsl.conf` retains a `[user]` section with `default=your-linux-user` for future launches. Run the verification command in the restored checkout and check your files before retiring the original distro. Exports contain the distro's files, including credentials and Docker data, so store them securely.

See Microsoft's [WSL export/import reference](https://learn.microsoft.com/en-us/windows/wsl/basic-commands#export-a-distribution).

## Customize

| File | Change here |
| --- | --- |
| [config.toml](config.toml) | Tools, Ubuntu packages, repositories, folders, services, and login shell |
| [files/zshrc.sh](files/zshrc.sh) | Zsh plugins, aliases, completions, and certificate paths |
| [files/bashrc.sh](files/bashrc.sh) | Shared Bash settings |
| [files/gitconfig](files/gitconfig) | Shared Git defaults; personal settings stay in `~/.gitconfig` |
| [files/wsl-dev.omp.json](files/wsl-dev.omp.json) | Prompt colors, spacing, and segments |
| [bootstrap.sh](bootstrap.sh) | Mise installation and WSL/Docker prerequisite checks |
| [scripts/check-platform.sh](scripts/check-platform.sh) | Supported Ubuntu release, architecture, and WSL version |
| [scripts/verify-setup.sh](scripts/verify-setup.sh) | Read-only verification after setup |

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
| Bootstrap rejects the platform | Use Ubuntu 26.04 amd64 on WSL 2. The platform check runs before any setup changes; other releases and architectures need a reviewed package configuration. |
| Verification reports missing packages or tools | Rerun `./bootstrap.sh`, reopen Ubuntu, and verify again. |
| Windows SSH checks fail | Check the Windows `ssh-agent` service and loaded keys in PowerShell, and leave WSL Windows interop/PATH integration enabled. |
| Bootstrap refuses an existing mise configuration | Merge or move it first; the script requires `~/.config/mise` to be empty or already linked to this checkout. |
| Zsh settings do not load with a custom `ZDOTDIR` | This setup manages startup files in your home directory; leave `ZDOTDIR` unset or point it there. |

WSL configuration changes preserve other settings and save the first backup at `/etc/wsl.conf.pre-wsl-dev-setup`. Bootstrap never restarts WSL automatically.

## License

[MIT](LICENSE). The adapted Oh My Posh theme retains its [upstream copyright and license notice](files/wsl-dev.omp.LICENSE).
