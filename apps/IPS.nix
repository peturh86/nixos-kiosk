{ pkgs, ... }:

let
  ipsPackage = pkgs.writeShellScriptBin "ips" ''
    echo "IPS launcher - replace with actual IPS installer setup"
    echo "This is a placeholder for the IPS application"
    # When you have the actual IPS installer, uncomment and configure below:
    # export WINEPREFIX="$HOME/.wine-ips"
    # export WINEARCH=win32
    # wine "$HOME/.wine-ips/drive_c/Program Files/IPS/ips.exe"
  '';

  # Commented out until you have the actual IPS installer
  # ipsPackage = pkgs.stdenv.mkDerivation {
  #   pname = "ips-client";
  #   version = "2025.08";
  # 
  #   # Point this to your NFS, S3, or internal web host
  #   src = pkgs.fetchzip {
  #     url = "https://nfs.example.com/IPS-Installer-2025.08.zip";
  #     sha256 = "0000000000000000000000000000000000000000000000000000";  # Replace with actual hash
  #   };
  # 
  #   buildInputs = [ pkgs.wineWowPackages.stable pkgs.unzip ];
  # 
  #   # Build-time "install" into a Wine prefix
  #   buildPhase = ''
  #     mkdir -p $out/wineprefix
  #     export WINEPREFIX=$out/wineprefix
  #     export WINEARCH=win32
  #     unzip $src -d installer
  #     wine installer/IPSInstaller.exe /S || true
  #   '';
  # 
  #   installPhase = ''
  #     mkdir -p $out/bin
  #     cat > $out/bin/ips <<EOF
  #     #!/bin/sh
  #     export WINEPREFIX=$out/wineprefix
  #     exec wine "\$WINEPREFIX/drive_c/Program Files/IPS/IPSClient.exe"
  #     EOF
  #     chmod +x $out/bin/ips
  #   '';
  # };
in
{
  environment.systemPackages = [
    ipsPackage
    pkgs.wineWowPackages.stable  # Add Wine for future use
  ];
}
