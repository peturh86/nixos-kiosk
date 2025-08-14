{ lib, pkgs, ... }:
{
  kiosk.autostart.lines = lib.mkAfter [
    "XDG_CONFIG_DIRS=/etc/xdg ${pkgs.tint2}/bin/tint2 &"
  ];
}
