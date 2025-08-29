#!/usr/bin/env bash
# Hostname mapping management script
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MAP_FILE="$REPO_DIR/assets/serial-hostname-map.json"

# Ensure jq is available
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required for hostname mapping management."
    echo "Install with: nix-env -i jq"
    exit 1
fi

# Create map file if it doesn't exist
if [[ ! -f "$MAP_FILE" ]]; then
    echo "{}" > "$MAP_FILE"
    echo "Created new hostname mapping file: $MAP_FILE"
fi

show_usage() {
    cat << EOF
Hostname Mapping Management Tool

Usage: $0 <command> [arguments]

Commands:
  list                    Show all current mappings
  add <serial> <hostname> Add or update a serial-to-hostname mapping
  remove <serial>         Remove a mapping for the given serial
  get <serial>            Get the hostname for a specific serial
  test <serial>           Test hostname derivation for a serial
  help                    Show this help message

Examples:
  $0 list
  $0 add ABC123 kiosk-01
  $0 remove ABC123
  $0 get ABC123
  $0 test ABC123

The mapping file is located at: $MAP_FILE
EOF
}

list_mappings() {
    echo "Current hostname mappings:"
    echo "Serial Number -> Hostname"
    echo "------------------------"
    jq -r 'to_entries[] | "\(.key) -> \(.value)"' "$MAP_FILE" | sort
}

add_mapping() {
    local serial="$1"
    local hostname="$2"

    if [[ -z "$serial" || -z "$hostname" ]]; then
        echo "Error: Both serial number and hostname are required."
        echo "Usage: $0 add <serial> <hostname>"
        exit 1
    fi

    # Validate hostname format (basic check)
    if [[ ! "$hostname" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$ ]]; then
        echo "Warning: Hostname '$hostname' may not be valid."
        echo "Valid characters: letters, numbers, hyphens (cannot start/end with hyphen)"
    fi

    # Add/update the mapping
    jq --arg serial "$serial" --arg hostname "$hostname" \
       '. + {($serial): $hostname}' "$MAP_FILE" > "${MAP_FILE}.tmp"
    mv "${MAP_FILE}.tmp" "$MAP_FILE"

    echo "Added mapping: $serial -> $hostname"
}

remove_mapping() {
    local serial="$1"

    if [[ -z "$serial" ]]; then
        echo "Error: Serial number is required."
        echo "Usage: $0 remove <serial>"
        exit 1
    fi

    if jq -e --arg serial "$serial" 'has($serial)' "$MAP_FILE" >/dev/null 2>&1; then
        jq --arg serial "$serial" 'del(.[$serial])' "$MAP_FILE" > "${MAP_FILE}.tmp"
        mv "${MAP_FILE}.tmp" "$MAP_FILE"
        echo "Removed mapping for serial: $serial"
    else
        echo "No mapping found for serial: $serial"
    fi
}

get_hostname() {
    local serial="$1"

    if [[ -z "$serial" ]]; then
        echo "Error: Serial number is required."
        echo "Usage: $0 get <serial>"
        exit 1
    fi

    local hostname
    hostname=$(jq -r --arg serial "$serial" '.[$serial] // empty' "$MAP_FILE")

    if [[ -n "$hostname" ]]; then
        echo "$hostname"
    else
        echo "No mapping found for serial: $serial"
        echo "Would derive hostname: wh-${serial: -4}"
    fi
}

test_derivation() {
    local serial="$1"

    if [[ -z "$serial" ]]; then
        echo "Error: Serial number is required."
        echo "Usage: $0 test <serial>"
        exit 1
    fi

    echo "Testing hostname derivation for serial: $serial"
    echo

    # Check if mapping exists
    local mapped_hostname
    mapped_hostname=$(jq -r --arg serial "$serial" '.[$serial] // empty' "$MAP_FILE")

    if [[ -n "$mapped_hostname" ]]; then
        echo "✅ Found mapping: $serial -> $mapped_hostname"
        echo "   Final hostname: $mapped_hostname"
    else
        echo "❌ No mapping found for: $serial"
        local fallback_hostname="wh-${serial: -4}"
        echo "   Fallback hostname: $fallback_hostname"
        echo
        echo "To add a mapping, run:"
        echo "  $0 add $serial <desired-hostname>"
    fi
}

# Main command handling
case "${1:-help}" in
    list)
        list_mappings
        ;;
    add)
        add_mapping "${2:-}" "${3:-}"
        ;;
    remove)
        remove_mapping "${2:-}"
        ;;
    get)
        get_hostname "${2:-}"
        ;;
    test)
        test_derivation "${2:-}"
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        echo "Unknown command: $1"
        echo
        show_usage
        exit 1
        ;;
esac
