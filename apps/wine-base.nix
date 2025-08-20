# Wine base environment for Windows applications
{ pkgs }:

let
  # Generate a hash for consistent Wine prefix naming
  wine_hash = builtins.substring 0 16 (builtins.hashString "sha256" (toString pkgs.path));
in
{
  # Core Wine setup without application-specific logic
  wineEnvironment = pkgs.writeShellScriptBin "wine-setup" ''
    # Wine environment setup - matching Ubuntu success + COM port support
    export WINEPREFIX="$HOME/.wine-app-${wine_hash}"
    export WINEARCH=win32  # 32-bit required for MDAC28
    export WINEDLLOVERRIDES="mscoree,mshtml="  # Disable prompts
    export WINEDEBUG=-all  # Clean output
    
    # Create Wine environment if it doesn't exist
    if [ ! -d "$WINEPREFIX" ]; then
        echo "Creating 32-bit Wine environment..."
        wineboot --init
        
        # Install only the components that worked in Ubuntu (minimal set)
        echo "Installing core fonts..."
        ${pkgs.winetricks}/bin/winetricks -q corefonts
        
        echo "Installing .NET Framework 4.8..."
        ${pkgs.winetricks}/bin/winetricks -q dotnet48
        
        echo "Installing MDAC28 (database components)..."
        ${pkgs.winetricks}/bin/winetricks -q mdac28
        
        # Configure COM ports for serial devices (scales, etc.)
        echo "Setting up COM port mappings..."
        wine reg add "HKLM\\Software\\Wine\\Ports" /v "COM1" /t REG_SZ /d "/dev/ttyS0" /f 2>/dev/null || true
        wine reg add "HKLM\\Software\\Wine\\Ports" /v "COM2" /t REG_SZ /d "/dev/ttyS1" /f 2>/dev/null || true
        wine reg add "HKLM\\Software\\Wine\\Ports" /v "COM3" /t REG_SZ /d "/dev/ttyUSB0" /f 2>/dev/null || true
        wine reg add "HKLM\\Software\\Wine\\Ports" /v "COM4" /t REG_SZ /d "/dev/ttyUSB1" /f 2>/dev/null || true
        wine reg add "HKLM\\Software\\Wine\\Ports" /v "COM5" /t REG_SZ /d "/dev/ttyACM0" /f 2>/dev/null || true
        wine reg add "HKLM\\Software\\Wine\\Ports" /v "COM6" /t REG_SZ /d "/dev/ttyACM1" /f 2>/dev/null || true
        
        echo "Wine environment ready"
    fi
    
    export WINEPREFIX
  '';
  
  # Wine prefix hash for consistent naming
  inherit wine_hash;
}
