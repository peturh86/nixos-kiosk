{ lib, pkgs, ... }:
{
  kiosk.autostart.lines = lib.mkAfter [
    "echo \"$(date): About to start tint2\" >> /tmp/openbox-autostart.log"
    "XDG_CONFIG_DIRS=/etc/xdg ${pkgs.tint2}/bin/tint2 >> /tmp/tint2.log 2>&1 &"
    "echo \"$(date): tint2 command executed\" >> /tmp/openbox-autostart.log"
  ];
}
