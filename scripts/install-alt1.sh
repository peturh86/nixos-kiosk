#!/usr/bin/env bash
set -euo pipefail

# Basic automated NixOS install: defines user, password, hostname and keymap
# Usage example:
#   HOSTNAME=myhost USERNAME=alice PASSWORD_HASH='$6$...' KEYMAP=us DISK=/dev/sda \
#   ./scripts/simple-install.sh

export NIX_CONFIG="experimental-features = nix-command flakes"

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DISK=${DISK:-/dev/sda}
HOSTNAME=${HOSTNAME:-kiosk}
USERNAME=${USERNAME:-kiosk}
KEYMAP=${KEYMAP:-us}
PASSWORD_HASH=${PASSWORD_HASH:-}
FLAKE_CONFIG=${FLAKE_CONFIG:-kiosk}

if [[ -z "$PASSWORD_HASH" ]]; then
  echo "PASSWORD_HASH environment variable must contain a SHA-512 password hash" >&2
  echo "Generate one with: mkpasswd -m sha-512" >&2
  exit 1
fi

# Ensure Nix is available (use official installer if missing)
if ! command -v nix >/dev/null 2>&1; then
  echo ">>> Installing Nix package manager"
  sh <(curl -L https://nixos.org/nix/install) --no-daemon
  # shellcheck disable=SC1091
  source "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

echo ">>> Partitioning and mounting $DISK"
export DISK
nix run --impure github:nix-community/disko -- --mode disko --flake "$repo_dir#$FLAKE_CONFIG"
nix run --impure github:nix-community/disko -- --mode mount --flake "$repo_dir#$FLAKE_CONFIG"

# Copy repository into target system for reproducible builds
mkdir -p /mnt/etc/nixos
cp -R "$repo_dir" /mnt/etc/nixos/kiosk

# Custom module for hostname, user and keymap
cat > /mnt/etc/nixos/kiosk/overrides.nix <<OVERRIDE
{ config, pkgs, ... }:
{
  networking.hostName = "$HOSTNAME";
  console.keyMap = "$KEYMAP";
  users.users.$USERNAME = {
    isNormalUser = true;
    hashedPassword = "$PASSWORD_HASH";
    extraGroups = [ "wheel" ];
  };
}
OVERRIDE

# Minimal flake that reuses kiosk configuration with overrides
cat > /mnt/etc/nixos/flake.nix <<FLAKE
{
  inputs.kiosk.url = "path:./kiosk";
  outputs = { kiosk, ... }: {
    nixosConfigurations.$HOSTNAME =
      kiosk.nixosConfigurations.$FLAKE_CONFIG.extendModules {
        modules = [ ./kiosk/overrides.nix ];
      };
  };
}
FLAKE

echo ">>> Installing NixOS"
nixos-install --impure --no-root-passwd --flake /mnt/etc/nixos#"$HOSTNAME"