#!/usr/bin/env bash
set -euo pipefail

# Simple NixOS installation script with predefined values.
# Assumes target root filesystem is mounted at /mnt and partitioning is already done.

HOSTNAME="kiosk"
USERNAME="kiosk"
# shellcheck disable=SC2016
PASSWORD_HASH='$6$QkKVlPsuOhQcLups$GxAMDqfeZ4oRXBEa4JXJFhvmUpz1PuRGj.JvdcGQPQK0uOb1D.VM32hpHQtUsOI6fmYhIoc/NsBB0CnOFjfxK.'
KEYBOARD_LAYOUT="us"

# Set keyboard layout for installer environment
loadkeys "$KEYBOARD_LAYOUT"

# Generate hardware configuration
nixos-generate-config --root /mnt

# Write configuration.nix with predefined options
cat > /mnt/etc/nixos/configuration.nix <<CONFIG
{ config, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "${HOSTNAME}";

  console.keyMap = "${KEYBOARD_LAYOUT}";
  services.xserver.xkb.layout = "${KEYBOARD_LAYOUT}";

  users.users.${USERNAME} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    initialHashedPassword = "${PASSWORD_HASH}";
  };

  users.users.root.initialHashedPassword = "${PASSWORD_HASH}";
}
CONFIG

# Install NixOS without prompting for root password
nixos-install --no-root-password