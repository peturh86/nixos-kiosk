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

# IPS Launcher Script with declarative Wine setup
# Use a hash-based Wine prefix to ensure fresh setup when IPS.zip changes
IPS_HASH=$(echo "${placeholder "out"}" | sha256sum | cut -d' ' -f1 | head -c16)
export WINEPREFIX="$HOME/.wine-ips-$IPS_HASH"
export WINEARCH=win32

echo "=== IPS Launcher Debug ==="
echo "IPS package hash: $IPS_HASH"
echo "Wine prefix: $WINEPREFIX"
echo "Current user: $(whoami)"
echo "Display: $DISPLAY"

# Clean up old Wine prefixes to save space (keep only current one)
echo "Cleaning up old IPS Wine prefixes..."
find "$HOME" -maxdepth 1 -name ".wine-ips-*" -type d | while read old_prefix; do
    if [ "$old_prefix" != "$WINEPREFIX" ]; then
        echo "Removing old Wine prefix: $old_prefix"
        rm -rf "$old_prefix"
    fi
done

# Create Wine prefix if it doesn't exist
if [ ! -d "$WINEPREFIX" ]; then
    echo "Setting up fresh IPS Wine environment..."
    echo "This may take a moment on first run..."
    
    # Initialize Wine prefix
    echo "Initializing Wine..."
    wineboot --init
    
    # Install common Windows components that might be needed
    echo "Installing Windows components..."
    winetricks -q corefonts vcrun2019 2>/dev/null || echo "Some components failed to install (this is often normal)"
    
    # Copy IPS files to Wine's C: drive
    WINE_C_DRIVE="$WINEPREFIX/drive_c"
    WINE_IPS_DIR="$WINE_C_DRIVE/IPS"
    
    echo "Copying IPS files to Wine C: drive..."
    mkdir -p "$WINE_IPS_DIR"
    cp -r "${placeholder "out"}/share/ips/"* "$WINE_IPS_DIR/"
    echo "IPS files copied to: $WINE_IPS_DIR"
    
    # Create a marker file with the package info
    echo "IPS Package: ${placeholder "out"}" > "$WINE_IPS_DIR/.nix-package-info"
    echo "Created: $(date)" >> "$WINE_IPS_DIR/.nix-package-info"
else
    echo "Using existing Wine environment (same IPS version)"
fi

# Wine paths
WINE_C_DRIVE="$WINEPREFIX/drive_c"
WINE_IPS_DIR="$WINE_C_DRIVE/IPS"

# Find and run IPS.exe from Wine's C: drive
IPS_EXE=""

echo "Looking for IPS executable in Wine C: drive: $WINE_IPS_DIR"

# Look specifically for IPS.exe first (case variations)
if [ -f "$WINE_IPS_DIR/IPS.exe" ]; then
    IPS_EXE="C:\\IPS\\Bin\\IPS.exe"
    echo "Found: $WINE_IPS_DIR/IPS.exe (Wine path: $IPS_EXE)"
elif [ -f "$WINE_IPS_DIR/ips.exe" ]; then
    IPS_EXE="C:\\IPS\\Bin\\ips.exe"
    echo "Found: $WINE_IPS_DIR/ips.exe (Wine path: $IPS_EXE)"
elif [ -f "$WINE_IPS_DIR/Ips.exe" ]; then
    IPS_EXE="C:\\IPS\\Bin\\Ips.exe"
    echo "Found: $WINE_IPS_DIR/Ips.exe (Wine path: $IPS_EXE)"
else
    echo "Error: IPS.exe not found in $WINE_IPS_DIR"
    echo "Available .exe files:"
    find "$WINE_IPS_DIR" -name "*.exe" -type f 2>/dev/null | while read exe_file; do
        echo "  $(basename "$exe_file")"
    done
    echo
    echo "Please ensure IPS.exe is in the ZIP file, or update the script to use the correct executable name"
    exit 1
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
    echo "Error: Could not find or run IPS.exe"
    echo "Make sure IPS.exe exists in the ZIP file"
    exit 1
fi
EOF
      
      chmod +x $out/bin/ips
      
      # Create a process checker script
      cat > $out/bin/ips-status <<'EOF'
#!/bin/sh
echo "=== IPS Status Check ==="

# Calculate the same hash as the launcher
IPS_HASH=$(echo "${placeholder "out"}" | sha256sum | cut -d' ' -f1 | head -c16)
CURRENT_WINEPREFIX="$HOME/.wine-ips-$IPS_HASH"

echo "Current IPS hash: $IPS_HASH"
echo "Current Wine prefix: $CURRENT_WINEPREFIX"
echo

echo "Wine processes:"
ps aux | grep wine | grep -v grep || echo "No Wine processes running"
echo
echo "IPS-related processes:"
ps aux | grep -i ips | grep -v grep || echo "No IPS processes found"
echo

echo "Wine prefix status:"
if [ -d "$CURRENT_WINEPREFIX" ]; then
    echo "Current Wine prefix exists at: $CURRENT_WINEPREFIX"
    echo "Size: $(du -sh "$CURRENT_WINEPREFIX" 2>/dev/null | cut -f1)"
    
    if [ -f "$CURRENT_WINEPREFIX/drive_c/IPS/.nix-package-info" ]; then
        echo "Package info:"
        cat "$CURRENT_WINEPREFIX/drive_c/IPS/.nix-package-info"
    fi
else
    echo "Current Wine prefix not found (run 'ips' first)"
fi

echo
echo "All IPS Wine prefixes:"
ls -ld "$HOME"/.wine-ips-* 2>/dev/null || echo "No Wine prefixes found"

echo
echo "To kill all Wine processes: killall wine wineserver"
echo "To force fresh setup: rm -rf $CURRENT_WINEPREFIX"
EOF
      chmod +x $out/bin/ips-status
      
      # Create a debug script to explore the installation
      cat > $out/bin/ips-debug <<'EOF'
#!/bin/sh
echo "=== IPS Debug Information ==="

# Calculate the same hash as the launcher
IPS_HASH=$(echo "${placeholder "out"}" | sha256sum | cut -d' ' -f1 | head -c16)
CURRENT_WINEPREFIX="$HOME/.wine-ips-$IPS_HASH"

echo "IPS package hash: $IPS_HASH"
echo "IPS files location (Nix store): ${placeholder "out"}/share/ips"
echo "Current Wine prefix: $CURRENT_WINEPREFIX"

if [ -d "$CURRENT_WINEPREFIX" ]; then
    echo "Wine C: drive: $CURRENT_WINEPREFIX/drive_c"
    echo "Wine IPS directory: $CURRENT_WINEPREFIX/drive_c/IPS"
    echo
    echo "Wine C: drive contents:"
    ls -la "$CURRENT_WINEPREFIX/drive_c/" 2>/dev/null || echo "No Wine C: drive found"
    echo
    echo "IPS files in Wine C: drive:"
    if [ -d "$CURRENT_WINEPREFIX/drive_c/IPS" ]; then
        ls -la "$CURRENT_WINEPREFIX/drive_c/IPS"
        echo
        echo "Package info:"
        cat "$CURRENT_WINEPREFIX/drive_c/IPS/.nix-package-info" 2>/dev/null || echo "No package info found"
        echo
        echo "Executable files in Wine IPS directory:"
        find "$CURRENT_WINEPREFIX/drive_c/IPS" -name "*.exe" -type f 2>/dev/null || echo "No .exe files found in Wine directory"
    else
        echo "IPS directory not found in Wine C: drive"
        echo "Run 'ips' first to copy files to Wine"
    fi
else
    echo "Current Wine prefix not created yet (run 'ips' first)"
fi

echo
echo "All IPS Wine prefixes:"
ls -ld "$HOME"/.wine-ips-* 2>/dev/null || echo "No Wine prefixes found"

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
echo "Removing all IPS Wine environments..."

# Remove all IPS Wine prefixes
REMOVED=0
for prefix in "$HOME"/.wine-ips-*; do
    if [ -d "$prefix" ]; then
        echo "Removing: $prefix"
        rm -rf "$prefix"
        REMOVED=$((REMOVED + 1))
    fi
done

if [ $REMOVED -eq 0 ]; then
    echo "No IPS Wine environments found"
else
    echo "Removed $REMOVED IPS Wine environment(s)"
fi

echo "Note: IPS files remain in the Nix store"
echo "To get a fresh setup, just run 'ips' again"
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
