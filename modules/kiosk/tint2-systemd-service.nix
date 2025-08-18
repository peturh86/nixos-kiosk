{ config, lib, pkgs, ... }:
{
  systemd.user.services.tint2 = {
    description = "Tint2 panel";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.tint2}/bin/tint2";
      Restart = "on-failure";
      RestartSec = 3;
      Environment = [
        "XDG_CONFIG_DIRS=/etc/xdg"
        "DISPLAY=:0"
        "PATH=${lib.makeBinPath (with pkgs; [ firefox chromium wineWowPackages.stable coreutils ])}"
        "XDG_DATA_DIRS=${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}:/run/current-system/sw/share"
        "XDG_SESSION_TYPE=x11"
        "XAUTHORITY=/home/fband/.Xauthority"
      ];
    };
  };

  # Enable the service by default
  systemd.user.targets.graphical-session.wants = [ "tint2.service" ];
}
