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
    echo "=== Setting up fresh IPS Wine environment ==="
    echo "This may take several minutes on first run..."
    
    # Step 1: Initialize Wine prefix
    echo "Step 1/6: Initializing Wine prefix..."
    if ! wineboot --init; then
        echo "ERROR: Failed to initialize Wine prefix"
        exit 1
    fi
    echo "✓ Wine prefix initialized"
    
    # Step 2: Wait for Wine to fully settle
    echo "Step 2/6: Waiting for Wine to settle..."
    sleep 3
    wineserver -w
    echo "✓ Wine settled"
    
    # Step 3: Install core fonts (critical for most apps)
    echo "Step 3/6: Installing core fonts..."
    if winetricks -q corefonts; then
        echo "✓ Core fonts installed"
    else
        echo "⚠ Core fonts installation failed (continuing anyway)"
    fi
    
    # Step 4: Install Visual C++ runtimes (try multiple versions)
    echo "Step 4/6: Installing Visual C++ runtimes..."
    for vcver in vcrun2015 vcrun2017 vcrun2019; do
        echo "  Installing $vcver..."
        if winetricks -q $vcver; then
            echo "  ✓ $vcver installed"
        else
            echo "  ⚠ $vcver failed (continuing)"
        fi
    done
    
    # Step 5: Install .NET frameworks (in order)
    echo "Step 5/6: Installing .NET frameworks..."
    for dotnet in dotnet35 dotnet40 dotnet48; do
        echo "  Installing $dotnet..."
        if timeout 300 winetricks -q $dotnet; then
            echo "  ✓ $dotnet installed"
        else
            echo "  ⚠ $dotnet failed or timed out (continuing)"
        fi
        # Wait between .NET installations
        sleep 2
        wineserver -w
    done
    
    # Step 6: Install database components
    echo "Step 6/6: Installing database components..."
    for dbcomp in odbc32 mdac28 jet40; do
        echo "  Installing $dbcomp..."
        if winetricks -q $dbcomp; then
            echo "  ✓ $dbcomp installed"
        else
            echo "  ⚠ $dbcomp failed (continuing)"
        fi
    done
    
    echo "=== Wine component installation summary ==="
    # Show what's actually installed
    echo "Installed Windows versions:"
    wine --version
    echo "Wine prefix contents:"
    ls -la "$WINEPREFIX/drive_c/" | head -10
    
    # Copy IPS files to Wine's C: drive
    WINE_C_DRIVE="$WINEPREFIX/drive_c"
    WINE_IPS_DIR="$WINE_C_DRIVE/IPS"
    
    echo "=== Copying IPS files to Wine C: drive ==="
    mkdir -p "$WINE_IPS_DIR"
    
    # Show what we're copying
    echo "Source files:"
    ls -la "${placeholder "out"}/share/ips"
    
    if cp -r "${placeholder "out"}/share/ips/"* "$WINE_IPS_DIR/"; then
        echo "✓ IPS files copied successfully"
    else
        echo "ERROR: Failed to copy IPS files"
        exit 1
    fi
    
    echo "Copied files:"
    ls -la "$WINE_IPS_DIR"
    
    # Create a detailed installation log
    cat > "$WINE_IPS_DIR/.nix-installation-log" <<LOGEOF
IPS Wine Environment Setup Log
=============================
Date: $(date)
IPS Package: ${placeholder "out"}
Wine Version: $(wine --version)
Wine Prefix: $WINEPREFIX

Components Attempted:
- Core Fonts: $(winetricks list-installed | grep corefonts >/dev/null && echo "✓ Installed" || echo "✗ Failed")
- VC++ 2015: $(winetricks list-installed | grep vcrun2015 >/dev/null && echo "✓ Installed" || echo "✗ Failed")
- VC++ 2019: $(winetricks list-installed | grep vcrun2019 >/dev/null && echo "✓ Installed" || echo "✗ Failed")
- .NET 3.5: $(winetricks list-installed | grep dotnet35 >/dev/null && echo "✓ Installed" || echo "✗ Failed")
- .NET 4.8: $(winetricks list-installed | grep dotnet48 >/dev/null && echo "✓ Installed" || echo "✗ Failed")
- ODBC: $(winetricks list-installed | grep odbc32 >/dev/null && echo "✓ Installed" || echo "✗ Failed")

IPS Files:
$(find "$WINE_IPS_DIR" -type f | head -20)

DLL Files Found:
$(find "$WINE_IPS_DIR" -name "*.dll" -type f | head -10)

EXE Files Found:
$(find "$WINE_IPS_DIR" -name "*.exe" -type f)
LOGEOF
    
    echo "✓ Installation log created at $WINE_IPS_DIR/.nix-installation-log"
    echo "=== Wine environment setup complete ==="
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
      
      # Create comprehensive Wine diagnostics tool
      cat > $out/bin/ips-diagnose <<'EOF'
#!/bin/sh
echo "=== IPS Wine Environment Diagnostics ==="

# Calculate the same hash as the launcher
IPS_HASH=$(echo "${placeholder "out"}" | sha256sum | cut -d' ' -f1 | head -c16)
CURRENT_WINEPREFIX="$HOME/.wine-ips-$IPS_HASH"

if [ ! -d "$CURRENT_WINEPREFIX" ]; then
    echo "❌ Wine prefix not found. Run 'ips' first to create it."
    exit 1
fi

export WINEPREFIX="$CURRENT_WINEPREFIX"
export WINEARCH=win32

echo "Wine Environment:"
echo "  Prefix: $WINEPREFIX"
echo "  Architecture: $WINEARCH"
echo "  Wine Version: $(wine --version)"
echo

echo "=== Installation Log ==="
if [ -f "$WINEPREFIX/drive_c/IPS/.nix-installation-log" ]; then
    cat "$WINEPREFIX/drive_c/IPS/.nix-installation-log"
else
    echo "❌ No installation log found"
fi
echo

echo "=== Winetricks Components Check ==="
echo "Installed components:"
winetricks list-installed 2>/dev/null || echo "Could not list installed components"
echo

echo "=== IPS Files Structure ==="
if [ -d "$WINEPREFIX/drive_c/IPS" ]; then
    echo "IPS directory exists ✓"
    echo "Contents:"
    find "$WINEPREFIX/drive_c/IPS" -type f | head -20
    echo
    echo "DLL files:"
    find "$WINEPREFIX/drive_c/IPS" -name "*.dll" | head -10
    echo
    echo "EXE files:"
    find "$WINEPREFIX/drive_c/IPS" -name "*.exe"
else
    echo "❌ IPS directory not found at $WINEPREFIX/drive_c/IPS"
fi
echo

echo "=== Wine Registry Check ==="
echo "Checking .NET installation in registry..."
wine regedit /E /tmp/dotnet_check.reg "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\NET Framework Setup\\NDP" 2>/dev/null
if [ -f /tmp/dotnet_check.reg ]; then
    echo "✓ .NET registry entries found"
    grep -i "version" /tmp/dotnet_check.reg | head -5
    rm -f /tmp/dotnet_check.reg
else
    echo "⚠ Could not check .NET registry"
fi
echo

echo "=== ODBC Configuration ==="
echo "ODBC drivers:"
wine odbcconf /q /A {REGSVR} 2>/dev/null || echo "ODBC check failed"
echo

echo "=== Wine Process Check ==="
echo "Running Wine processes:"
ps aux | grep wine | grep -v grep || echo "No Wine processes running"
echo

echo "=== Test Wine DLL Loading ==="
echo "Testing basic Wine functionality..."
if wine cmd /c "echo Wine command test" 2>/dev/null | grep -q "Wine command test"; then
    echo "✓ Wine command execution works"
else
    echo "❌ Wine command execution failed"
fi

echo
echo "=== Recommendations ==="
if ! winetricks list-installed | grep -q dotnet; then
    echo "⚠ No .NET framework detected - may cause DLL loading issues"
fi
if ! winetricks list-installed | grep -q vcrun; then
    echo "⚠ No Visual C++ runtime detected - may cause DLL loading issues"
fi
if [ ! -f "$WINEPREFIX/drive_c/IPS/Bin/IPS.exe" ]; then
    echo "❌ IPS.exe not found at expected location"
fi

echo
echo "To force a fresh Wine environment: ips-uninstall && ips"
EOF
      chmod +x $out/bin/ips-diagnose
      
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
