# Dotfiles

My personal environment, managed with **Nix flakes** and **Home Manager**.

User-space only — no NixOS. Every host is a regular Linux or macOS machine with
Nix installed on top, so the same repository works on WSL, on a headless server,
on a Linux desktop and on a Mac.

## Quick start

```bash
# 1. Install Nix (any installer with flakes enabled)
sh <(curl -L https://nixos.org/nix/install) --daemon

# 2. Clone and pick a host
git clone https://github.com/ruizsamuel/dotfiles ~/dotfiles && cd ~/dotfiles
nix run home-manager/master -- switch --flake .#samuel@wsl
```

Forking this for yourself means editing exactly one file, [`identity.nix`](identity.nix):
username, git name and email, and the GPG key used for signing. Nothing in it is
secret — an email is already public in every commit you push, and a GPG key ID
identifies a *public* key. It has to stay in git because Nix reads it during
evaluation, so gitignoring it is not an option.

## Hosts

| Host | System | What it is |
|---|---|---|
| `wsl` | `x86_64-linux` | WSL2 on Windows. Main development machine |
| `server` | `x86_64-linux` | Headless. Always-on Orca runtime |
| `desktop` | `x86_64-linux` | Native Linux desktop |
| `mac` | `aarch64-darwin` | macOS on Apple Silicon |

Each host is a file in [`hosts/`](hosts) that imports the modules it needs.
Adding a machine is one line in `flake.nix` plus that file — including the same
host on a different architecture:

```nix
hosts = {
  wsl = "x86_64-linux";
  server-arm = "aarch64-linux";   # hosts/server-arm.nix: imports = [ ./server.nix ];
};
```

## Modules

| Module | Contents | Hosts |
|---|---|---|
| `base` | Identity, state version, store GC and dedup | all |
| `shell` | Zsh, Starship | all |
| `tmux` | Tmux | all |
| `git` | Git, GitHub CLI, GPG signing | all |
| `neovim` | Neovim, config from its own repo | all |
| `dev` | Node, Python, JDK, toolchains, LSPs, Docker | all |
| `agents` | Claude Code and personal skills | all |
| `android` | SDK, NDK, emulator | wsl, desktop |
| `orca` | Orca package, headless server, pairing helper | wsl, server |

Only `orca` exposes options, for the port and the advertised pairing address.

The Mac deliberately gets neither `android` nor `orca`: both have a macOS-native
counterpart that owns its own state — Android Studio manages its SDK under
`~/Library/Android/sdk`, and Orca ships a Homebrew cask. A second, Nix-managed
copy would only fight them.

## Orca headless server

The `orca-serve` user service runs `orca serve`, so an Orca client — desktop or
mobile — can attach to the machine. See the
[remote servers documentation](https://www.onorca.dev/docs/remote-servers).

```bash
orca-pairing                            # print the pairing URL
systemctl --user status orca-serve      # is it up?
journalctl --user -t orca-serve -e      # full server log
```

Paste the `orca://pair?code=…` URL into the client under
**Settings → Remote Orca Servers → Add Server**.

`orca-pairing` is the only command needed when the machine's address changes: it
compares what the running service advertises against what the configuration
expects and restarts it to regenerate the URL if they differ. Nothing in the Nix
configuration changes.

Some hard-won details:

- The server always binds `0.0.0.0` — there is no bind flag. `local.orca.pairingAddress`
  only changes what clients are told. Left unset it advertises the machine's LAN
  address, detected at service start; an address containing `://` is embedded in
  the pairing code verbatim, with no port appended, which is what the `server`
  host uses to advertise its public subdomain behind nginx. `localhost` does
  **not** work: the client reads a loopback endpoint as its own runtime and
  refuses to pair.
- The runtime is an Electron process and will not start without an X server,
  so the service wraps it in `xvfb-run` — an in-memory display, not a GUI. Under
  WSL specifically, WSLg's own display (`DISPLAY=:0`) makes it die with `SIGTRAP`.
- On WSL the address survives reboots only if the NAT subnet is pinned in
  `.wslconfig` on the Windows side, otherwise WSL regenerates it on every boot
  and you have to pair again:

  ```ini
  [wsl2]
  networkingMode=nat
  natNetwork=192.168.128.0/20
  ```

- Never expose the Orca port to the public internet.

### Updating Orca

Orca is not in nixpkgs (`pkgs.orca` is the GNOME screen reader), so
`pkgs/orca.nix` pins a release by version and one hash per architecture. That
puts it outside `flake.lock`, which means `nix flake update` cannot see it, and
the app's own auto-updater cannot work either — the Nix store is read-only.

```bash
nix run .#update-orca          # from the repository root
nix fmt && git commit -am "chore: update Orca to <version>"
```

The script reads the latest release from the GitHub API, hashes both AppImages
and rewrites the version and both hashes in place. It stops early if the pin is
already current, and leaves the commit to you.

Making the AppImages flake inputs would let `nix flake update` handle them, but
flake inputs are fetched whenever the flake is evaluated — every host would pull
two 200 MB files, including the Mac, which has no Orca module, and CI, whose
entire point is to evaluate cheaply.

Update the desktop client to the same version. The runtime negotiates a protocol
version with a `status.get` preflight (`RemoteRuntimeCompatGate`), and the client
updates itself while the server does not, so they drift apart on their own.

### On a headless server

Two things a desktop or WSL machine already has, and a bare server does not.

**System libraries.** The package deliberately avoids `buildFHSEnv` (see
`pkgs/orca.nix` for why), so the Electron binary resolves its libraries against
the host. Install the GTK stack and let apt pull the rest:

```bash
sudo apt-get install -y \
  libgtk-3-0t64 libnss3 libasound2t64 libatk-bridge2.0-0t64 libcups2t64 \
  libgbm1 libdrm2 libxkbcommon0 \
  libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libxinerama1 libxcursor1 libxi6
```

Drop the `t64` suffixes on distributions predating the 64-bit `time_t`
transition. To check what is still missing:
`ldd <store-path>/orca-ide | grep "not found"`.

**Unprivileged user namespaces.** Chromium's SUID sandbox helper must be
root-owned and mode 4755, which the read-only Nix store cannot provide, so it
falls back to the namespace sandbox. Servers that disable unprivileged user
namespaces make Electron abort instead of running unsandboxed. The service
probes for them at start and passes `--no-sandbox` only when they are missing,
so nothing needs configuring — but enabling them keeps the sandbox:

```bash
sudo sysctl -w kernel.unprivileged_userns_clone=1        # Debian
sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0   # Ubuntu 24.04+
```

**Lingering** is required, unlike on a desktop: `orca-serve` is a *user*
service, so without `sudo loginctl enable-linger <user>` it dies when the SSH
session ends and never starts at boot.

## Agent skills

Two sets of skills share `~/.claude/skills`, managed by different things.

**Personal skills** live in [`skills/`](skills) and are symlinked from the Nix
store by `modules/agents.nix`. Dropping a new directory in there is enough — the
module reads the directory, there is no list to update. These are versioned,
roll back with the generation, and every host gets them.

**Orca's own skills** are installed by the app's CLI into `~/.agents/skills`,
which is then symlinked into `~/.claude/skills`. Linking specific paths lets both
sets coexist without clobbering each other.

| Host | Personal skills | Orca's skills |
|---|---|---|
| `wsl` | switch | manual, CLI available |
| `server` | switch | manual, CLI available |
| `desktop` | switch | manual, **no CLI** — the host does not import `modules/orca.nix` |
| `mac` | switch | manual, **no CLI** — install the Homebrew cask, which ships one |

`home-manager switch` never installs Orca's skills, on any host. Run this once
per machine, and again when you want to pick up upstream changes:

```bash
orca skills install --all
orca skills update
```

### Superpowers

[Superpowers](https://github.com/obra/superpowers) ships as a plugin for several
agents, but upstream is a plain git repo of skill directories, so `flake.lock`
pins it exactly and `nix flake update superpowers` bumps it. Both agents get it
from the same pinned store path, by different routes.

**Claude Code** takes the 14 skills as symlinks under `~/.claude/skills`,
alongside the personal ones. Its SessionStart hook cannot be reproduced: a hook
has to live in `~/.claude/settings.json`, which Orca rewrites to wire its own
eleven hooks and which Claude Code rewrites whenever you touch `/config`. Nix
cannot own a contested file. Instead `modules/agents.nix` writes the content the
hook would have injected — `skills/using-superpowers/SKILL.md`, in the same
`<EXTREMELY_IMPORTANT>` framing — to `~/.claude/CLAUDE.md`, which nothing else
owns.

That reimplementation also sidesteps a trap. The hook script branches on
`CLAUDE_PLUGIN_ROOT`; unset, it emits a field its own comments say Claude Code
does not read. Run from a store path rather than as a plugin, it would have
failed silently.

**Copilot CLI** gets the real thing. `copilot --plugin-dir <directory>` loads a
plugin from a local path, so `modules/agents.nix` wraps the binary to always
pass the pinned store path:

```nix
wrapProgram $out/bin/copilot --add-flags "--plugin-dir ${inputs.superpowers}"
```

Skills and the upstream hook both arrive natively — verified against a live
session: Copilot invoked `skill(using-superpowers)`, and its startup context
contained the hook's `You have superpowers`. Because the hook fires on its own,
writing the same text to `~/.copilot/copilot-instructions.md` would only put it
in context twice, so that file is deliberately absent.

For the record, user-level Copilot instructions live in
`~/.copilot/copilot-instructions.md`, not `AGENTS.md` — that one is
repository-level. `COPILOT_HOME` relocates the directory.

Note that `github-copilot-cli` is the standalone agentic CLI and provides a
`copilot` binary. It is not a `gh` extension, which is why declaring it under
`programs.gh.extensions` left `gh extension list` empty.

Turning Superpowers off is a per-host decision, not a per-session one: the
bootstrap applies to every session on the machine. The skills themselves stay
usable either way — dropping the `CLAUDE.md` entry removes the pressure to
always reach for them, not the skills.

### Why this one step is manual

It would be easy to bolt onto activation:

```nix
home.activation.orcaSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  [ -d "$HOME/.agents/skills" ] || $DRY_RUN_CMD orca skills install --all || true
'';
```

The guard keeps it off the network on every switch and the `|| true` keeps it
from breaking activation, so the obvious objections do not apply. It is still
the wrong thing, for three reasons.

**It is not reproducible.** `orca skills install` resolves to
`npx skills add https://github.com/stablyai/orca --skill …`, which fetches
whatever is on the default branch right now. No version, no hash. The same Nix
generation applied on two machines on different days would install different
skills — the exact impurity that pinning Orca by hash and locking the flake
exists to prevent.

**It creates state Nix cannot undo.** A generation is meant to describe the
whole state. Skills written by an external installer are invisible to Nix:
`--rollback` restores the personal skills, because they are store symlinks, and
leaves Orca's untouched. Configuration and disk drift apart permanently, and the
garbage collector never reclaims any of it.

**The guard lies.** `[ -d ~/.agents/skills ]` proves a directory exists, not that
the right skills are present at the right version. Delete one and it still
passes. It only behaves on a machine's first switch — which is precisely the
case a line of documentation already covers.

The coherent alternative is not activation but vendoring: pin Orca's skills into
this repo the way the personal ones are, and let Nix own them properly. That
buys reproducibility and rollback at the cost of maintaining the pin and
drifting from whatever the app ships. For skills that belong to the app and
change with it, that trade is not worth it.

## Development

```bash
nix fmt              # format (nixfmt via treefmt)
nix fmt -- --ci      # check formatting without writing
nix develop          # shell with the formatter and home-manager

nix eval --raw '.#homeConfigurations."samuel@mac".activationPackage.drvPath'

nix run .#update-orca   # bump the pinned Orca release
```

That last command is the useful one: it evaluates a host without building it,
which catches unportable packages and renamed options in seconds. CI runs it for
every host on each push — Linux hosts on `ubuntu-latest`, the macOS host on
`macos-14`, since a Linux runner cannot evaluate a Darwin configuration.

## Disk

Two systemd user timers on Linux hosts, both in `modules/base.nix`:

- `nix-gc` drops profile generations older than 14 days, then collects what is
  no longer reachable.
- `nix-optimise` hard-links identical files across store paths. This one earns
  its keep whenever nixpkgs moves: the Android system images get rebuilt under
  new hashes while their contents are the same upstream archive, so a single
  bump can otherwise cost ~10 GB in duplicates. It deletes nothing, so it costs
  no rollback.

Home Manager exposes `nix.gc` but not `nix.optimise`, hence the hand-written
unit for the second one.
