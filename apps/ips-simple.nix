# IPS Application - using installer from NAS
{ pkgs }:

let
  wineBase = import ./wine-base.nix { inherit pkgs; };
in
{
  ips = pkgs.writeShellScriptBin "ips" ''
    # IPS Application Launcher - Installer from NAS approach

    # Wine environment (32-bit required for MDAC28)
    export WINEPREFIX="$HOME/.wine-ips-${wineBase.wine_hash}"
    export WINEARCH=win32
    export WINEDLLOVERRIDES="mscoree,mshtml="

    # NAS configuration
    NAS_SHARE="/mnt/nas-share"
    IPS_INSTALLER="$NAS_SHARE/nixos/ipssetup.exe"

    # Check NAS accessibility
    if [ ! -d "$NAS_SHARE" ]; then
        echo "❌ NAS share not mounted at $NAS_SHARE"
        echo "Please ensure the NAS is accessible and mounted"
        exit 1
    fi

    if [ ! -f "$IPS_INSTALLER" ]; then
        echo "❌ IPS installer not found at $IPS_INSTALLER"
        echo "Please ensure ipssetup.zip is available on the NAS"
        exit 1
    fi

    # Setup Wine if needed
    if [ ! -d "$WINEPREFIX" ]; then
        echo "Setting up 32-bit Wine environment for IPS..."
        wineboot --init
        
        echo "Installing required components (Ubuntu-tested sequence):"
        echo "1. Core fonts..."
        ${pkgs.winetricks}/bin/winetricks -q corefonts
        
        echo "2. .NET Framework 4.8..."
        ${pkgs.winetricks}/bin/winetricks -q dotnet48
        
        echo "3. MDAC28 (database components)..."
        ${pkgs.winetricks}/bin/winetricks -q mdac28
        
        echo "Wine environment ready"
    fi

    # Check if IPS is installed (look for installed application)
    IPS_INSTALLED=$(find "$WINEPREFIX/drive_c" -name "IPS.exe" -type f 2>/dev/null | head -1)

    if [ -z "$IPS_INSTALLED" ]; then
        echo "IPS not found - extracting and running installer from NAS..."
        
        # Create temporary directory for extraction
        TEMP_DIR=$(mktemp -d)
        trap "rm -rf $TEMP_DIR" EXIT
        
        echo "Extracting installer from NAS: $IPS_INSTALLER"
        ${pkgs.unzip}/bin/unzip -q "$IPS_INSTALLER" -d "$TEMP_DIR" || {
            echo "Failed to extract ipssetup.zip from NAS"
            exit 1
        }
        
        # Find installer in extracted files
        INSTALLER=$(find "$TEMP_DIR" -name "*.exe" -o -name "setup.exe" -o -name "install.exe" | head -1)
        if [ -z "$INSTALLER" ]; then
            echo "Error: No installer (.exe) found in ipssetup.zip"
            echo "Available files:"
            find "$TEMP_DIR" -type f | head -10
            exit 1
        fi
        
        echo "Running IPS installer: $(basename $INSTALLER)"
        echo "Follow the installation prompts..."
        wine "$INSTALLER"
        
        # Check if installation succeeded
        IPS_INSTALLED=$(find "$WINEPREFIX/drive_c" -name "IPS.exe" -type f 2>/dev/null | head -1)
        if [ -z "$IPS_INSTALLED" ]; then
            echo "Installation may have failed - IPS.exe not found"
            echo "Please check the installation manually"
            exit 1
        fi
        
        echo "✓ IPS installation completed"
    fi

    # Run IPS from installed location
    echo "Starting IPS from: $IPS_INSTALLED"
    IPS_DIR=$(dirname "$IPS_INSTALLED")
    cd "$IPS_DIR"
    wine "$(basename "$IPS_INSTALLED")" "$@"
  '';
}
