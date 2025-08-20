# Wine base environment for Windows applications
{ pkgs }:

let
  # Generate a hash for consistent Wine prefix naming
  wine_hash = builtins.substring 0 16 (builtins.hashString "sha256" (toString pkgs.path));
in
{
  # Core Wine setup without application-specific logic
  wineEnvironment = pkgs.writeShellScriptBin "wine-setup" ''
    # Wine environment setup - matching Ubuntu success
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
        
        echo "Wine environment ready"
    fi
    
    export WINEPREFIX
  '';
  
  # Wine prefix hash for consistent naming
  inherit wine_hash;
}
