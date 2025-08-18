{ pkgs, ... }:
{
  services.xserver.displayManager.lightdm.extraSeatDefaults = ''
    session-setup-script=${pkgs.writeScript "lightdm-session-setup" ''
      #!/bin/sh
      echo "$(date): LightDM session setup executed" >> /tmp/lightdm-setup.log
      
      # Set background
      ${pkgs.xorg.xsetroot}/bin/xsetroot -solid '#2a2a2a'
      
      # Start tint2 in background
      XDG_CONFIG_DIRS=/etc/xdg ${pkgs.tint2}/bin/tint2 &
      
      echo "$(date): LightDM session setup completed" >> /tmp/lightdm-setup.log
    ''}
  '';
}
