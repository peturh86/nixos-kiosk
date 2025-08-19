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

# IPS Launcher Script with enhanced debugging
export WINEPREFIX="$HOME/.wine-ips"
export WINEARCH=win32

echo "=== IPS Launcher Debug ==="
echo "Wine prefix: $WINEPREFIX"
echo "Current user: $(whoami)"
echo "Display: $DISPLAY"

# Create Wine prefix if it doesn't exist
if [ ! -d "$WINEPREFIX" ]; then
    echo "Setting up IPS Wine environment..."
    echo "This may take a moment on first run..."
    
    # Initialize Wine prefix
    echo "Initializing Wine..."
    wineboot --init
    
    # Install common Windows components that might be needed
    echo "Installing Windows components..."
    winetricks -q corefonts vcrun2019 2>/dev/null || echo "Some components failed to install (this is often normal)"
fi

# Find and run IPS.exe
IPS_PATH="${placeholder "out"}/share/ips"
IPS_EXE=""

echo "Looking for IPS executable in: $IPS_PATH"

# Look for IPS.exe in the extracted files
if [ -f "$IPS_PATH/IPS.exe" ]; then
    IPS_EXE="$IPS_PATH/IPS.exe"
    echo "Found: $IPS_EXE"
elif [ -f "$IPS_PATH/ips.exe" ]; then
    IPS_EXE="$IPS_PATH/ips.exe"
    echo "Found: $IPS_EXE"
else
    # Search for any .exe file
    echo "Searching for any .exe files..."
    IPS_EXE=$(find "$IPS_PATH" -name "*.exe" -type f | head -1)
    if [ -n "$IPS_EXE" ]; then
        echo "Found executable: $IPS_EXE"
    fi
fi

if [ -n "$IPS_EXE" ] && [ -f "$IPS_EXE" ]; then
    echo "Starting IPS from: $IPS_EXE"
    echo "Wine command: wine \"$IPS_EXE\""
    
    # Run with more verbose output and timeout
    timeout 30 wine "$IPS_EXE" "$@" 2>&1 | while IFS= read -r line; do
        echo "[Wine] $line"
    done
    
    EXIT_CODE=$?
    echo "Wine exit code: $EXIT_CODE"
    
    if [ $EXIT_CODE -eq 124 ]; then
        echo "Warning: Wine process timed out after 30 seconds"
        echo "This might mean IPS is running in background or hung"
        echo "Check with: ps aux | grep wine"
    fi
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
      
      # Create a process checker script
      cat > $out/bin/ips-status <<'EOF'
#!/bin/sh
echo "=== IPS Status Check ==="
echo "Wine processes:"
ps aux | grep wine | grep -v grep || echo "No Wine processes running"
echo
echo "IPS-related processes:"
ps aux | grep -i ips | grep -v grep || echo "No IPS processes found"
echo
echo "Wine prefix status:"
if [ -d "$HOME/.wine-ips" ]; then
    echo "Wine prefix exists at: $HOME/.wine-ips"
    echo "Size: $(du -sh "$HOME/.wine-ips" 2>/dev/null | cut -f1)"
else
    echo "Wine prefix not found"
fi
echo
echo "To kill all Wine processes: killall wine wineserver"
EOF
      chmod +x $out/bin/ips-status
      
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
