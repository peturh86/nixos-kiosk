#!/usr/bin/env bash
set -euo pipefail

# Safety: require AUTO=1 to proceed (you can also export DISK/HOSTNAME/ROOT_HASH/USER_HASH)
: "${AUTO:=0}"

# Ensure flakes work in the ISO shell
export NIX_CONFIG="experimental-features = nix-command flakes"

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

# ---- pick disk (largest, writable, non-loop/non-cdrom) unless DISK is provided
if [[ -z "${DISK:-}" ]]; then
  DISK="$(lsblk -dnbo NAME,RO,TYPE,BYTES | awk '$2==0 && $3=="disk"{print "/dev/"$1,$4}' | sort -nk2 | tail -1 | cut -d' ' -f1)"
fi
if [[ -z "${DISK:-}" ]]; then
  echo "Could not detect a target disk. Set DISK=/dev/XXX and retry."; exit 1
fi

# ---- derive hostname if not provided: use serial-hostname map
if [[ -z "${HOSTNAME:-}" ]]; then
  serial=""
  if [[ -r /sys/class/dmi/id/board_serial ]]; then
    serial=$(cat /sys/class/dmi/id/board_serial | tr -d '[:space:]')
  elif [[ -r /sys/class/dmi/id/product_serial ]]; then
    serial=$(cat /sys/class/dmi/id/product_serial | tr -d '[:space:]')
  fi
  if [[ -z "$serial" ]]; then
    echo "No motherboard serial found to derive hostname."; exit 1
  fi
  # Try to map serial to hostname using JSON
  MAP_FILE="$repo_dir/assets/serial-hostname-map.json"
  if [[ -f "$MAP_FILE" ]] && command -v jq >/dev/null 2>&1; then
    mapped=$(jq -r --arg s "$serial" '.[$s] // empty' "$MAP_FILE")
    if [[ -n "$mapped" ]]; then
      HOSTNAME="$mapped"
    else
      suffix="${serial: -4}"
      HOSTNAME="wh-${suffix}"
    fi
  else
    suffix="${serial: -4}"
    HOSTNAME="wh-${suffix}"
  fi
fi

echo ">>> Installing kiosk to ${DISK} with hostname ${HOSTNAME}"
if [[ "$AUTO" != "1" ]]; then
  echo "Set AUTO=1 to proceed non-interactively."; exit 1
fi

export DISK HOSTNAME

# Wipe/partition/format (from disko), then mount
nix run --impure github:nix-community/disko -- --mode disko --flake .#kiosk
nix run --impure github:nix-community/disko -- --mode mount --flake .#kiosk

# Copy assets to the installed system
if [[ -d "$repo_dir/assets" ]]; then
  echo ">>> Copying assets to installed system..."
  mkdir -p /mnt/etc/nixos/assets
  cp -r "$repo_dir/assets/"* /mnt/etc/nixos/assets/ 2>/dev/null || true
fi

# Install (no root password unless ROOT_HASH is exported)
nixos-install --impure --no-root-passwd --flake .#kiosk

# Reboot into the installed system
reboot
