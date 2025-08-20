# IPS Application - using installer approach like Ubuntu success
{ pkgs }:

let
  wineBase = import ./wine-base.nix { inherit pkgs; };
in
{
  ips = pkgs.stdenv.mkDerivation {
    pname = "ips-wine-app";
    version = "1.0";
    
    src = ./assets/apps/IPS.zip;
    
    nativeBuildInputs = [ pkgs.unzip ];
    
    buildPhase = ''
      echo "Extracting IPS installer..."
      # Just extract - no Wine operations during build
    '';
    
    installPhase = ''
      mkdir -p $out/share/ips-installer
      unzip -q $src -d $out/share/ips-installer/ || {
        echo "Failed to extract IPS.zip"
        exit 1
      }
      
      # Find the installer executable
      INSTALLER=$(find $out/share/ips-installer -name "*.exe" -o -name "setup.exe" -o -name "install.exe" | head -1)
      if [ -z "$INSTALLER" ]; then
        echo "Warning: No installer found, looking for any .exe files:"
        find $out/share/ips-installer -name "*.exe" -type f | head -5
      fi
      
      # Create launcher that uses installer approach
      mkdir -p $out/bin
      cat > $out/bin/ips <<'EOF'
#!/bin/sh
# IPS Application Launcher - Installer-based approach

# Wine environment (32-bit required for MDAC28)
export WINEPREFIX="$HOME/.wine-ips-${wineBase.wine_hash}"
export WINEARCH=win32
export WINEDLLOVERRIDES="mscoree,mshtml="

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
    echo "IPS not found - running installer..."
    
    # Find installer in extracted files
    INSTALLER=$(find ${placeholder "out"}/share/ips-installer -name "*.exe" | head -1)
    if [ -z "$INSTALLER" ]; then
        echo "Error: No installer found in IPS.zip"
        exit 1
    fi
    
    echo "Running IPS installer: $INSTALLER"
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
EOF
      chmod +x $out/bin/ips
    '';
  };
}
