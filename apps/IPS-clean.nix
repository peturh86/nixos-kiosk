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
  ];
  
  # Optional: Add database tools to system packages if needed for debugging
  # Uncomment the line below if you need database configuration tools
  # environment.systemPackages = [ ipsApp.ips dbTools.odbc-setup dbTools.db-auth-setup ];
}
