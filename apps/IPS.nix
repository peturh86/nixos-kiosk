{ pkgs, lib, ... }:

let
  # Simple IPS package that extracts your local ZIP and sets up Wine launcher
  ipsPackage = pkgs.stdenv.mkDerivation {
    pname = "ips-client";
    version = "local";

    # Use your local IPS.zip file
    src = ../assets/apps/IPS.zip;

    nativeBuildInputs = with pkgs; [
      unzip
    ];

    # Don't try to unpack automatically since it's a zip
    unpackPhase = ''
      echo "Extracting IPS.zip..."
      unzip -q $src -d ./ips-extracted
      cd ips-extracted
      ls -la  # Show what's inside for debugging
    '';

    installPhase = ''
      echo "Installing IPS files..."
      
      # Create installation directory
      mkdir -p $out/share/ips
      
      # Copy all extracted files
      cp -r * $out/share/ips/
      
      # Create the main launcher script
      mkdir -p $out/bin
      cat > $out/bin/ips <<'EOF'
#!/bin/sh

# IPS Launcher Script
export WINEPREFIX="$HOME/.wine-ips"
export WINEARCH=win32

# Create Wine prefix if it doesn't exist
if [ ! -d "$WINEPREFIX" ]; then
    echo "Setting up IPS Wine environment..."
    echo "This may take a moment on first run..."
    
    # Initialize Wine prefix
    wineboot --init
    
    # Install common Windows components that might be needed
    echo "Installing Windows components..."
    winetricks -q corefonts vcrun2019 2>/dev/null || echo "Some components failed to install (this is often normal)"
fi

# Find and run IPS.exe
IPS_PATH="${placeholder "out"}/share/ips"
IPS_EXE=""

# Look for IPS.exe in the extracted files
if [ -f "$IPS_PATH/IPS.exe" ]; then
    IPS_EXE="$IPS_PATH/IPS.exe"
elif [ -f "$IPS_PATH/ips.exe" ]; then
    IPS_EXE="$IPS_PATH/ips.exe"
else
    # Search for any .exe file
    IPS_EXE=$(find "$IPS_PATH" -name "*.exe" -type f | head -1)
fi

if [ -n "$IPS_EXE" ] && [ -f "$IPS_EXE" ]; then
    echo "Starting IPS from: $IPS_EXE"
    exec wine "$IPS_EXE" "$@"
else
    echo "Error: Could not find IPS.exe"
    echo "Available files in $IPS_PATH:"
    ls -la "$IPS_PATH" 2>/dev/null || echo "Directory not found"
    echo
    echo "Looking for .exe files:"
    find "$IPS_PATH" -name "*.exe" -type f 2>/dev/null || echo "No .exe files found"
    exit 1
fi
EOF
      
      chmod +x $out/bin/ips
      
      # Create a debug script to explore the installation
      cat > $out/bin/ips-debug <<'EOF'
#!/bin/sh
echo "=== IPS Debug Information ==="
echo "IPS files location: ${placeholder "out"}/share/ips"
echo "Wine prefix: $HOME/.wine-ips"
echo
echo "Contents of IPS directory:"
ls -la "${placeholder "out"}/share/ips"
echo
echo "Executable files found:"
find "${placeholder "out"}/share/ips" -name "*.exe" -type f 2>/dev/null || echo "No .exe files found"
echo
echo "Wine prefix status:"
if [ -d "$HOME/.wine-ips" ]; then
    echo "Wine prefix exists"
else
    echo "Wine prefix not created yet (run 'ips' first)"
fi
EOF
      chmod +x $out/bin/ips-debug
      
      # Create uninstaller
      cat > $out/bin/ips-uninstall <<'EOF'
#!/bin/sh
echo "Removing IPS Wine environment..."
rm -rf "$HOME/.wine-ips"
echo "IPS Wine environment removed"
echo "Note: IPS files remain in the Nix store"
EOF
      chmod +x $out/bin/ips-uninstall
    '';

    meta = with lib; {
      description = "IPS Client Application (Local Installation)";
      platforms = platforms.linux;
    };
  };

in
{
  environment.systemPackages = [
    ipsPackage
    pkgs.wineWowPackages.stable
    pkgs.winetricks
  ];
}
