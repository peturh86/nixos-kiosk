{ lib, pkgs, ... }:
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
        "${pkgs.xorg.xsetroot}/bin/xsetroot -solid '#2a2a2a'"
      ] ++ (map (l: l) (lib.unique config.kiosk.autostart.lines))
    ) + "\n";
  };
}