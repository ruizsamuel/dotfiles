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

## Agent skills

Personal skills live in [`skills/`](skills) and are symlinked into
`~/.claude/skills`. Dropping a new directory in there is enough — the module
reads the directory, there is no list to update.

Orca's own skills are deliberately **not** versioned here. They belong to the
app and are updated with it:

```bash
orca skills install --all   # on a fresh machine
orca skills update
```

They land in `~/.agents/skills` and are symlinked into `~/.claude/skills`, so
both sets coexist without clobbering each other.

## Development

```bash
nix fmt              # format (nixfmt via treefmt)
nix fmt -- --ci      # check formatting without writing
nix develop          # shell with the formatter and home-manager

nix eval --raw '.#homeConfigurations."samuel@mac".activationPackage.drvPath'
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
