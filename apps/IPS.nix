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

# Copy IPS files to Wine's C: drive if not already there
WINE_C_DRIVE="$WINEPREFIX/drive_c"
WINE_IPS_DIR="$WINE_C_DRIVE/IPS"

if [ ! -d "$WINE_IPS_DIR" ]; then
    echo "Copying IPS files to Wine C: drive..."
    mkdir -p "$WINE_IPS_DIR"
    cp -r "${placeholder "out"}/share/ips/"* "$WINE_IPS_DIR/"
    echo "IPS files copied to: $WINE_IPS_DIR"
else
    echo "IPS files already present in Wine C: drive"
fi

# Find and run IPS.exe from Wine's C: drive
IPS_EXE=""

echo "Looking for IPS executable in Wine C: drive: $WINE_IPS_DIR"

# Look for IPS.exe in the Wine directory
if [ -f "$WINE_IPS_DIR/IPS.exe" ]; then
    IPS_EXE="C:\\IPS\\IPS.exe"
    echo "Found: $WINE_IPS_DIR/IPS.exe (Wine path: $IPS_EXE)"
elif [ -f "$WINE_IPS_DIR/ips.exe" ]; then
    IPS_EXE="C:\\IPS\\ips.exe"
    echo "Found: $WINE_IPS_DIR/ips.exe (Wine path: $IPS_EXE)"
else
    # Search for any .exe file
    echo "Searching for any .exe files..."
    FOUND_EXE=$(find "$WINE_IPS_DIR" -name "*.exe" -type f | head -1)
    if [ -n "$FOUND_EXE" ]; then
        # Convert Unix path to Windows path for Wine
        REL_PATH=$(echo "$FOUND_EXE" | sed "s|$WINE_IPS_DIR/||")
        IPS_EXE="C:\\IPS\\$(echo "$REL_PATH" | sed 's|/|\\|g')"
        echo "Found executable: $FOUND_EXE (Wine path: $IPS_EXE)"
    fi
fi

if [ -n "$IPS_EXE" ]; then
    echo "Starting IPS using Wine path: $IPS_EXE"
    echo "Wine command: wine \"$IPS_EXE\""
    
    # Change to IPS directory in Wine before running
    cd "$WINE_IPS_DIR"
    
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
    echo "Available files in $WINE_IPS_DIR:"
    ls -la "$WINE_IPS_DIR" 2>/dev/null || echo "Directory not found"
    echo
    echo "Looking for .exe files:"
    find "$WINE_IPS_DIR" -name "*.exe" -type f 2>/dev/null || echo "No .exe files found"
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
echo "IPS files location (Nix store): ${placeholder "out"}/share/ips"
echo "Wine prefix: $HOME/.wine-ips"

if [ -d "$HOME/.wine-ips" ]; then
    echo "Wine C: drive: $HOME/.wine-ips/drive_c"
    echo "Wine IPS directory: $HOME/.wine-ips/drive_c/IPS"
    echo
    echo "Wine C: drive contents:"
    ls -la "$HOME/.wine-ips/drive_c/" 2>/dev/null || echo "No Wine C: drive found"
    echo
    echo "IPS files in Wine C: drive:"
    if [ -d "$HOME/.wine-ips/drive_c/IPS" ]; then
        ls -la "$HOME/.wine-ips/drive_c/IPS"
        echo
        echo "Executable files in Wine IPS directory:"
        find "$HOME/.wine-ips/drive_c/IPS" -name "*.exe" -type f 2>/dev/null || echo "No .exe files found in Wine directory"
    else
        echo "IPS directory not found in Wine C: drive"
        echo "Run 'ips' first to copy files to Wine"
    fi
else
    echo "Wine prefix not created yet (run 'ips' first)"
fi

echo
echo "Original IPS files (Nix store):"
ls -la "${placeholder "out"}/share/ips"
echo
echo "Executable files in Nix store:"
find "${placeholder "out"}/share/ips" -name "*.exe" -type f 2>/dev/null || echo "No .exe files found"
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
