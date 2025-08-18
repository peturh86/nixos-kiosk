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
      ];
    };
  };

  # Enable the service by default
  systemd.user.targets.graphical-session.wants = [ "tint2.service" ];
}
