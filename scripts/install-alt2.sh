#!/usr/bin/env bash
set -euo pipefail

# Minimal installer that predefines user, password, hostname and keyboard layout
# usage: optionally export USERNAME, PASSWORD, HOSTNAME, KEYMAP, FLAKE_CONFIG
# default FLAKE_CONFIG is "kiosk"

export NIX_CONFIG="experimental-features = nix-command flakes"

HOSTNAME=${HOSTNAME:-kiosk}
USERNAME=${USERNAME:-kiosk}
PASSWORD=${PASSWORD:-changeme}
KEYMAP=${KEYMAP:-us}
FLAKE_CONFIG=${FLAKE_CONFIG:-kiosk}

# Install nix if not present
if ! command -v nix >/dev/null 2>&1; then
  echo ">>> Installing Nix package manager"
  curl -L https://nixos.org/nix/install | sh
  # shellcheck disable=SC1091
  . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

# Hash the password (sha-512)
if command -v mkpasswd >/dev/null 2>&1; then
  HASH=$(mkpasswd -m sha-512 "$PASSWORD")
else
  HASH=$(nix shell nixpkgs#whois -c mkpasswd -m sha-512 "$PASSWORD")
fi

# Extra module for user/hostname/keymap
cat > /tmp/installer-extra.nix <<EXTRA
{ config, pkgs, ... }:
{
  networking.hostName = "${HOSTNAME}";
  console.keyMap = "${KEYMAP}";
  users.users.${USERNAME} = {
    isNormalUser = true;
    initialHashedPassword = "${HASH}";
    extraGroups = [ "wheel" "networkmanager" ];
  };
}
EXTRA

# Partition and mount disk using flake's Disko configuration
nix run github:nix-community/disko -- --mode disko --flake ".#${FLAKE_CONFIG}"
nix run github:nix-community/disko -- --mode mount --flake ".#${FLAKE_CONFIG}"

# Install NixOS applying the additional module
NIXOS_INSTALL_EXTRA_CONFIG=/tmp/installer-extra.nix \
  nixos-install --impure --no-root-passwd --flake ".#${FLAKE_CONFIG}"

echo ">>> Installation complete. Rebooting is recommended."