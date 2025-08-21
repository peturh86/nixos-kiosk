# IPS Application - using installer from NAS
{ pkgs }:

let
  wineBase = import ./wine-base.nix { inherit pkgs; };
in
{
  ips = pkgs.writeShellScriptBin "ips" ''
    # IPS Application Launcher - Direct installer from NAS

    # Add Wine to PATH
    export PATH="${pkgs.wineWowPackages.stable}/bin:${pkgs.winetricks}/bin:$PATH"
    
    # Wine environment (32-bit required for MDAC28)
    export WINEPREFIX="$HOME/.wine-ips-${wineBase.wine_hash}"
    export WINEARCH=win32
    # Temporarily remove DLL overrides that might interfere with IPS
    # export WINEDLLOVERRIDES="mscoree,mshtml="

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
        echo "Available files in NAS nixos folder:"
        ls -la "$NAS_SHARE/nixos/" 2>/dev/null || echo "Cannot list NAS contents"
        exit 1
    fi

    # Setup Wine if needed
    if [ ! -d "$WINEPREFIX" ]; then
        echo "Setting up 32-bit Wine environment for IPS..."
        wineboot --init
        
        echo "Installing required components (Ubuntu-tested sequence):"
        echo "1. Core fonts..."
        winetricks -q corefonts
        
        echo "2. .NET Framework 4.8..."
        winetricks -q dotnet48
        
        echo "3. MDAC28 (database components)..."
        winetricks -q mdac28
        
        echo "Wine environment ready"
    fi

    # Check if IPS is installed (look for installed application)
    IPS_INSTALLED=$(find "$WINEPREFIX/drive_c" -name "IPS.exe" -type f 2>/dev/null | head -1)

    if [ -z "$IPS_INSTALLED" ]; then
        echo "IPS not found - running installer directly from NAS..."
        
        echo "Running IPS installer: $IPS_INSTALLER"
        echo "Follow the installation prompts..."
        wine "$IPS_INSTALLER"
        
        # Check if installation succeeded
        IPS_INSTALLED=$(find "$WINEPREFIX/drive_c" -name "IPS.exe" -type f 2>/dev/null | head -1)
        if [ -z "$IPS_INSTALLED" ]; then
            echo "Installation may have failed - IPS.exe not found"
            echo "Please check the installation manually"
            echo "Looking for any .exe files that might be IPS:"
            find "$WINEPREFIX/drive_c" -name "*.exe" -type f | grep -i ips || echo "No IPS-related executables found"
            exit 1
        fi
        
        echo "✓ IPS installation completed"
    fi

    # Debug information before running IPS
    echo "=== IPS Debug Information ==="
    echo "IPS executable found at: $IPS_INSTALLED"
    echo "Linux path: $IPS_INSTALLED"
    echo "Wine prefix: $WINEPREFIX"
    
    # Convert to Windows path for Wine
    IPS_WINE_PATH=$(echo "$IPS_INSTALLED" | sed "s|$WINEPREFIX/drive_c|C:|" | sed 's|/|\\|g')
    echo "Wine path: $IPS_WINE_PATH"
    
    # Check DLL dependencies
    IPS_DIR=$(dirname "$IPS_INSTALLED")
    echo "IPS directory: $IPS_DIR"
    echo "DLL files in IPS directory:"
    find "$IPS_DIR" -name "*.dll" | head -10
    
    # Check Wine DLL overrides
    echo "Wine DLL overrides: ${WINEDLLOVERRIDES:-none}"
    
    # Test Wine environment
    echo "Testing Wine..."
    if ! wine --version; then
        echo "❌ Wine is not working properly"
        exit 1
    fi
    
    # Check if we can access the IPS directory from Wine
    echo "Testing Wine access to IPS directory..."
    wine cmd /c "dir $(echo "$IPS_WINE_PATH" | sed 's|\\[^\\]*$||')" || echo "Failed to access IPS directory via Wine"
    
    echo "=== Running IPS with debugging ==="
    cd "$IPS_DIR"
    
    # Don't suppress debug output initially - let's see what's happening
    export WINEDEBUG=+dll,+module
    echo "Running: wine \"$IPS_WINE_PATH\""
    wine "$IPS_WINE_PATH" "$@"
  '';
}
