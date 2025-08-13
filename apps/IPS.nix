{ pkgs, ... }:

let
  ipsPackage = pkgs.stdenv.mkDerivation {
    pname = "ips-client";
    version = "2025.08";

    # Point this to your NFS, S3, or internal web host
    src = pkgs.fetchzip {
      url = "https://nfs.example.com/IPS-Installer-2025.08.zip";
      sha256 = "sha256-of-the-zip";
    };

    buildInputs = [ pkgs.wineWowPackages.stable pkgs.unzip ];

    # Build-time "install" into a Wine prefix
    buildPhase = ''
      mkdir -p $out/wineprefix
      export WINEPREFIX=$out/wineprefix
      export WINEARCH=win32
      unzip $src -d installer
      wine installer/IPSInstaller.exe /S || true
    '';

    installPhase = ''
      mkdir -p $out/bin
      cat > $out/bin/ips <<EOF
      #!/bin/sh
      export WINEPREFIX=$out/wineprefix
      exec wine "\$WINEPREFIX/drive_c/Program Files/IPS/IPSClient.exe"
      EOF
      chmod +x $out/bin/ips
    '';
  };
in
{
  environment.systemPackages = [
    ipsPackage
  ];
}
