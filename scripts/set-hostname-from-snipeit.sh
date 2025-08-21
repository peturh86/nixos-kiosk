#!/bin/bash
# Hostname management script for kiosk deployment
# This script fetches hostname from Snipe-IT based on hardware serial number
# and updates the NixOS system configuration

set -euo pipefail

# Configuration
SNIPEIT_URL="${SNIPEIT_URL:-https://snipeit.example/api/v1}"
SNIPEIT_TOKEN="${SNIPEIT_TOKEN:-YOURTOKEN}"
CONFIG_FILE="${CONFIG_FILE:-/etc/nixos/configurations/system.nix}"
BACKUP_DIR="${BACKUP_DIR:-/etc/nixos/backups}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get hardware serial number
get_serial() {
    local serial=""
    
    # Try DMI product serial
    if [[ -r /sys/class/dmi/id/product_serial ]]; then
        serial=$(cat /sys/class/dmi/id/product_serial 2>/dev/null | tr -d '[:space:]')
    fi
    
    # Fallback to board serial
    if [[ -z "$serial" || "$serial" == "Not Specified" ]] && [[ -r /sys/class/dmi/id/board_serial ]]; then
        serial=$(cat /sys/class/dmi/id/board_serial 2>/dev/null | tr -d '[:space:]')
    fi
    
    # Fallback to MAC-based identifier
    if [[ -z "$serial" || "$serial" == "Not Specified" ]]; then
        local mac=$(ip link show | grep -o 'link/ether [^[:space:]]*' | head -1 | cut -d' ' -f2 | tr -d ':' | tr '[:lower:]' '[:upper:]')
        if [[ -n "$mac" ]]; then
            serial="MAC-${mac: -6}"
            warn "Using MAC-based serial: $serial"
        fi
    fi
    
    echo "$serial"
}

# Fetch hostname from Snipe-IT
fetch_hostname() {
    local serial="$1"
    local hostname=""
    
    log "Fetching hostname for serial: $serial"
    
    # Make API request
    local response=$(curl -s \
        -H "Authorization: Bearer $SNIPEIT_TOKEN" \
        -H "Accept: application/json" \
        "$SNIPEIT_URL/hardware/byserial/$serial" \
        2>/dev/null || echo '{}')
    
    # Parse response
    if command -v jq >/dev/null 2>&1; then
        hostname=$(echo "$response" | jq -r '.name // empty' 2>/dev/null)
    else
        # Fallback parsing without jq
        hostname=$(echo "$response" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")
    fi
    
    echo "$hostname"
}

# Update NixOS configuration
update_config() {
    local new_hostname="$1"
    local current_hostname=$(hostname)
    
    if [[ -z "$new_hostname" ]]; then
        error "No hostname provided"
        return 1
    fi
    
    if [[ "$new_hostname" == "$current_hostname" ]]; then
        log "Hostname already set to: $new_hostname"
        return 0
    fi
    
    log "Updating hostname from '$current_hostname' to '$new_hostname'"
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Backup current config
    local backup_file="$BACKUP_DIR/system.nix.$(date +%Y%m%d_%H%M%S)"
    cp "$CONFIG_FILE" "$backup_file"
    log "Backed up config to: $backup_file"
    
    # Update the configuration file
    sed -i.tmp "s/networking\.hostName = \"[^\"]*\";/networking.hostName = \"$new_hostname\";/g" "$CONFIG_FILE"
    
    # Verify the change
    if grep -q "networking.hostName = \"$new_hostname\";" "$CONFIG_FILE"; then
        log "Successfully updated configuration file"
        rm -f "$CONFIG_FILE.tmp"
        
        # Apply the configuration
        log "Rebuilding system configuration..."
        if nixos-rebuild switch; then
            log "System rebuilt successfully"
            log "New hostname: $(hostname)"
        else
            error "Failed to rebuild system"
            # Restore backup
            cp "$backup_file" "$CONFIG_FILE"
            warn "Restored backup configuration"
            return 1
        fi
    else
        error "Failed to update configuration file"
        rm -f "$CONFIG_FILE.tmp"
        return 1
    fi
}

# Main function
main() {
    log "Starting hostname update process..."
    
    # Check dependencies
    if ! command -v curl >/dev/null 2>&1; then
        error "curl is required but not installed"
        exit 1
    fi
    
    # Get serial number
    local serial=$(get_serial)
    if [[ -z "$serial" ]]; then
        error "Could not determine hardware serial number"
        exit 1
    fi
    
    log "Hardware serial: $serial"
    
    # Fetch hostname from Snipe-IT
    local hostname=$(fetch_hostname "$serial")
    if [[ -z "$hostname" || "$hostname" == "null" ]]; then
        warn "No hostname found in Snipe-IT for serial: $serial"
        log "Keeping current hostname: $(hostname)"
        exit 0
    fi
    
    log "Found hostname in Snipe-IT: $hostname"
    
    # Update configuration
    update_config "$hostname"
    
    log "Hostname update process completed"
}

# Script usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Update NixOS hostname based on Snipe-IT asset management system.

OPTIONS:
    -h, --help              Show this help message
    -s, --serial SERIAL     Use specific serial number instead of auto-detection
    -n, --hostname NAME     Set specific hostname (bypass Snipe-IT lookup)
    -c, --config FILE       Specify config file path (default: $CONFIG_FILE)
    --dry-run               Show what would be done without making changes

ENVIRONMENT VARIABLES:
    SNIPEIT_URL            Snipe-IT API base URL
    SNIPEIT_TOKEN          Snipe-IT API token
    CONFIG_FILE            NixOS config file path
    BACKUP_DIR             Backup directory path

EXAMPLES:
    $0                     # Auto-detect serial and update hostname
    $0 -s ABC123          # Use specific serial number
    $0 -n workstation-01  # Set specific hostname
    $0 --dry-run          # Preview changes

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -s|--serial)
            MANUAL_SERIAL="$2"
            shift 2
            ;;
        -n|--hostname)
            MANUAL_HOSTNAME="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Handle manual hostname setting
if [[ -n "${MANUAL_HOSTNAME:-}" ]]; then
    log "Manual hostname specified: $MANUAL_HOSTNAME"
    if [[ -n "${DRY_RUN:-}" ]]; then
        log "DRY RUN: Would update hostname to: $MANUAL_HOSTNAME"
    else
        update_config "$MANUAL_HOSTNAME"
    fi
    exit 0
fi

# Handle dry run mode
if [[ -n "${DRY_RUN:-}" ]]; then
    log "DRY RUN MODE - No changes will be made"
    local serial="${MANUAL_SERIAL:-$(get_serial)}"
    log "Would use serial: $serial"
    local hostname=$(fetch_hostname "$serial")
    log "Would set hostname to: ${hostname:-"<no change>"}"
    exit 0
fi

# Run main function
main "$@"
