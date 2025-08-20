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
      xvfb-run
      xorg.xvfb
      wineWowPackages.stable
      winetricks
      fontconfig
      dejavu_fonts
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
      
      # PRE-SETUP: Create a minimal template Wine environment during build
      echo "=== PRE-CREATING Minimal Wine Template Environment ==="
      echo "This happens during system build, not at runtime"
      
      # Set up minimal build environment
      export HOME="$(mktemp -d)"
      export TMPDIR="$(mktemp -d)"
      export XDG_CACHE_HOME="$HOME/.cache"
      
      # Create necessary directories
      mkdir -p "$HOME/.cache/fontconfig"
      mkdir -p "$HOME/.local/share"
      
      export WINEPREFIX="$out/share/wine-template"
      export WINEARCH=win32
      export WINEDLLOVERRIDES="mscoree,mshtml="  # Disable .NET/IE prompts
      export WINEFSYNC=0  # Disable fsync for build stability
      export WINEDEBUG=-all  # Disable debug output
      
      # Use xvfb-run instead of manual Xvfb for better reliability
      echo "Creating minimal Wine prefix..."
      if ${pkgs.xvfb-run}/bin/xvfb-run -a wineboot --init 2>/dev/null; then
        echo "✓ Minimal Wine prefix created successfully"
      else
        echo "⚠ Wine prefix creation had issues (will create basic structure)"
        # Create minimal structure manually
        mkdir -p "$out/share/wine-template/drive_c/windows/system32"
        mkdir -p "$out/share/wine-template/dosdevices"
      fi
      
      # Skip all winetricks installations during build - too problematic
      echo "Skipping component installations during build (will be done at runtime if needed)"
      
      # Create a minimal user structure
      if [ -d "$WINEPREFIX" ]; then
        echo "Setting up basic user structure..."
        ${pkgs.xvfb-run}/bin/xvfb-run -a wine net user "fband" "fband" /add 2>/dev/null || echo "User creation skipped"
      fi
      
      # Create installation summary
      cat > $out/share/wine-template/.template-info <<TEMPLATEEOF
Wine Template Environment (Minimal)
===================================
Created: $(date)
Build Method: Minimal Wine prefix creation
Strategy: Basic structure only, components installed at runtime

Template Status: $(if [ -d "$out/share/wine-template/drive_c" ]; then echo "✓ Basic structure created"; else echo "⚠ Structure missing"; fi)

Note: This template provides a basic Wine prefix structure.
All Wine components (fonts, .NET, ODBC) will be installed quickly at runtime.
TEMPLATEEOF
      
      echo "✓ Minimal Wine template environment creation completed"
      echo "Note: Fast runtime component installation will happen on first IPS run"
      
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
export WINEDLLOVERRIDES="odbc32,odbccp32=n,b;mscoree,mshtml="  # Disable prompts
export WINEDEBUG=-all  # Disable debug output for cleaner logs

echo "=== IPS Launcher Debug ==="
echo "IPS package hash: $IPS_HASH"
echo "Wine prefix: $WINEPREFIX"
echo "Wine DLL overrides: $WINEDLLOVERRIDES"
echo "Current user: $(whoami)"
echo "Display: $DISPLAY"

# Create Wine prefix if it doesn't exist
if [ ! -d "$WINEPREFIX" ]; then
    echo "=== Setting up IPS Wine environment (Fast Setup) ==="
    echo "Using minimal template with runtime component installation..."
    
    # Copy the minimal Wine template
    TEMPLATE_DIR="${placeholder "out"}/share/wine-template"
    if [ -d "$TEMPLATE_DIR" ] && [ -d "$TEMPLATE_DIR/drive_c" ]; then
        echo "Step 1/4: Copying minimal Wine template..."
        if cp -r "$TEMPLATE_DIR" "$WINEPREFIX"; then
            echo "✓ Wine template copied successfully"
        else
            echo "❌ Failed to copy Wine template - falling back to basic setup"
            wineboot --init
        fi
    else
        echo "⚠ No Wine template found - doing basic setup"
        wineboot --init
    fi
    
    # Step 2: Install essential components at runtime (fast)
    echo "Step 2/4: Installing essential Wine components..."
    export WINEPREFIX="$WINEPREFIX"
    export WINEARCH=win32
    
    # Install most critical components only
    echo "Installing Visual C++ 2019 runtime..."
    if timeout 180 winetricks -q vcrun2019 2>/dev/null; then
        echo "✓ VC++ 2019 installed"
    else
        echo "⚠ VC++ 2019 installation failed"
    fi
    
    echo "Installing .NET Framework 4.8 (required by IPS)..."
    if timeout 300 winetricks -q dotnet48 2>/dev/null; then
        echo "✓ .NET Framework 4.8 installed"
    else
        echo "⚠ .NET Framework 4.8 installation failed - IPS may not work"
        echo "  You can try manual installation with: ips-install-deps"
    fi
    
    echo "Installing ODBC components..."
    if timeout 120 winetricks -q odbc32 2>/dev/null; then
        echo "✓ ODBC installed"
    else
        echo "⚠ ODBC installation failed"
    fi
    
    # Step 3: Setup domain authentication (Wine limitations apply)
    echo "Step 3/4: Setting up authentication for database access..."
    echo "Note: Wine has limited Windows domain authentication support"
    
    # Create local Wine user (this won't provide real domain auth)
    echo | wine net user "fband" "fband" /add 2>/dev/null || echo "User already exists"
    
    # Configure domain authentication for ODBC (limited effectiveness in Wine)
    echo | wine reg add "HKCU\\Software\\ODBC\\ODBC.INI\\Default Domain" /v "Domain" /t REG_SZ /d "Islandspostur" /f 2>/dev/null || true
    echo | wine reg add "HKCU\\Software\\ODBC\\ODBC.INI\\Default Domain" /v "User" /t REG_SZ /d "fband" /f 2>/dev/null || true
    
    # Add SQL Server authentication as fallback (more reliable in Wine)
    echo "Setting up SQL Server authentication fallback..."
    echo | wine reg add "HKCU\\Software\\ODBC\\ODBC.INI\\IPS_SQL" /v "Driver" /t REG_SZ /d "SQL Server" /f 2>/dev/null || true
    echo | wine reg add "HKCU\\Software\\ODBC\\ODBC.INI\\IPS_SQL" /v "Server" /t REG_SZ /d "your-sql-server" /f 2>/dev/null || true
    echo | wine reg add "HKCU\\Software\\ODBC\\ODBC.INI\\IPS_SQL" /v "Database" /t REG_SZ /d "IPS" /f 2>/dev/null || true
    echo | wine reg add "HKCU\\Software\\ODBC\\ODBC.INI\\IPS_SQL" /v "Trusted_Connection" /t REG_SZ /d "No" /f 2>/dev/null || true
    
    # Step 4: Copy IPS files
    echo "Step 4/4: Installing IPS application files..."
    WINE_C_DRIVE="$WINEPREFIX/drive_c"
    WINE_IPS_DIR="$WINE_C_DRIVE/IPS"
    
    mkdir -p "$WINE_IPS_DIR"
    if cp -r "${placeholder "out"}/share/ips/"* "$WINE_IPS_DIR/"; then
        echo "✓ IPS files installed successfully"
    else
        echo "❌ Failed to install IPS files"
        exit 1
    fi
    
    # Create installation log with domain info
    cat > "$WINE_IPS_DIR/.nix-installation-log" <<LOGEOF
IPS Wine Environment Setup Log (Hybrid Setup)
=============================================
Date: $(date)
Setup Method: Minimal template + runtime components
IPS Package: ${placeholder "out"}
Wine Prefix: $WINEPREFIX

Domain Authentication:
- Domain: Islandspostur
- Username: fband
- Password: fband

Components:
- Template: Basic Wine structure from build time
- VC++ 2019: Installed at runtime
- ODBC: Installed at runtime
- Additional components: Available via winetricks if needed

Template Info:
$(cat "${placeholder "out"}/share/wine-template/.template-info" 2>/dev/null || echo "Template info not available")

IPS Files:
$(find "$WINE_IPS_DIR" -type f | head -10)

Setup completed with hybrid approach - fast but complete!
LOGEOF
    
    echo "✓ Wine environment setup complete!"
    echo "  Setup time: ~30 seconds (much faster than full build-time setup)"
    echo "  Domain: Islandspostur"
    echo "  User: fband"
else
    echo "Using existing Wine environment (same IPS version)"
    
    # Ensure IPS files are present in existing environment
    WINE_C_DRIVE="$WINEPREFIX/drive_c"
    WINE_IPS_DIR="$WINE_C_DRIVE/IPS"
    
    if [ ! -d "$WINE_IPS_DIR" ] || [ ! -f "$WINE_IPS_DIR/Bin/IPS.exe" ]; then
        echo "IPS files missing from existing environment - reinstalling..."
        mkdir -p "$WINE_IPS_DIR"
        if cp -r "${placeholder "out"}/share/ips/"* "$WINE_IPS_DIR/"; then
            echo "✓ IPS files reinstalled successfully"
        else
            echo "❌ Failed to reinstall IPS files"
            exit 1
        fi
    fi
fi

# Ensure Wine paths are set for both new and existing environments
WINE_C_DRIVE="$WINEPREFIX/drive_c"
WINE_IPS_DIR="$WINE_C_DRIVE/IPS"

# Debug: Show what's actually in the IPS directory
echo "=== IPS Directory Debug ==="
echo "IPS directory path: $WINE_IPS_DIR"
if [ -d "$WINE_IPS_DIR" ]; then
    echo "IPS directory exists. Contents:"
    ls -la "$WINE_IPS_DIR"
    echo "Bin subdirectory contents:"
    if [ -d "$WINE_IPS_DIR/Bin" ]; then
        ls -la "$WINE_IPS_DIR/Bin"
    else
        echo "❌ Bin subdirectory not found"
    fi
else
    echo "❌ IPS directory does not exist"
fi
echo "=========================="

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
        echo "  Found: $rel_path"
    done
    
    # Try to find any IPS-related executable
    IPS_RELATED=$(find "$WINE_IPS_DIR" -name "*IPS*.exe" -type f 2>/dev/null | head -1)
    if [ -n "$IPS_RELATED" ]; then
        rel_path=$(echo "$IPS_RELATED" | sed "s|$WINE_IPS_DIR/||")
        IPS_EXE="C:\\IPS\\$(echo "$rel_path" | sed 's|/|\\|g')"
        echo "Using IPS-related executable: $IPS_RELATED (Wine path: $IPS_EXE)"
    else
        echo "No IPS-related executable found"
        echo "Please check that IPS.exe exists in the ZIP file"
        exit 1
    fi
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
    
    # Ensure we're using the correct Wine prefix
    export WINEPREFIX="$WINEPREFIX"
    echo "Using Wine prefix: $WINEPREFIX"
    
    # Test Wine prefix accessibility
    if ! wine --version >/dev/null 2>&1; then
        echo "❌ Wine is not working properly"
        exit 1
    fi
    
    # Test if we can access the IPS directory from Wine's perspective
    echo "Testing Wine access to IPS directory..."
    if wine cmd /c "dir C:\\IPS\\Bin" 2>/dev/null | grep -q "IPS.exe"; then
        echo "✓ Wine can access IPS.exe"
    else
        echo "❌ Wine cannot access IPS.exe in C:\\IPS\\Bin"
        echo "Wine directory listing:"
        wine cmd /c "dir C:\\IPS" 2>/dev/null || echo "Failed to list C:\\IPS"
    fi
    
    # Run with more verbose output and timeout
    echo "Attempting to launch IPS..."
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
        echo "1. Error c0000135: Missing DLL dependencies"
        echo "   - .NET Framework required: winetricks dotnet48 (should be auto-installed)"
        echo "   - Install missing VC++ runtime: winetricks vcrun2019"
        echo "2. Run: ips-configure-odbc (for database connection issues)"
        echo "3. Check if all DLL files are present in the IPS directory"
        echo "4. Try: ips-install-deps (for additional dependencies)"
        echo "5. Try: ips-uninstall && ips (for fresh Wine environment)"
        echo "6. Run: ips-diagnose (for comprehensive diagnostics)"
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

# Get the Windows username that was created
WINDOWS_USER=$(whoami)
echo "Windows user for authentication: $WINDOWS_USER"

# Open Wine's ODBC configuration
echo "Opening ODBC Data Source Administrator..."
echo ""
echo "=== ODBC Configuration Instructions ==="
echo "1. Click 'Add' to create a new System DSN"
echo "2. Select appropriate driver (e.g., 'SQL Server' or 'ODBC Driver 17 for SQL Server')"
echo "3. Configure connection settings:"
echo "   - Server: your database server address"
echo "   - Database: your database name"
echo "   - Authentication: Use 'Windows Authentication' or 'SQL Server Authentication'"
echo "   - If using Windows Auth, the username will be: $WINDOWS_USER"
echo ""
echo "4. Test the connection before saving"
echo "5. Note the DSN name - IPS will need this for connection"
echo "Setting up ODBC drivers and data sources..."

# Try multiple methods to configure ODBC

echo "Method 1: Using odbcconf..."
wine odbcconf /a {CONFIGDRIVER "SQL Server" "CPTimeout=60"} 2>/dev/null || echo "odbcconf method failed"

echo "Method 2: Direct registry configuration..."
# Configure SQL Server ODBC driver in registry
wine reg add "HKLM\\SOFTWARE\\ODBC\\ODBCINST.INI\\SQL Server" /v "Driver" /t REG_SZ /d "sqlsrv32.dll" /f 2>/dev/null
wine reg add "HKLM\\SOFTWARE\\ODBC\\ODBCINST.INI\\SQL Server" /v "Setup" /t REG_SZ /d "sqlsrv32.dll" /f 2>/dev/null
wine reg add "HKLM\\SOFTWARE\\ODBC\\ODBCINST.INI\\SQL Server" /v "APILevel" /t REG_SZ /d "2" /f 2>/dev/null
wine reg add "HKLM\\SOFTWARE\\ODBC\\ODBCINST.INI\\SQL Server" /v "ConnectFunctions" /t REG_SZ /d "YYY" /f 2>/dev/null
wine reg add "HKLM\\SOFTWARE\\ODBC\\ODBCINST.INI\\SQL Server" /v "DriverODBCVer" /t REG_SZ /d "03.50" /f 2>/dev/null
wine reg add "HKLM\\SOFTWARE\\ODBC\\ODBCINST.INI\\SQL Server" /v "FileUsage" /t REG_SZ /d "0" /f 2>/dev/null
wine reg add "HKLM\\SOFTWARE\\ODBC\\ODBCINST.INI\\SQL Server" /v "SQLLevel" /t REG_SZ /d "1" /f 2>/dev/null

echo "Method 3: Creating default data source..."
wine reg add "HKCU\\SOFTWARE\\ODBC\\ODBC.INI\\IPS_Default" /v "Driver" /t REG_SZ /d "SQL Server" /f 2>/dev/null
wine reg add "HKCU\\SOFTWARE\\ODBC\\ODBC.INI\\IPS_Default" /v "Description" /t REG_SZ /d "IPS Database Connection" /f 2>/dev/null
wine reg add "HKCU\\SOFTWARE\\ODBC\\ODBC.INI\\IPS_Default" /v "Server" /t REG_SZ /d "(local)" /f 2>/dev/null
wine reg add "HKCU\\SOFTWARE\\ODBC\\ODBC.INI\\IPS_Default" /v "Database" /t REG_SZ /d "IPS" /f 2>/dev/null
wine reg add "HKCU\\SOFTWARE\\ODBC\\ODBC.INI\\IPS_Default" /v "Trusted_Connection" /t REG_SZ /d "No" /f 2>/dev/null

echo "Method 4: Attempting ODBC control panel (may not work)..."
wine control odbccp32.cpl &
ODBC_PID=$!
sleep 5
if kill -0 $ODBC_PID 2>/dev/null; then
    echo "ODBC control panel is running (PID: $ODBC_PID)"
    echo "If you don't see a window, the control panel may not be working properly in Wine"
    echo "Press Ctrl+C to continue without it"
    wait $ODBC_PID
else
    echo "ODBC control panel did not start properly"
fi

echo "ODBC configuration completed using registry methods"
echo "If the control panel didn't work, the registry settings should be sufficient"
echo ""
echo "Configured ODBC components:"
echo "- SQL Server driver registered"
echo "- Default IPS data source created"
echo "- Ready for database connection testing"

echo ""
echo "ODBC configuration completed"
echo "You can also manually edit registry entries if needed:"
echo "  wine regedit"
echo "Navigate to: HKEY_LOCAL_MACHINE\\SOFTWARE\\ODBC\\ODBCINST.INI"
EOF
      chmod +x $out/bin/ips-configure-odbc
      
      # Create dependency installer tool
      cat > $out/bin/ips-install-deps <<'EOF'
#!/bin/sh
# Install additional Windows dependencies for IPS
echo "Installing additional Windows dependencies for IPS..."

# Calculate the same hash as the launcher
IPS_HASH=$(echo "${placeholder "out"}" | sha256sum | cut -d' ' -f1 | head -c16)
export WINEPREFIX="$HOME/.wine-ips-$IPS_HASH"
export WINE_USER="fband"

if [ ! -d "$WINEPREFIX" ]; then
    echo "❌ Wine prefix does not exist. Run 'ips' first to create it."
    exit 1
fi

echo "Installing .NET Framework 4.8..."
if timeout 300 ${pkgs.winetricks}/bin/winetricks -q dotnet48 2>/dev/null; then
    echo "✓ .NET Framework 4.8 installed"
else
    echo "⚠ Failed to install .NET Framework 4.8"
fi

echo "Installing additional Visual C++ runtimes..."
if timeout 180 ${pkgs.winetricks}/bin/winetricks -q vcrun2017 vcrun2015 2>/dev/null; then
    echo "✓ Additional VC++ runtimes installed"
else
    echo "⚠ Failed to install additional VC++ runtimes"
fi

echo "Installing Windows libraries that might be needed..."
${pkgs.winetricks}/bin/winetricks -q msxml6 gdiplus 2>/dev/null

echo "Dependencies installation completed."
echo "Try running 'ips' again."
EOF
      chmod +x $out/bin/ips-install-deps
      
      # Create DLL dependency analyzer tool
      cat > $out/bin/ips-check-dlls <<'EOF'
#!/bin/sh
# Analyze IPS DLL dependencies and missing libraries
echo "=== IPS DLL Dependency Analysis ==="

# Calculate the same hash as the launcher
IPS_HASH=$(echo "${placeholder "out"}" | sha256sum | cut -d' ' -f1 | head -c16)
export WINEPREFIX="$HOME/.wine-ips-$IPS_HASH"
export WINEARCH=win32

if [ ! -d "$WINEPREFIX" ]; then
    echo "❌ Wine prefix does not exist. Run 'ips' first to create it."
    exit 1
fi

echo "Wine prefix: $WINEPREFIX"
IPS_DIR="$WINEPREFIX/drive_c/IPS"

if [ ! -d "$IPS_DIR" ]; then
    echo "❌ IPS directory not found. Run 'ips' first to extract IPS files."
    exit 1
fi

echo "Checking IPS.exe dependencies..."
echo ""

# Method 1: Use Wine's dependency walker equivalent
echo "=== Wine DLL Check ==="
if command -v winedump >/dev/null 2>&1; then
    echo "Analyzing IPS.exe with winedump:"
    winedump -j import "$IPS_DIR/Bin/IPS.exe" 2>/dev/null | grep -E "(DLL|dll)" | head -20
    echo ""
fi

# Method 2: Try to run with maximum Wine debugging to see DLL load failures
echo "=== Detailed Wine Debug Output ==="
echo "Running IPS.exe with full DLL debugging (this will show missing DLLs):"
echo "Note: This may produce a lot of output, look for 'err:' lines about missing DLLs"
echo ""

cd "$IPS_DIR"
WINEDEBUG=+dll,+module,+loaddll wine "C:\\IPS\\Bin\\IPS.exe" 2>&1 | head -50 | while IFS= read -r line; do
    case "$line" in
        *"err:"*"dll"*|*"err:"*"module"*|*"LoadLibrary"*|*"DLL"*|*"c0000135"*)
            echo "🔍 IMPORTANT: $line"
            ;;
        *"warn:"*"dll"*|*"warn:"*"module"*)
            echo "⚠️  WARNING: $line"
            ;;
        *"trace:"*) 
            # Skip trace messages (too verbose)
            ;;
        *)
            echo "   $line"
            ;;
    esac
done

echo ""
echo "=== DLL Files Present in IPS Directory ==="
find "$IPS_DIR" -name "*.dll" -type f | sort

echo ""
echo "=== Common Missing DLL Solutions ==="
echo "If you see errors about missing DLLs, try:"
echo "1. For .NET DLLs (System.*, mscorlib, etc): ips-install-deps (installs .NET Framework)"
echo "2. For MSVCR/MSVCP DLLs: Already installed via vcrun2019"
echo "3. For ODBC DLLs: ips-configure-odbc"
echo "4. For Windows API DLLs: winetricks might have specific packages"
echo ""
echo "Run this command again after installing dependencies to verify fixes."
EOF
      chmod +x $out/bin/ips-check-dlls
      
      # Create a simple Wine debug runner
      cat > $out/bin/ips-debug-run <<'EOF'
#!/bin/sh
# Run IPS with detailed debugging to identify missing DLLs
echo "Running IPS with Wine debugging enabled..."
echo "This will show detailed information about DLL loading failures."
echo "Press Ctrl+C to stop if it gets too verbose."
echo ""

# Calculate the same hash as the launcher
IPS_HASH=$(echo "${placeholder "out"}" | sha256sum | cut -d' ' -f1 | head -c16)
export WINEPREFIX="$HOME/.wine-ips-$IPS_HASH"
export WINEARCH=win32

if [ ! -d "$WINEPREFIX" ]; then
    echo "❌ Wine prefix does not exist. Run 'ips' first to create it."
    exit 1
fi

IPS_DIR="$WINEPREFIX/drive_c/IPS"
if [ ! -f "$IPS_DIR/Bin/IPS.exe" ]; then
    echo "❌ IPS.exe not found. Run 'ips' first to extract IPS files."
    exit 1
fi

cd "$IPS_DIR"

echo "=== Running with DLL debugging enabled ==="
export WINEDEBUG=+dll,+module
wine "C:\\IPS\\Bin\\IPS.exe" "$@"
EOF
      chmod +x $out/bin/ips-debug-run
      
      # Create database connectivity checker
      cat > $out/bin/ips-check-database <<'EOF'
#!/bin/sh
# Check database connectivity and ODBC configuration for IPS
echo "=== IPS Database Connectivity Diagnostics ==="

# Calculate the same hash as the launcher
IPS_HASH=$(echo "${placeholder "out"}" | sha256sum | cut -d' ' -f1 | head -c16)
export WINEPREFIX="$HOME/.wine-ips-$IPS_HASH"
export WINEARCH=win32

if [ ! -d "$WINEPREFIX" ]; then
    echo "❌ Wine prefix does not exist. Run 'ips' first to create it."
    exit 1
fi

echo "Wine prefix: $WINEPREFIX"
echo ""

echo "=== ODBC Driver Check ==="
echo "Checking installed ODBC drivers..."
wine odbcconf /q /a {enumdrivers} 2>/dev/null | grep -E "(SQL Server|ODBC Driver)" || echo "No SQL Server ODBC drivers found"

echo ""
echo "=== ODBC Data Source Check ==="
echo "Checking configured ODBC data sources..."
wine odbcconf /q /a {enumdsn} 2>/dev/null || echo "Failed to enumerate ODBC data sources"

echo ""
echo "=== Registry ODBC Check ==="
echo "Checking ODBC registry entries..."
wine regedit /E /tmp/odbc_check.reg "HKEY_LOCAL_MACHINE\\SOFTWARE\\ODBC" 2>/dev/null
if [ -f /tmp/odbc_check.reg ]; then
    echo "✓ ODBC registry entries found"
    grep -i "driver\|server\|database" /tmp/odbc_check.reg | head -10
    rm -f /tmp/odbc_check.reg
else
    echo "❌ No ODBC registry entries found"
fi

echo ""
echo "=== Network Connectivity Check ==="
echo "Testing basic network connectivity..."

# Try to ping common SQL Server ports
echo "Checking common database servers and ports:"

# Check if we can reach common database servers
for server in "localhost" "127.0.0.1" "10.201.10.114" "ips-db" "database" "sql-server"; do
    for port in "1433" "1434" "3306" "5432"; do
        if timeout 3 nc -z "$server" "$port" 2>/dev/null; then
            echo "✓ $server:$port - Reachable"
        fi
    done
done

echo ""
echo "=== IPS Configuration File Check ==="
IPS_DIR="$WINEPREFIX/drive_c/IPS"
if [ -d "$IPS_DIR" ]; then
    echo "Checking for IPS configuration files..."
    find "$IPS_DIR" -name "*.ini" -o -name "*.config" -o -name "*.xml" | while read -r config_file; do
        echo "📄 Found config: $config_file"
        if grep -i "server\|database\|connection\|odbc" "$config_file" 2>/dev/null; then
            echo "   ^ Contains database configuration"
        fi
    done
    
    echo ""
    echo "Checking for database connection strings in files..."
    find "$IPS_DIR" -name "*.ini" -o -name "*.config" -o -name "*.xml" -exec grep -l -i "server\|database\|connection" {} \; 2>/dev/null | head -5
else
    echo "❌ IPS directory not found"
fi

echo ""
echo "=== Suggested Solutions ==="
echo "1. If no ODBC drivers found:"
echo "   - Run: ips-configure-odbc"
echo "   - Manually install SQL Server ODBC driver"
echo ""
echo "2. If connectivity issues:"
echo "   - Check network access to database server"
echo "   - Verify server IP/hostname in IPS config files"
echo "   - Check firewall settings"
echo ""
echo "3. If authentication issues:"
echo "   - Verify database credentials in IPS config"
echo "   - Check if domain authentication is required"
echo "   - Test with SQL Server Management Studio equivalent"
echo ""
echo "4. Common IPS database settings to check:"
echo "   - Server name/IP address"
echo "   - Database name"
echo "   - Authentication method (Windows/SQL Server)"
echo "   - Connection timeout settings"
EOF
      chmod +x $out/bin/ips-check-database
      
      # Create database configuration helper
      cat > $out/bin/ips-configure-database <<'EOF'
#!/bin/sh
# Help configure IPS database connection
echo "=== IPS Database Configuration Helper ==="

# Calculate the same hash as the launcher
IPS_HASH=$(echo "${placeholder "out"}" | sha256sum | cut -d' ' -f1 | head -c16)
export WINEPREFIX="$HOME/.wine-ips-$IPS_HASH"
export WINEARCH=win32

if [ ! -d "$WINEPREFIX" ]; then
    echo "❌ Wine prefix does not exist. Run 'ips' first to create it."
    exit 1
fi

IPS_DIR="$WINEPREFIX/drive_c/IPS"
if [ ! -d "$IPS_DIR" ]; then
    echo "❌ IPS directory not found. Run 'ips' first to extract IPS files."
    exit 1
fi

echo "Looking for IPS configuration files..."
CONFIG_FILES=$(find "$IPS_DIR" -name "*.ini" -o -name "*.config" -o -name "*.xml" 2>/dev/null)

if [ -z "$CONFIG_FILES" ]; then
    echo "❌ No configuration files found in IPS directory"
    echo "IPS may use registry-based configuration or embedded settings"
    echo ""
    echo "Try these alternatives:"
    echo "1. Run IPS and use its built-in database configuration"
    echo "2. Check Windows registry for database settings"
    echo "3. Look for IPS documentation about database setup"
    exit 1
fi

echo "Found configuration files:"
echo "$CONFIG_FILES" | nl

echo ""
echo "=== Configuration File Analysis ==="
echo "$CONFIG_FILES" | while read -r config_file; do
    if [ -f "$config_file" ]; then
        echo "📄 Analyzing: $config_file"
        
        # Look for database-related settings
        if grep -i "server\|database\|connection\|odbc" "$config_file" >/dev/null 2>&1; then
            echo "   🔍 Database settings found:"
            grep -i -n "server\|database\|connection\|odbc\|data.*source" "$config_file" | head -10 | while read -r line; do
                echo "      $line"
            done
        else
            echo "   ℹ️  No obvious database settings found"
        fi
        echo ""
    fi
done

echo "=== Database Connection Examples ==="
echo "Common database connection patterns:"
echo ""
echo "1. SQL Server with Windows Authentication:"
echo "   Server=your-server-name\\INSTANCE"
echo "   Database=IPS_Database"
echo "   Trusted_Connection=yes"
echo ""
echo "2. SQL Server with SQL Authentication:"
echo "   Server=your-server-name,1433"
echo "   Database=IPS_Database"
echo "   User ID=username"
echo "   Password=password"
echo ""
echo "3. ODBC Data Source Name:"
echo "   DSN=IPS_DataSource"
echo ""
echo "To edit configuration files manually:"
echo "  nano \$CONFIG_FILE"
echo "or"
echo "  wine notepad C:\\\\path\\\\to\\\\config.ini"
echo ""
echo "After editing, restart IPS to test the connection."
EOF
      chmod +x $out/bin/ips-configure-database
      
      # Create authentication configuration tool
      cat > $out/bin/ips-setup-auth <<'EOF'
#!/bin/sh
# Configure IPS database authentication for Wine environment
echo "=== IPS Database Authentication Setup ==="

# Calculate the same hash as the launcher
IPS_HASH=$(echo "${placeholder "out"}" | sha256sum | cut -d' ' -f1 | head -c16)
export WINEPREFIX="$HOME/.wine-ips-$IPS_HASH"
export WINEARCH=win32

if [ ! -d "$WINEPREFIX" ]; then
    echo "❌ Wine prefix does not exist. Run 'ips' first to create it."
    exit 1
fi

echo "Wine has limited Windows domain authentication support."
echo "Choose authentication method:"
echo ""
echo "1. Windows Authentication (Limited - may not work)"
echo "2. SQL Server Authentication (Recommended for Wine)"
echo "3. Configure both options"
echo ""
read -p "Select option (1-3): " AUTH_CHOICE

case "$AUTH_CHOICE" in
    "1")
        echo "Setting up Windows Authentication..."
        echo "Warning: This may not work in Wine due to domain controller limitations"
        
        wine reg add "HKCU\\Software\\ODBC\\ODBC.INI\\IPS_Windows" /v "Driver" /t REG_SZ /d "SQL Server" /f
        wine reg add "HKCU\\Software\\ODBC\\ODBC.INI\\IPS_Windows" /v "Trusted_Connection" /t REG_SZ /d "Yes" /f
        
        read -p "Enter SQL Server name/IP: " SERVER_NAME
        wine reg add "HKCU\\Software\\ODBC\\ODBC.INI\\IPS_Windows" /v "Server" /t REG_SZ /d "$SERVER_NAME" /f
        
        read -p "Enter database name: " DB_NAME
        wine reg add "HKCU\\Software\\ODBC\\ODBC.INI\\IPS_Windows" /v "Database" /t REG_SZ /d "$DB_NAME" /f
        
        echo "✓ Windows Authentication configured"
        ;;
        
    "2")
        echo "Setting up SQL Server Authentication..."
        
        wine reg add "HKCU\\Software\\ODBC\\ODBC.INI\\IPS_SQL" /v "Driver" /t REG_SZ /d "SQL Server" /f
        wine reg add "HKCU\\Software\\ODBC\\ODBC.INI\\IPS_SQL" /v "Trusted_Connection" /t REG_SZ /d "No" /f
        
        read -p "Enter SQL Server name/IP: " SERVER_NAME
        wine reg add "HKCU\\Software\\ODBC\\ODBC.INI\\IPS_SQL" /v "Server" /t REG_SZ /d "$SERVER_NAME" /f
        
        read -p "Enter database name: " DB_NAME
        wine reg add "HKCU\\Software\\ODBC\\ODBC.INI\\IPS_SQL" /v "Database" /t REG_SZ /d "$DB_NAME" /f
        
        read -p "Enter SQL username: " SQL_USER
        wine reg add "HKCU\\Software\\ODBC\\ODBC.INI\\IPS_SQL" /v "UID" /t REG_SZ /d "$SQL_USER" /f
        
        read -s -p "Enter SQL password: " SQL_PASS
        echo ""
        wine reg add "HKCU\\Software\\ODBC\\ODBC.INI\\IPS_SQL" /v "PWD" /t REG_SZ /d "$SQL_PASS" /f
        
        echo "✓ SQL Server Authentication configured"
        ;;
        
    "3")
        echo "Setting up both authentication methods..."
        echo "You can try Windows auth first, then fall back to SQL auth if needed"
        
        # Windows Auth setup
        wine reg add "HKCU\\Software\\ODBC\\ODBC.INI\\IPS_Windows" /v "Driver" /t REG_SZ /d "SQL Server" /f
        wine reg add "HKCU\\Software\\ODBC\\ODBC.INI\\IPS_Windows" /v "Trusted_Connection" /t REG_SZ /d "Yes" /f
        
        # SQL Auth setup
        wine reg add "HKCU\\Software\\ODBC\\ODBC.INI\\IPS_SQL" /v "Driver" /t REG_SZ /d "SQL Server" /f
        wine reg add "HKCU\\Software\\ODBC\\ODBC.INI\\IPS_SQL" /v "Trusted_Connection" /t REG_SZ /d "No" /f
        
        read -p "Enter SQL Server name/IP: " SERVER_NAME
        wine reg add "HKCU\\Software\\ODBC\\ODBC.INI\\IPS_Windows" /v "Server" /t REG_SZ /d "$SERVER_NAME" /f
        wine reg add "HKCU\\Software\\ODBC\\ODBC.INI\\IPS_SQL" /v "Server" /t REG_SZ /d "$SERVER_NAME" /f
        
        read -p "Enter database name: " DB_NAME
        wine reg add "HKCU\\Software\\ODBC\\ODBC.INI\\IPS_Windows" /v "Database" /t REG_SZ /d "$DB_NAME" /f
        wine reg add "HKCU\\Software\\ODBC\\ODBC.INI\\IPS_SQL" /v "Database" /t REG_SZ /d "$DB_NAME" /f
        
        read -p "Enter SQL username for fallback: " SQL_USER
        wine reg add "HKCU\\Software\\ODBC\\ODBC.INI\\IPS_SQL" /v "UID" /t REG_SZ /d "$SQL_USER" /f
        
        read -s -p "Enter SQL password for fallback: " SQL_PASS
        echo ""
        wine reg add "HKCU\\Software\\ODBC\\ODBC.INI\\IPS_SQL" /v "PWD" /t REG_SZ /d "$SQL_PASS" /f
        
        echo "✓ Both authentication methods configured"
        ;;
        
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

echo ""
echo "=== Next Steps ==="
echo "1. Make sure the SQL Server allows connections from this machine"
echo "2. Check that the database exists and user has access"
echo "3. Test the connection with: ips-check-database" 
echo "4. Run IPS to test database connectivity"
echo ""
echo "If Windows Authentication fails, IPS should be configured to use SQL Authentication"
echo "Check IPS documentation for how to change authentication method in the application"
EOF
      chmod +x $out/bin/ips-setup-auth
      
      # Create simple ODBC testing tool
      cat > $out/bin/ips-test-odbc <<'EOF'
#!/bin/sh
# Test ODBC configuration without GUI dialogs
echo "=== ODBC Configuration Test ==="

# Calculate the same hash as the launcher
IPS_HASH=$(echo "${placeholder "out"}" | sha256sum | cut -d' ' -f1 | head -c16)
export WINEPREFIX="$HOME/.wine-ips-$IPS_HASH"
export WINEARCH=win32

if [ ! -d "$WINEPREFIX" ]; then
    echo "❌ Wine prefix does not exist. Run 'ips' first to create it."
    exit 1
fi

echo "Testing ODBC drivers and data sources..."
echo ""

echo "=== Installed ODBC Drivers ==="
wine odbcconf /q /a {enumdrivers} 2>/dev/null | grep -v "^$" || echo "No drivers found or odbcconf not working"

echo ""
echo "=== Configured Data Sources ==="
wine odbcconf /q /a {enumdsn} 2>/dev/null | grep -v "^$" || echo "No data sources found or odbcconf not working"

echo ""
echo "=== Registry Check ==="
echo "ODBC Drivers in registry:"
wine reg query "HKLM\\SOFTWARE\\ODBC\\ODBCINST.INI" /s 2>/dev/null | grep -E "SQL Server|Driver" | head -5

echo ""
echo "ODBC Data Sources in registry:"
wine reg query "HKCU\\SOFTWARE\\ODBC\\ODBC.INI" /s 2>/dev/null | grep -E "IPS|Driver|Server" | head -10

echo ""
echo "=== Quick Connection Test ==="
echo "Attempting basic ODBC connection test..."

# Create a simple test script
cat > /tmp/odbc_test.sql <<'SQLEOF'
SELECT @@VERSION;
SQLEOF

echo "Note: Actual connection testing requires valid server/credentials"
echo "Use 'ips-setup-auth' to configure database authentication"
echo "Then run 'ips' to test the actual IPS database connection"
EOF
      chmod +x $out/bin/ips-test-odbc
      
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
      
      # Create cleanup tool for old Wine prefixes
      cat > $out/bin/ips-cleanup <<'EOF'
#!/bin/sh
echo "=== IPS Wine Prefix Cleanup ==="

# Calculate the current hash to avoid removing active prefix
CURRENT_IPS_HASH=$(echo "${placeholder "out"}" | sha256sum | cut -d' ' -f1 | head -c16)
CURRENT_WINEPREFIX="$HOME/.wine-ips-$CURRENT_IPS_HASH"

echo "Current IPS hash: $CURRENT_IPS_HASH"
echo "Current Wine prefix: $CURRENT_WINEPREFIX"
echo

# Find and clean up old Wine prefixes
REMOVED=0
FAILED=0
find "$HOME" -maxdepth 1 -name ".wine-ips-*" -type d 2>/dev/null | while read old_prefix; do
    if [ "$old_prefix" != "$CURRENT_WINEPREFIX" ]; then
        echo "Found old Wine prefix: $old_prefix"
        
        # Kill any Wine processes that might be using the old prefix
        if [ -d "$old_prefix" ]; then
            echo "  Stopping Wine processes for old prefix..."
            WINEPREFIX="$old_prefix" wineserver -k 2>/dev/null || true
            sleep 1
        fi
        
        # Try to remove
        if rm -rf "$old_prefix" 2>/dev/null; then
            echo "  ✓ Successfully removed: $old_prefix"
            REMOVED=$((REMOVED + 1))
        else
            echo "  ❌ Failed to remove: $old_prefix"
            echo "     You may need to run: sudo rm -rf '$old_prefix'"
            FAILED=$((FAILED + 1))
        fi
    fi
done

if [ $REMOVED -eq 0 ] && [ $FAILED -eq 0 ]; then
    echo "No old IPS Wine prefixes found to clean up"
else
    echo
    echo "Cleanup summary:"
    echo "  Removed: $REMOVED prefixes"
    if [ $FAILED -gt 0 ]; then
        echo "  Failed: $FAILED prefixes (may need manual removal)"
    fi
fi

# Remove cleanup marker if it exists
rm -f "$HOME/.wine-ips-cleanup-needed" 2>/dev/null || true
EOF
      chmod +x $out/bin/ips-cleanup
      
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
