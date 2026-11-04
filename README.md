# WSL bootstrap

Repeatable setup for Ubuntu 26.04 amd64 on WSL 2, with mise managing tools,
Ubuntu packages, and dotfiles. Windows OpenSSH supplies the SSH client and agent.
Other Ubuntu releases need the matching ICU runtime package in `config.toml`.

## Apply to this distro

Run from this checkout inside Ubuntu as your regular user:

```bash
./bootstrap.sh --dry-run
./bootstrap.sh
```

On WSL, the script first ensures `/etc/wsl.conf` contains `[boot] systemd=true`,
preserving other settings. If systemd is not running yet, it stops after this
step and prints the Windows command to restart that distro. Reopen Ubuntu and
rerun bootstrap afterward; Docker installation needs systemd running.

The script installs Zsh and missing prerequisites (`ca-certificates`, `curl`, and
`git`) first, installs the mise release in `.mise-version` into `~/.local/bin`,
and links `~/.config/mise` to this checkout. It then runs mise in two phases:
`mise bootstrap --only repos` clones Oh My Zsh and its plugins first, and
`mise bootstrap --skip repos` applies the rest. This keeps the shell framework
ahead of Docker and the development tools, including on a fresh distro.

Most setup is declared in `config.toml`:

| Setup | Mise declaration |
| --- | --- |
| `~/projects/work` and `~/projects/private` | `[bootstrap.directories]` |
| Oh My Zsh and the three Zsh plugin checkouts | `[bootstrap.repos]` |
| Zsh as the default login shell | `[bootstrap.user]` |
| Ubuntu packages and Docker's apt repository | `[bootstrap.packages]` and `[bootstrap.apt.sources]` |
| Docker's systemd service | `[bootstrap.services]` |
| Development tools | `[tools]` |
| Shared Git config, shell startup files, and the Oh My Posh theme | `[dotfiles]` |
| Chrome's initial `.deb` installation | `[bootstrap.hooks.pre-packages]` |
| Docker group access and the personal Git questions | `[tasks.bootstrap]` |

The wrapper keeps the steps needed before mise can take over: WSL's systemd
merge and restart check, Docker conflict checks, the first prerequisites,
mise installation, and the config link. Chrome still uses a small installer
because its `.deb` sets up Google's apt repository. The final task uses
`scripts/finalize-setup.sh` for Docker membership and interactive Git input.
These helpers skip work that is already done; native resources compare the
declared state before changing it.

Mise creates missing project folders and parents while preserving existing
contents. The two project folders have mode `0755`, as declared in the config;
mise also repairs that mode on later runs. It adds marked blocks to `.bashrc`,
`.profile`, `.zshrc`, and `.zprofile`. Existing shell configuration is preserved;
shared settings stay in `files/bashrc.sh` and `files/zshrc.sh`. Mise makes Zsh
the default login shell. New Ubuntu terminals load the local `wsl-dev` theme.

Docker Engine runs directly inside Ubuntu, with Compose and Buildx plugins from
Docker's official stable apt repository. Mise manages the repository, packages,
and Docker systemd service. Bootstrap adds your user to the `docker` group;
reopen your WSL login session afterward to use Docker without sudo. This group
grants root-level access through the Docker daemon. Verify the installation with
`docker version`, `docker compose version`, and `docker buildx version`.

Bootstrap enables systemd in the distro automatically. Its configuration is:

```ini
[boot]
systemd=true
```

Keep Docker Desktop's WSL integration disabled for this distro. Bootstrap stops
if it detects Desktop-managed Docker paths or conflicting Ubuntu Docker packages;
it does not remove them automatically. Existing remote Docker contexts and
`DOCKER_HOST` settings are kept; use `docker --host unix:///var/run/docker.sock version`
to explicitly check the native engine. To upgrade the declared system packages
later, run `mise bootstrap packages upgrade`.

Zsh activates mise first, adds extra completion definitions before Oh My Zsh
initializes completion, then loads fzf, autosuggestions, and the Oh My Posh
prompt. Syntax highlighting loads last. Oh My Zsh's own theme is disabled
while Oh My Posh is available. Existing plugin choices are kept; fresh setups
use the `git` plugin. If Oh My Posh is unavailable, Zsh uses the existing Oh My
Zsh theme or `robbyrussell` as a fallback. An already loaded Oh My Zsh is not
loaded again. Use `omz update` inside Zsh to update the framework.

Zsh loads `mise completion zsh` after Oh My Zsh initializes completion. Tab
completes mise commands, options, tools, versions, and task names. Generating
the script at shell startup keeps it in sync with the installed mise release;
it does not need a separate `usage` CLI or another `compinit` call. See the
[mise completion instructions](https://mise.jdx.dev/shell-setup.html#completions).

The additional plugins are `zsh-autosuggestions`, `zsh-syntax-highlighting`, and
`zsh-completions`, cloned from `zsh-users` into Oh My Zsh's custom plugin
directory. `ZSH_CUSTOM` is respected. Ordinary runs keep existing checkouts at
their current commits. Use `./bootstrap.sh --update` or
`mise bootstrap repos update` to fast-forward the managed shell repositories.
Mise stops on local changes or an unexpected origin instead of overwriting them.
To update just one plugin, use `mise bootstrap repos update
~/.oh-my-zsh/custom/plugins/PLUGIN_NAME` (adjust the path for `ZSH_CUSTOM`).
`zsh-completions` extends `fpath` directly and should not be added to `plugins=(...)`.

Autosuggestions show matching history entries as faint text; press Right Arrow
at the end of the line to accept one. fzf provides **Ctrl+R** for history search,
**Ctrl+T** for file selection, and **Alt+C** for directory selection. Syntax
highlighting colors the command as you type. Start a fresh Zsh shell after
installing the plugins so the new completion definitions are registered.

In WSL, when `ssh.exe` and `ssh-add.exe` are on `PATH`, `ssh-add` uses Windows
OpenSSH. The `ssh` wrapper checks the Windows agent for keys, runs `ssh-add.exe`
if needed, then forwards all arguments to `ssh.exe`. Failed key loading stops
the connection; a successful load prints a confirmation. Configure the Windows
`ssh-agent` service and keys on Windows. Clearing keys when Windows locks is a
separate Windows configuration; this setup does not configure that behavior.

Shared Git defaults live in `files/gitconfig`. Bootstrap links it at
`~/.config/wsl-dev-setup/gitconfig` and prepends an include to `~/.gitconfig`.
The personal file stays local, and existing settings after the include override
the shared defaults. Your name and email remain outside this repository.

The base config sets `core.sshCommand = ssh.exe`, so Git uses Windows OpenSSH
and its agent as well as interactive `ssh` commands. It also uses `main` for
new repositories, prunes stale remote branches when fetching, allows only
fast-forward pulls, and sets upstream tracking on the first default push.
It also sets `core.eol = lf`, `core.autocrlf = input`, and `core.symlinks = true`.
Git uses the Windows SSH configuration and keys; the Zsh key-loading wrapper
is not run by Git. Use `ssh-add.exe -l` to check loaded keys and `ssh-add.exe`
to load them when needed.

Apply only the shared Git and other dotfiles on an existing setup with
`mise bootstrap --only dotfiles --yes`. Check the effective SSH setting with
`git config --show-origin --get core.sshCommand`. To choose a different client,
set `git config --global core.sshCommand CLIENT`, or use a repository-local
override. See [Git's configuration includes](https://git-scm.com/docs/git-config#_includes).

Node.js, Go, the .NET SDK, pnpm, Oh My Posh, fzf, and Entire are managed by mise with `latest`
versions. To upgrade already installed tools to the newest releases later, run
`mise upgrade node go dotnet pnpm oh-my-posh fzf entire`.

Check the Entire CLI with `entire version`. To enable session capture in a
project, run `entire enable` from that project's Git repository. Project hooks
and agent integration are configured by that command. Zsh loads
`entire completion zsh` after Oh My Zsh initializes completion, enabling Tab
completion for Entire commands and options. See the
[Entire quickstart](https://docs.entire.com/quickstart).

Zsh adds `~/.aspnet/dev-certs/trust` to `SSL_CERT_DIR` for ASP.NET development
certificates. It preserves an existing value, uses `/usr/lib/ssl/certs` when
unset or empty, and avoids adding the trust directory again on reload.

Oh My Posh uses our local `wsl-dev` theme in `files/wsl-dev.omp.json`, based on
[marcduiker](https://ohmyposh.dev/docs/themes). It keeps the folder, Git, and exit
status segments and their colors, and adds a blank line between commands using
`newline: true`. The complete theme is stored in this repository; loading it
does not require downloading the upstream theme. Upstream attribution and license
are in `files/wsl-dev.omp.LICENSE`.

The [Docker segment](https://ohmyposh.dev/docs/segments/cli/docker) shows the active
Docker context with a Docker icon on a cyan background. It uses `context` mode.

The theme also includes an [Aspire segment](https://ohmyposh.dev/docs/segments/cli/aspire)
between Git and exit status. It shows the detected AppHost name on a purple
background and adds a checkmark when it is running. Running status uses the
Aspire CLI's `aspire ps --format json`; the CLI must be available on `PATH`.

Bootstrap installs the theme as a symlink at
`~/.config/wsl-dev-setup/wsl-dev.omp.json`, which `files/zshrc.sh` loads. Edit the
repository file to customize it, then run `exec zsh -l` to reload. On a distro
that already uses this setup, install just the new theme link with
`mise bootstrap --only dotfiles --yes`. New WSL setups get it automatically
when running `./bootstrap.sh`.
The `--strict` option keeps the prompt using the current executable on `PATH`
when mise upgrades Oh My Posh.

For icons, install a Nerd Font on **Windows**, where the WSL terminal is rendered.
Installing it only inside Ubuntu does not configure Windows Terminal or your
editor's terminal. Oh My Posh recommends Meslo. With the Windows version of
Oh My Posh installed, run this in **Windows PowerShell**:

```powershell
oh-my-posh font install meslo
```

Alternatively, install a Nerd Font manually. Then choose the installed font (for example,
`MesloLGM Nerd Font`) in Windows Terminal's Ubuntu profile under **Appearance →
Font face**, and in your editor's terminal font settings. Bootstrap prints a
reminder; it does not change Windows font or terminal settings. See the
[Oh My Posh font guide](https://ohmyposh.dev/docs/installation/fonts).

The package list includes `libicu78`, which .NET needs on Ubuntu 26.04. On another
Ubuntu release, change this declaration to that release's ICU runtime package
before applying the setup.

After applying the setup, mise's final bootstrap task asks for your Git name and email. Existing
global values appear as defaults; press Enter to keep them, or to skip a field
that is not configured yet. Answers are saved with `git config --global` in your
user configuration, outside this repository. They are not written to tracked
files or uploaded by the script. Git does include your name and email in future
commits, so use a GitHub noreply email if you want to keep your personal email
private.

Use `./bootstrap.sh --skip-git-config` to skip these questions. They are also
skipped when standard input is not an interactive terminal. `--yes` accepts mise's
installation prompts; it does not answer the Git identity questions. A dry run
does not ask questions or change your Git configuration. Shared Git defaults
are still applied when the identity questions are skipped.
When running mise directly, use `WSL_DEV_SETUP_SKIP_GIT_CONFIG=true mise bootstrap`
to skip the questions, or `mise bootstrap --skip task` to skip the whole final
task, including Docker group setup.

Package installation can ask for your sudo password. Keep this checkout in place:
your mise configuration and Bash settings link to it. If you already have a mise
configuration, merge or move it before running the script; the script refuses to
replace an unrelated configuration.

The preview does not install anything or create configuration links. If mise is
not installed yet, it prints the initial steps; the detailed mise preview becomes
available after installation. You can also review all declarations in `config.toml`.

Reopen Ubuntu after applying, or switch the current terminal to Zsh, then check:

```bash
exec zsh -l
```

```zsh
mise --version
mise doctor
mise bootstrap status
oh-my-posh version
```

Bootstrap sets the default login shell without replacing the shell that is
running the script. For an already configured distro that still starts Bash,
run `chsh -s "$(command -v zsh)"`, then reopen Ubuntu. If a terminal profile
explicitly launches `bash`, remove that override so it uses the distro's default
shell. Bash remains configured for mise too. This setup manages Zsh startup
files in your home directory; it assumes `ZDOTDIR` is unset or points to your
home directory.

## Make this your own

- Add Ubuntu packages under `[bootstrap.packages]` in `config.toml`.
- Add or change default development tools and versions under `[tools]`. Project
  `mise.toml` files can select different versions for each project.
- Add shared Bash configuration to `files/bashrc.sh`.
- Add shared Zsh configuration to `files/zshrc.sh`.
- Add shared Git settings to `files/gitconfig`; keep your identity in `~/.gitconfig`.
- Add directories under `[bootstrap.directories]`, and checkouts under `[bootstrap.repos]`.
- Add more managed files or edits under `[dotfiles]`.
- Keep distro-specific mise overrides in `config.local.toml`, which Git ignores.
  Keep credentials and private keys outside this repository.

The `.gitignore` also excludes common credential stores, SSH keys, certificate
bundles, and local authentication state. Use placeholders in examples; `.env.example`
is intentionally allowed.

Rerun `./bootstrap.sh` after changing declarations. Existing matching resources
are skipped. Removing a package declaration does not uninstall that package;
Ubuntu packages also depend on what the distro's repositories currently provide.
Use exact tool versions when you need to reproduce the same runtime versions.

The setup manages systemd enablement in `/etc/wsl.conf`; other WSL settings are
kept as configured.

Mise can also group optional features into `config.NAME.toml` modules beside
`config.toml`. Select them for one run with `mise -E NAME bootstrap`, or put
`env = ["NAME"]` in an ignored `miserc.local.toml` for that machine. Shared
defaults in `config.toml` always load. See [machine modules](https://mise.jdx.dev/bootstrap/modules.html).

This repository contains global mise configuration, so its native repository
workflow is `mise bootstrap --adopt maddindeiss/wsl-bootstrap`. `--from` is for a setup project
with a `mise.toml`. On a fresh WSL distro, use `./bootstrap.sh` to perform the
initial WSL checks and preserve the Zsh-first installation order. See
[bootstrap from a repository](https://mise.jdx.dev/bootstrap/from-repository.html).

## Use on another distro

Clone the public repository in the new distro:

```bash
sudo apt-get update
sudo apt-get install -y --no-install-recommends ca-certificates curl git
mkdir -p ~/projects/private
git clone https://github.com/maddindeiss/wsl-bootstrap.git ~/projects/private/wsl-bootstrap
cd ~/projects/private/wsl-bootstrap
./bootstrap.sh --dry-run
./bootstrap.sh
```

After pushing an update, apply it in each other distro:

```bash
cd ~/projects/private/wsl-bootstrap
git pull --ff-only
./bootstrap.sh
```

`./bootstrap.sh --update` refreshes package metadata and fast-forwards the managed
shell repositories. Changing `.mise-version`
selects a different mise release on the next run. Use `--yes` to accept mise's
installation prompts; sudo may still ask for a password.

## WSL settings

`/etc/wsl.conf` configures one distro. Windows' `%UserProfile%\.wslconfig` affects
all WSL 2 distros. Bootstrap merges `systemd=true` into the distro's `[boot]`
section and saves an existing file as `/etc/wsl.conf.pre-wsl-dev-setup` before
the first change. That backup is kept on later runs. Existing settings such as
`[user] default=...`, networking options, and boot commands are preserved.
Dry runs preview the change without writing the file. Bootstrap leaves the
Windows `.wslconfig` file as configured and never restarts WSL automatically.

## Chrome for agents and Playwright

Mise's `pre-packages` hook installs native Linux Google Chrome Stable inside Ubuntu from Google's
official `.deb`, including its system dependencies. The initial package sets up
Google's apt repository; `config.toml` declares the installed package for later
maintenance. This installer currently targets Ubuntu amd64. Existing Chrome
installations are skipped. To install only Chrome without applying the rest of
bootstrap, run:

```bash
bash scripts/install-chrome.sh --dry-run
bash scripts/install-chrome.sh
google-chrome --version
```

Run `google-chrome` for a window through WSLg. Agents can use the Linux binary at
`/usr/bin/google-chrome`, and Playwright can discover it through the `chrome`
channel. For a project that has `playwright` installed:

```js
import { chromium } from 'playwright';

const browser = await chromium.launch({ channel: 'chrome', headless: true });
const page = await browser.newPage();
await page.setContent('<title>WSL Chrome</title>');
console.log(await page.title());
await browser.close();
```

For Playwright Test, set `use: { channel: 'chrome' }` in the project's config.
Playwright itself stays a project dependency. See the
[Playwright browser guide](https://playwright.dev/docs/browsers#google-chrome--microsoft-edge).

## Linux GUI apps with WSLg

WSLg provides X11 and Wayland support for Linux GUI apps on Windows. Bootstrap
reports whether the current shell has display sockets available. WSL sets
`DISPLAY` and `WAYLAND_DISPLAY`; keep those supplied values in your shell.

For a simple GUI test, install the X11 example apps inside Ubuntu, then start one:

```bash
sudo apt-get update
sudo apt-get install -y x11-apps
xclock
```

Once installed, other Linux GUI apps can also be started by their executable
name. This setup does not install a full desktop environment.

If WSLg is missing on another machine, use Windows PowerShell to check and update
WSL with `wsl --version` and `wsl --update`. GUI apps require WSL 2. In Windows
WSL Settings, enable GUI application support, or merge the following into
`%UserProfile%\.wslconfig`, preserving other settings:

```ini
[wsl2]
guiApplications=true
```

If you changed Windows settings or updated WSL, save work in your WSL sessions,
run `wsl --shutdown` from Windows PowerShell, then reopen Ubuntu. This stops all
WSL distros. Bootstrap reports status and does not restart WSL or change the
Windows settings file. See [Microsoft's GUI app guide](https://learn.microsoft.com/en-us/windows/wsl/tutorials/gui-apps).

## License

This project is licensed under the [MIT License](LICENSE). The Oh My Posh theme
retains its [upstream copyright and license notice](files/wsl-dev.omp.LICENSE).

## Documentation

- [Mise bootstrap](https://mise.jdx.dev/bootstrap.html)
- [Mise repositories](https://mise.jdx.dev/bootstrap/repos.html)
- [Mise directories](https://mise.jdx.dev/bootstrap/files.html)
- [Mise login shell](https://mise.jdx.dev/bootstrap/shell.html)
- [Mise machine modules](https://mise.jdx.dev/bootstrap/modules.html)
- [Mise dotfiles](https://mise.jdx.dev/dotfiles.html)
- [Mise file edits](https://mise.jdx.dev/dotfiles/edits.html)
- [Mise Ubuntu packages](https://mise.jdx.dev/bootstrap/packages/apt.html)
- [Mise installation](https://mise.jdx.dev/installing-mise.html)
- [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh)
- [Zsh autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
- [Zsh syntax highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
- [Zsh completions](https://github.com/zsh-users/zsh-completions)
- [fzf](https://github.com/junegunn/fzf)
- [Oh My Posh on Linux](https://ohmyposh.dev/docs/installation/linux)
- [Oh My Posh fonts](https://ohmyposh.dev/docs/installation/fonts)
- [Oh My Posh shell initialization](https://ohmyposh.dev/docs/installation/prompt)
- [Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
- [Docker post-installation](https://docs.docker.com/engine/install/linux-postinstall/)
- [WSL configuration](https://learn.microsoft.com/en-us/windows/wsl/wsl-config)
- [Install Google Chrome](https://support.google.com/chrome/answer/95346)
