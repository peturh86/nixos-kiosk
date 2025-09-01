#!/usr/bin/env bash
set -euo pipefail

# Environment: you can export DISK/HOSTNAME/ROOT_HASH/USER_HASH to override defaults

# Ensure flakes work in the ISO shell
export NIX_CONFIG="experimental-features = nix-command flakes"

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

# Ensure assets dir exists and contains derive-hostname script used at first boot
mkdir -p "$repo_dir/assets"
cat > "$repo_dir/assets/derive-hostname.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Try to get motherboard serial
serial=""
if [[ -r /sys/class/dmi/id/board_serial ]]; then
  serial=$(cat /sys/class/dmi/id/board_serial | tr -d '[:space:]')
elif [[ -r /sys/class/dmi/id/product_serial ]]; then
  serial=$(cat /sys/class/dmi/id/product_serial | tr -d '[:space:]')
fi

if [[ -z "$serial" ]]; then
  echo "fband"
  exit 0
fi

# Check for JSON mapping file
map_file="/etc/nixos/assets/serial-hostname-map.json"
if [[ -f "$map_file" ]] && command -v jq >/dev/null 2>&1; then
  mapped=$(jq -r --arg s "$serial" '.[$s] // empty' "$map_file")
  if [[ -n "$mapped" ]]; then
    echo "$mapped"
    exit 0
  fi
fi

# Fallback: generate hostname from last 4 chars of serial
suffix="${serial: -4}"
echo "wh-${suffix}"
EOF
chmod +x "$repo_dir/assets/derive-hostname.sh" || true

# Interactive disk chooser (very early): if DISK is not set, show available
# block devices and prompt the user to pick one by number or enter a /dev path.
if [[ -z "${DISK:-}" ]]; then
  echo "Available block devices:";
  declare -a _dev_names=()
  i=0
  while read -r name type size ro rm; do
    _dev_names[$i]="$name"
    printf "[%2d] /dev/%-8s  type=%-4s  size=%8s  removable=%s\n" "$i" "$name" "$type" "$size" "$rm"
    i=$((i+1))
  done < <(lsblk -dn -o NAME,TYPE,SIZE,RO,RM 2>/dev/null || true)

  if [[ ${#_dev_names[@]} -eq 0 ]]; then
    echo "No block devices found to list.";
  else
    echo
    read -rp "Select target disk (number) or enter full /dev path (or leave empty to auto-detect): " sel
    if [[ -n "$sel" ]]; then
      if [[ "$sel" =~ ^/dev/ ]]; then
        DISK="$sel"
      elif [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >=0 && sel < ${#_dev_names[@]} )); then
        DISK="/dev/${_dev_names[$sel]}"
      else
        echo "Invalid selection: '$sel'"; exit 1
      fi

      # Confirm selection
      read -rp "You selected $DISK — continue? [y/N]: " confirm
      if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Aborted by user."; exit 1
      fi
    fi
  fi
fi

# ---- pick disk (largest, writable, non-loop/non-cdrom) unless DISK is provided
if [[ -z "${DISK:-}" ]]; then
  # Safer disk detection:
  # - use lsblk to list disks with SIZE in bytes (-b)
  # - exclude removable devices (USB installers), loop, ram, sr, md, dm devices
  # - pick the largest remaining disk
  disks_list=()
  while IFS=" " read -r name ro type size; do
    # only consider disk types
    if [[ "$type" != "disk" ]]; then
      continue
    fi
    # skip read-only devices
    if [[ "$ro" -ne 0 ]]; then
      continue
    fi
    # skip known virtual/loop/ram devices
    case "$name" in
      loop*|ram*|sr*|md*|dm-*) continue ;;
    esac
    # skip removable devices (like the installer USB)
    removable_file="/sys/block/$name/removable"
    if [[ -f "$removable_file" ]]; then
      if [[ "$(cat "$removable_file")" -eq 1 ]]; then
        continue
      fi
    fi
    # size should be bytes when using -b; if empty, skip
    if [[ -z "$size" || "$size" == "-" ]]; then
      continue
    fi
    disks_list+=("$name:$size")
  done < <(lsblk -dn -o NAME,RO,TYPE,SIZE -b 2>/dev/null || lsblk -dn -o NAME,RO,TYPE,SIZE 2>/dev/null)

  if [[ ${#disks_list[@]} -gt 0 ]]; then
    biggest=$(printf "%s\n" "${disks_list[@]}" | sort -t: -k2 -n | tail -1 | cut -d: -f1)
    DISK="/dev/${biggest}"
  else
    # fallback: ask user to set DISK explicitly
    DISK=""
  fi
fi
if [[ -z "${DISK:-}" ]]; then
  echo "Could not detect a target disk automatically. Set DISK=/dev/XXX and retry."; exit 1
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

export DISK HOSTNAME

FLAKE_CONFIG="kiosk"
echo ">>> Using flake configuration: $FLAKE_CONFIG (DISK=${DISK})"

# Wipe/partition/format (from disko), then mount
nix run --impure github:nix-community/disko -- --mode disko --flake .#$FLAKE_CONFIG
nix run --impure github:nix-community/disko -- --mode mount --flake .#$FLAKE_CONFIG

# Copy assets to the installed system
if [[ -d "$repo_dir/assets" ]]; then
  echo ">>> Copying assets to installed system..."
  mkdir -p /mnt/etc/nixos/assets
  cp -r "$repo_dir/assets/"* /mnt/etc/nixos/assets/ 2>/dev/null || true
fi

# Generate hardware-configuration.nix (uses blkid/UUIDs) and ensure root is
# referenced by UUID in the generated file to avoid by-partlabel mismatches.
echo ">>> Generating NixOS hardware configuration (nixos-generate-config)..."
if command -v nixos-generate-config >/dev/null 2>&1; then
  nixos-generate-config --root /mnt || true

  HW_FILE="/mnt/etc/nixos/hardware-configuration.nix"
  if [[ -f "$HW_FILE" ]]; then
    # Check if fileSystems."/".device is using an explicit UUID
    if ! grep -q 'fileSystems."/".device = "UUID=' "$HW_FILE"; then
      echo ">>> Ensuring root device is referenced by UUID in $HW_FILE"
      # Find the root device mounted on /mnt
      ROOT_DEV=$(findmnt -n -o SOURCE --target /mnt || true)
      if [[ -n "$ROOT_DEV" ]]; then
        ROOT_UUID=$(blkid -s UUID -o value "$ROOT_DEV" || true)
        if [[ -n "$ROOT_UUID" ]]; then
          # Replace or add the fileSystems."/".device line
          if grep -q 'fileSystems."/".device' "$HW_FILE"; then
            sed -i -E "s|fileSystems\.\"/\"\.device = \"[^"]*\";|fileSystems.\"/\".device = \"UUID=${ROOT_UUID}\";|" "$HW_FILE"
          else
            # Inject a minimal fileSystems entry near the top of the file
            sed -i '1s;^;{ /* hardware config added by installer */ }\n;' "$HW_FILE"
          fi
        else
          echo "Warning: could not determine UUID for $ROOT_DEV"
        fi
      else
        echo "Warning: could not find root device mounted at /mnt"
      fi
    fi
  else
    echo "Warning: $HW_FILE not generated"
  fi
else
  echo "nixos-generate-config not available in this environment; skipping hardware config generation"
fi

# Install (no root password unless ROOT_HASH is exported)
nixos-install --impure --no-root-passwd --flake .#$FLAKE_CONFIG

# Reboot into the installed system
reboot
