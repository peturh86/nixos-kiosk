{ lib, pkgs, ... }:
{
  kiosk.autostart.lines = lib.mkAfter [
    "${pkgs.tint2}/bin/tint2 &"
  ];
}
