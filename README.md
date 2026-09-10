# orca-nix

Always up-to-date Nix package for [Orca](https://github.com/stablyai/orca), the ADE for working with a fleet of parallel agents.

This flake packages Orca's official Linux AppImage release and exposes two commands:

- `orca-ide`: desktop app launcher
- `orca`: headless and automation CLI

## Quick Start

Launch the desktop app:

```bash
nix run github:kevinpita/orca-nix
```

Run the CLI:

```bash
nix run github:kevinpita/orca-nix#orca -- --help
nix run github:kevinpita/orca-nix#orca -- serve
```

## Install

```bash
nix profile install github:kevinpita/orca-nix
orca --help
orca-ide
```

For the CLI without the GUI launcher:

```bash
nix profile install github:kevinpita/orca-nix#orca-cli
```

## Binary Cache

Prebuilt `x86_64-linux` outputs are served from a [Cachix](https://www.cachix.org/) cache, so installing can pull the binary instead of rebuilding the AppImage wrapper locally. The flake advertises the cache via `nixConfig`. The first `nix run` or `nix profile install` will ask to trust it. To opt in permanently:

```bash
cachix use kevinpita
```

## Use In A Flake

Add `github:kevinpita/orca-nix` as an input. Use the modules below, or add `orca-nix.packages.${system}.default` to your package list.

The `default` and `orca` outputs include both commands. `orca-cli` includes only the CLI launcher and its headless requirements. All outputs use the same AppImage. The CLI still needs Electron libraries.

## NixOS

Add the input to your flake:

```nix
inputs.orca-nix.url = "github:kevinpita/orca-nix";
```

Import the module in a NixOS configuration. For a workstation:

```nix
{ inputs, ... }:
{
  imports = [ inputs.orca-nix.nixosModules.default ];
  programs.orca-ide.enable = true;
}
```

This installs the GUI and CLI. It does not start a server or change your desktop session. The GUI supports Wayland.

For a headless server, use the service instead:

```nix
{ config, inputs, pkgs, ... }:
{
  imports = [ inputs.orca-nix.nixosModules.default ];

  services.orca-ide = {
    enable = true;
    user = "alice";
    pairingAddress = "my-server.example.ts.net";
    extraPackages = [ pkgs.git pkgs.nodejs ];
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    config.services.orca-ide.port
  ];
}
```

Replace `alice` with an existing account that has a writable home. Install and authenticate your agent tools for that account. The example assumes Tailscale is already connected and tailnet policy permits the connection.

Without `user`, the module creates an unprivileged `orca-ide` account with its home at `/var/lib/orca-ide`. Run account-management commands as the service account, not as root. For that default account, use:

```bash
sudo -u orca-ide -H /run/current-system/sw/bin/orca account add --agent codex
```

The service starts at boot. It installs the CLI automatically; no `programs.orca-ide.enable` setting is required. Xvfb provides its virtual X11 display. This does not enable an Xorg desktop or change a Wayland session.

For the CLI without an automatic service:

```nix
programs.orca-ide = {
  enable = true;
  gui = false;
};
```

## Home Manager

Import `homeModules.default` in your Home Manager configuration:

```nix
{ inputs, ... }:
{
  imports = [ inputs.orca-nix.homeModules.default ];
  programs.orca-ide.enable = true;
}
```

For a user service, replace the program setting with:

```nix
services.orca-ide = {
  enable = true;
  pairingAddress = "my-server.example.ts.net";
};
```

The service uses the Home Manager account and its XDG directories. It has no `user` option. Home Manager does not configure the system firewall. On NixOS, enable lingering if the user service must start before login and continue after logout:

```nix
users.users.alice.linger = true;
```

On another Linux distribution, an administrator can use `loginctl enable-linger alice`. Do not enable the NixOS service and Home Manager service for the same account and profile.

## Module options

| Option | Default | Effect |
| --- | --- | --- |
| `programs.orca-ide.enable` | `false` | Install Orca |
| `programs.orca-ide.gui` | `true` | Include the GUI launcher |
| `programs.orca-ide.package` | Selected by `gui` | Override the installed package |
| `services.orca-ide.enable` | `false` | Install the CLI and start the headless service |
| `services.orca-ide.package` | `orca-cli` | Override the headless-ready service package |
| `services.orca-ide.port` | `6768` | Set the TCP port |
| `services.orca-ide.pairingAddress` | `null` | Set the address advertised to clients; otherwise Orca selects it |
| `services.orca-ide.extraPackages` | `[]` | Add tools to the service's `PATH` |
| `services.orca-ide.user` | `"orca-ide"` | Select the service account; NixOS only |

The modules do not change `services.orca` or `pkgs.orca`, which belong to the GNOME screen reader. The existing `overlays.default` does replace `pkgs.orca`; the modules do not need that overlay. Do not install both applications in the same profile: both provide an `orca` command.

## Connect and operate

After applying the NixOS configuration, check the service and get its private pairing link:

```bash
systemctl status orca-ide
sudo journalctl -u orca-ide -b -o cat \
  | jq -Rr 'fromjson? | select(.type == "orca_server_ready" and .schemaVersion == 1 and .pairing.available) | .pairing.url' \
  | tail -n 1
```

For Home Manager, use `systemctl --user status orca-ide` and replace the journal command with `journalctl --user -u orca-ide -b -o cat`.

On the client, open **Settings → Remote Orca Servers → Add Server** and paste the pairing link. Keep the link private. Repositories, credentials, and sessions stay on the server. Client logins do not transfer.

**The server listens on all addresses.** `pairingAddress` changes only the advertised address. The modules do not open firewall ports. Use Tailscale, WireGuard, or another private network, and permit the port only on the required interface. Do not expose it directly to the public internet.

**Restarting the service stops active terminals and agents.** Complete their work before a reboot, package update, or configuration change that restarts the service. Orca keeps its writable state in the service account's home; the modules do not write account credentials or pairing keys into the Nix store. Back up that state before an upgrade. Do not start the GUI or another `orca serve` process against the same profile while the service is running.

See the upstream [remote server guide](https://www.onorca.dev/docs/remote-servers) for pairing and access revocation.

## Development

```bash
nix fmt -- .
nix flake check --all-systems --no-build
nix flake check
nix build .#orca
./result/bin/orca --help
./result/bin/orca-ide
```

Supported Nix systems: `x86_64-linux` and `aarch64-linux`.

## Updates

The update workflow checks upstream releases hourly and can also be run manually from GitHub Actions. When a new release exists, it updates `package.nix`, refreshes AppImage hashes from upstream release metadata, updates `flake.lock`, creates a pull request, and enables auto-merge.

Manual update:

```bash
./scripts/update.sh --check
./scripts/update.sh --version 1.4.119
```
