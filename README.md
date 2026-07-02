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

## Binary Cache

Prebuilt `x86_64-linux` outputs are served from a [Cachix](https://www.cachix.org/) cache, so installing can pull the binary instead of rebuilding the AppImage wrapper locally. The flake advertises the cache via `nixConfig`. The first `nix run` or `nix profile install` will ask to trust it. To opt in permanently:

```bash
cachix use kevinpita
```

## Use In A Flake

Add `github:kevinpita/orca-nix` as an input, then use `orca-nix.packages.${system}.default` wherever you build your package list.

## Development

```bash
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
