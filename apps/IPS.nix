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
      
      # Check if there's an IPS subdirectory in the extracted files
      if [ -d "IPS" ]; then
        echo "Found IPS subdirectory, copying contents..."
        cp -r IPS/* $out/share/ips/
      else
        echo "No IPS subdirectory found, copying all files..."
        cp -r * $out/share/ips/
      fi
      
      echo "Final IPS directory structure:"
      find $out/share/ips -type f -name "*.exe" | head -5
      echo "All files in IPS directory:"
      ls -la $out/share/ips/
      
      # Create the main launcher script
      mkdir -p $out/bin
      cat > $out/bin/ips <<'EOF'
#!/bin/sh

# IPS Launcher Script with declarative Wine setup
# Use a hash-based Wine prefix to ensure fresh setup when IPS.zip changes
IPS_HASH=$(echo "${placeholder "out"}" | sha256sum | cut -d' ' -f1 | head -c16)
export WINEPREFIX="$HOME/.wine-ips-$IPS_HASH"
export WINEARCH=win32

# Set Wine environment variables for better database compatibility
export WINEDLLOVERRIDES="odbc32,odbccp32=n,b"

echo "=== IPS Launcher Debug ==="
echo "IPS package hash: $IPS_HASH"
echo "Wine prefix: $WINEPREFIX"
echo "Wine DLL overrides: $WINEDLLOVERRIDES"
echo "Current user: $(whoami)"
echo "Display: $DISPLAY"

# Clean up old Wine prefixes to save space (keep only current one)
echo "Cleaning up old IPS Wine prefixes..."
find "$HOME" -maxdepth 1 -name ".wine-ips-*" -type d | while read old_prefix; do
    if [ "$old_prefix" != "$WINEPREFIX" ]; then
        echo "Removing old Wine prefix: $old_prefix"
        
        # Kill any Wine processes that might be using the old prefix
        if [ -d "$old_prefix" ]; then
            echo "Stopping Wine processes for old prefix..."
            WINEPREFIX="$old_prefix" wineserver -k 2>/dev/null || true
            sleep 1
        fi
        
        # Try to remove with force and without error on failure
        if rm -rf "$old_prefix" 2>/dev/null; then
            echo "Successfully removed: $old_prefix"
        else
            echo "Warning: Could not remove $old_prefix (may be in use)"
            echo "You can manually remove it later with: rm -rf '$old_prefix'"
        fi
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
    
    # Install basic components
    winetricks -q corefonts vcrun2019 2>/dev/null || echo "Some basic components failed to install (this is often normal)"
    
    # Install ODBC components for database connectivity
    echo "Installing ODBC components for database connectivity..."
    winetricks -q odbc32 2>/dev/null || echo "ODBC32 installation attempted"
    winetricks -q mdac28 2>/dev/null || echo "MDAC 2.8 installation attempted"
    winetricks -q jet40 2>/dev/null || echo "Jet 4.0 installation attempted"
    
    # Install additional .NET and database components that IPS might need
    echo "Installing additional runtime components..."
    winetricks -q dotnet48 2>/dev/null || echo ".NET 4.8 installation attempted"
    winetricks -q vcrun2015 2>/dev/null || echo "VC++ 2015 installation attempted"
    winetricks -q vcrun2019 2>/dev/null || echo "VC++ 2019 installation attempted"
    
    # Install additional .NET components
    echo "Installing .NET Framework components..."
    winetricks -q dotnet35 2>/dev/null || echo ".NET 3.5 installation attempted"
    winetricks -q dotnet40 2>/dev/null || echo ".NET 4.0 installation attempted"
    
    echo "Wine component installation complete"
    
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

# Look specifically for IPS.exe first (case variations and subdirectories)
if [ -f "$WINE_IPS_DIR/Bin/IPS.exe" ]; then
    IPS_EXE="C:\\IPS\\Bin\\IPS.exe"
    echo "Found: $WINE_IPS_DIR/Bin/IPS.exe (Wine path: $IPS_EXE)"
elif [ -f "$WINE_IPS_DIR/bin/IPS.exe" ]; then
    IPS_EXE="C:\\IPS\\bin\\IPS.exe"
    echo "Found: $WINE_IPS_DIR/bin/IPS.exe (Wine path: $IPS_EXE)"
elif [ -f "$WINE_IPS_DIR/Bin/ips.exe" ]; then
    IPS_EXE="C:\\IPS\\Bin\\ips.exe"
    echo "Found: $WINE_IPS_DIR/Bin/ips.exe (Wine path: $IPS_EXE)"
elif [ -f "$WINE_IPS_DIR/bin/ips.exe" ]; then
    IPS_EXE="C:\\IPS\\bin\\ips.exe"
    echo "Found: $WINE_IPS_DIR/bin/ips.exe (Wine path: $IPS_EXE)"
elif [ -f "$WINE_IPS_DIR/IPS.exe" ]; then
    IPS_EXE="C:\\IPS\\IPS.exe"
    echo "Found: $WINE_IPS_DIR/IPS.exe (Wine path: $IPS_EXE)"
elif [ -f "$WINE_IPS_DIR/ips.exe" ]; then
    IPS_EXE="C:\\IPS\\ips.exe"
    echo "Found: $WINE_IPS_DIR/ips.exe (Wine path: $IPS_EXE)"
else
    echo "Error: IPS.exe not found in $WINE_IPS_DIR or subdirectories"
    echo "Searching for all .exe files:"
    find "$WINE_IPS_DIR" -name "*.exe" -type f 2>/dev/null | while read exe_file; do
        rel_path=$(echo "$exe_file" | sed "s|$WINE_IPS_DIR/||")
        echo "  $rel_path"
    done
    echo
    echo "Please ensure IPS.exe is in the ZIP file in the expected location"
    exit 1
fi

if [ -n "$IPS_EXE" ]; then
    echo "Starting IPS using Wine path: $IPS_EXE"
    echo "Wine command: wine \"$IPS_EXE\""
    
    # Change to IPS directory in Wine before running (important for DLL loading)
    cd "$WINE_IPS_DIR"
    echo "Working directory: $(pwd)"
    
    # Set additional Wine environment for better DLL loading
    export WINEDLLPATH="$WINE_IPS_DIR/Bin;$WINE_IPS_DIR"
    
    # Show available DLL files for debugging
    echo "Available DLL files in IPS directory:"
    find "$WINE_IPS_DIR" -name "*.dll" -type f | head -10
    
    # Run with more verbose output and timeout
    timeout 60 wine "$IPS_EXE" "$@" 2>&1 | while IFS= read -r line; do
        echo "[Wine] $line"
    done
    
    EXIT_CODE=$?
    echo "Wine exit code: $EXIT_CODE"
    
    if [ $EXIT_CODE -eq 124 ]; then
        echo "Warning: Wine process timed out after 60 seconds"
        echo "This might mean IPS is running in background or hung"
        echo "Check with: ps aux | grep wine"
    elif [ $EXIT_CODE -ne 0 ]; then
        echo "IPS exited with error code: $EXIT_CODE"
        echo "Common solutions:"
        echo "1. Run: ips-configure-odbc (for database connection issues)"
        echo "2. Check if all DLL files are present in the IPS directory"
        echo "3. Try: ips-uninstall && ips (for fresh Wine environment)"
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
      
      # Create ODBC configuration helper
      cat > $out/bin/ips-configure-odbc <<'EOF'
#!/bin/sh
echo "=== IPS ODBC Configuration ==="

# Calculate the same hash as the launcher
IPS_HASH=$(echo "${placeholder "out"}" | sha256sum | cut -d' ' -f1 | head -c16)
CURRENT_WINEPREFIX="$HOME/.wine-ips-$IPS_HASH"

if [ ! -d "$CURRENT_WINEPREFIX" ]; then
    echo "Wine prefix not found. Run 'ips' first to create it."
    exit 1
fi

export WINEPREFIX="$CURRENT_WINEPREFIX"
export WINEARCH=win32

echo "Configuring ODBC for IPS..."
echo "Wine prefix: $WINEPREFIX"

# Open Wine's ODBC configuration
echo "Opening ODBC Data Source Administrator..."
echo "This will help you configure database connections for IPS"
echo "Look for SQL Server, Oracle, or other database drivers"
echo

wine control odbccp32.cpl

echo
echo "ODBC configuration completed"
echo "You can also manually edit registry entries if needed:"
echo "  wine regedit"
echo "Navigate to: HKEY_LOCAL_MACHINE\\SOFTWARE\\ODBC\\ODBCINST.INI"
EOF
      chmod +x $out/bin/ips-configure-odbc
      
      # Create uninstaller
      cat > $out/bin/ips-uninstall <<'EOF'
#!/bin/sh
echo "Removing all IPS Wine environments..."

# Stop all Wine processes first
echo "Stopping all Wine processes..."
killall wine wineserver 2>/dev/null || true
sleep 2

# Remove all IPS Wine prefixes
REMOVED=0
FAILED=0
for prefix in "$HOME"/.wine-ips-*; do
    if [ -d "$prefix" ]; then
        echo "Removing: $prefix"
        
        # Try to stop Wine server for this specific prefix
        WINEPREFIX="$prefix" wineserver -k 2>/dev/null || true
        sleep 1
        
        # Try to remove
        if rm -rf "$prefix" 2>/dev/null; then
            echo "Successfully removed: $prefix"
            REMOVED=$((REMOVED + 1))
        else
            echo "Failed to remove: $prefix (permission denied or in use)"
            echo "Try running: sudo rm -rf '$prefix'"
            FAILED=$((FAILED + 1))
        fi
    fi
done

if [ $REMOVED -eq 0 ] && [ $FAILED -eq 0 ]; then
    echo "No IPS Wine environments found"
elif [ $FAILED -gt 0 ]; then
    echo "Removed $REMOVED environment(s), failed to remove $FAILED"
    echo "You may need to manually remove remaining directories or reboot"
else
    echo "Successfully removed $REMOVED IPS Wine environment(s)"
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
