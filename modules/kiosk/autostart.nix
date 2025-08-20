{ config, lib, pkgs, ... }:
let
  inherit (lib) mkOption types concatStringsSep;
in
{
  options.kiosk.autostart.lines = mkOption {
    type = types.listOf types.str;
    default = [];
    description = "Lines to add to /etc/xdg/openbox/autostart";
  };

  config.environment.etc."xdg/openbox/autostart" = {
    mode = "0755";
    text = concatStringsSep "\n" (
      [
        "#!/bin/sh"
        "echo \"$(date): Openbox autostart executed\" >> /tmp/openbox-autostart.log"
        "${pkgs.xorg.xsetroot}/bin/xsetroot -solid '#2a2a2a'"
        "echo \"$(date): Background set\" >> /tmp/openbox-autostart.log"
        # Start system info overlay
        "start-system-info-overlay &"
        "echo \"$(date): System info overlay started\" >> /tmp/openbox-autostart.log"
      ] ++ (map (l: l) (lib.unique config.kiosk.autostart.lines)) ++ [
        "echo \"$(date): All autostart commands processed\" >> /tmp/openbox-autostart.log"
      ]
    ) + "\n";
  };
}