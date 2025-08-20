# Clean IPS application with NAS-based installer
{ config, pkgs, ... }:

let
  ipsApp = import ./ips-simple.nix { inherit pkgs; };
  dbTools = import ./database-tools.nix { inherit pkgs; };
  serialTools = import ./serial-tools.nix { inherit pkgs; };
in
{
  # Install main IPS application for all users
  environment.systemPackages = [
    ipsApp.ips
    # Add serial port diagnostic tools
    serialTools.check-serial
    serialTools.test-com
    # Add Wine to system packages so it's always available
    pkgs.wineWowPackages.stable
    pkgs.winetricks
    # Add debugging tool
    (pkgs.writeShellScriptBin "ips-debug-dlls" ''
      echo "=== IPS DLL Dependency Analysis ==="
      
      # Find Wine prefix
      WINE_PREFIX=$(ls -d $HOME/.wine-ips-* 2>/dev/null | head -1)
      if [ -z "$WINE_PREFIX" ]; then
        echo "❌ No Wine prefix found. Run 'ips' first."
        exit 1
      fi
      
      export WINEPREFIX="$WINE_PREFIX"
      export PATH="${pkgs.wineWowPackages.stable}/bin:$PATH"
      
      echo "Wine prefix: $WINEPREFIX"
      
      # Find IPS executable
      IPS_EXE=$(find "$WINEPREFIX/drive_c" -name "IPS.exe" -type f 2>/dev/null | head -1)
      if [ -z "$IPS_EXE" ]; then
        echo "❌ IPS.exe not found"
        exit 1
      fi
      
      echo "IPS executable: $IPS_EXE"
      IPS_DIR=$(dirname "$IPS_EXE")
      
      echo ""
      echo "=== DLL Files in IPS Directory ==="
      find "$IPS_DIR" -name "*.dll" -type f | sort
      
      echo ""
      echo "=== Wine DLL Loading Test ==="
      cd "$IPS_DIR"
      
      # Convert to Wine path
      IPS_WINE_PATH=$(echo "$IPS_EXE" | sed "s|$WINEPREFIX/drive_c|C:|" | sed 's|/|\\|g')
      echo "Testing DLL loading for: $IPS_WINE_PATH"
      
      # Test with maximum DLL debugging
      export WINEDEBUG=+dll,+module,+loaddll
      echo "Running with DLL debugging (will be verbose)..."
      timeout 10 wine "$IPS_WINE_PATH" 2>&1 | grep -E "(err:|warn:|DLL|dll|module)" | head -20
      
      echo ""
      echo "=== Component Analysis ==="
      echo "Checking installed Wine components..."
      wine uninstaller --list 2>/dev/null | head -10
      
      echo ""
      echo "=== Registry Check ==="
      echo "Checking Wine registry for IPS..."
      wine reg query "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall" 2>/dev/null | grep -i ips || echo "IPS not found in registry"
    '')
    # Wine environment helper for manual debugging
    (pkgs.writeShellScriptBin "wine-env" ''
      # Set up Wine environment for manual use
      WINE_PREFIX=$(ls -d $HOME/.wine-ips-* 2>/dev/null | head -1)
      if [ -z "$WINE_PREFIX" ]; then
        echo "❌ No Wine prefix found. Run 'ips' first to create one."
        exit 1
      fi
      
      export WINEPREFIX="$WINE_PREFIX"
      export PATH="${pkgs.wineWowPackages.stable}/bin:$PATH"
      
      echo "🍷 Wine environment ready!"
      echo "Wine prefix: $WINEPREFIX"
      echo "Wine version: $(wine --version)"
      echo ""
      echo "You can now run Wine commands like:"
      echo "  wine notepad"
      echo "  wine regedit"
      echo "  wine uninstaller"
      echo ""
      echo "To run other executables in IPS directory:"
      IPS_DIR=$(find "$WINEPREFIX/drive_c" -name "IPS.exe" -type f 2>/dev/null | head -1 | xargs dirname)
      if [ -n "$IPS_DIR" ]; then
        echo "  cd '$IPS_DIR'"
        echo "  wine SomeOtherApp.exe"
      fi
      echo ""
      echo "Starting a shell with Wine environment..."
      exec $SHELL
    '')
    # Wine hostname changer
    (pkgs.writeShellScriptBin "wine-set-hostname" ''
      #!/bin/bash
      
      # Set up Wine environment
      WINE_PREFIX=$(ls -d $HOME/.wine-ips-* 2>/dev/null | head -1)
      if [ -z "$WINE_PREFIX" ]; then
        echo "❌ No Wine prefix found. Run 'ips' first to create one."
        exit 1
      fi
      
      export WINEPREFIX="$WINE_PREFIX"
      export PATH="${pkgs.wineWowPackages.stable}/bin:$PATH"
      
      echo "🖥️  Wine Hostname Changer"
      echo "Current Wine prefix: $WINEPREFIX"
      echo ""
      
      # Show current hostname
      echo "Current hostname in Wine:"
      CURRENT_HOSTNAME=$(wine hostname 2>/dev/null || echo "unknown")
      echo "  → $CURRENT_HOSTNAME"
      echo ""
      
      # Get new hostname from user
      if [ -n "$1" ]; then
        NEW_HOSTNAME="$1"
        echo "Setting hostname to: $NEW_HOSTNAME"
      else
        echo "Enter new hostname (or press Enter to cancel):"
        read -r NEW_HOSTNAME
        
        if [ -z "$NEW_HOSTNAME" ]; then
          echo "❌ No hostname provided. Canceling."
          exit 1
        fi
      fi
      
      # Validate hostname (basic check)
      if [[ ! "$NEW_HOSTNAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
        echo "❌ Invalid hostname. Use only letters, numbers, and hyphens."
        exit 1
      fi
      
      echo ""
      echo "🔧 Setting Wine hostname to: $NEW_HOSTNAME"
      
      # Set the hostname in Wine registry
      # The hostname is stored in multiple places in Windows registry
      wine reg add "HKLM\\SYSTEM\\CurrentControlSet\\Control\\ComputerName\\ActiveComputerName" /v "ComputerName" /t REG_SZ /d "$NEW_HOSTNAME" /f 2>/dev/null
      wine reg add "HKLM\\SYSTEM\\CurrentControlSet\\Control\\ComputerName\\ComputerName" /v "ComputerName" /t REG_SZ /d "$NEW_HOSTNAME" /f 2>/dev/null
      wine reg add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters" /v "Hostname" /t REG_SZ /d "$NEW_HOSTNAME" /f 2>/dev/null
      wine reg add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters" /v "NV Hostname" /t REG_SZ /d "$NEW_HOSTNAME" /f 2>/dev/null
      
      echo "✅ Hostname set in Wine registry"
      echo ""
      
      # Verify the change
      echo "Verifying new hostname:"
      sleep 1
      NEW_CHECK=$(wine hostname 2>/dev/null || echo "unknown")
      echo "  → $NEW_CHECK"
      
      if [ "$NEW_CHECK" = "$NEW_HOSTNAME" ]; then
        echo "✅ Success! Wine hostname is now: $NEW_HOSTNAME"
      else
        echo "⚠️  Warning: Verification shows different hostname. You may need to restart Wine applications."
        echo "   Expected: $NEW_HOSTNAME"
        echo "   Got: $NEW_CHECK"
      fi
      
      echo ""
      echo "💡 Usage examples:"
      echo "  wine-set-hostname KIOSK-001"
      echo "  wine-set-hostname PRODUCTION-PC"
      echo "  wine-set-hostname"  # Interactive mode
    '')
  ];
  
  # Optional: Add database tools to system packages if needed for debugging
  # Uncomment the line below if you need database configuration tools
  # environment.systemPackages = [ ipsApp.ips dbTools.odbc-setup dbTools.db-auth-setup ];
}
