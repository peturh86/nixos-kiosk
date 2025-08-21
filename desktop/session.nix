# Unified Openbox session configuration for kiosk
# Consolidates display manager, window manager, and autostart
{ config, pkgs, lib, ... }:

{
  services.xserver = {
    enable = true;
    
    # Display manager
    displayManager = {
      lightdm.enable = true;
      defaultSession = "none+openbox";
    };

    # Window manager
    windowManager.openbox = {
      enable = true;
    };

    # Disable default xterm session
    desktopManager.xterm.enable = false;
  };

  # Unified autostart script for Openbox
  environment.etc."xdg/openbox/autostart" = {
    text = ''
      #!/bin/sh
      
      # Logging for debugging
      exec > /tmp/openbox-autostart.log 2>&1
      echo "$(date): Openbox autostart beginning"
      
      # Set background
      ${pkgs.xorg.xsetroot}/bin/xsetroot -solid '#2a2a2a'
      echo "$(date): Background set"
      
      # Start panel (choose one)
      ${pkgs.lxpanel}/bin/lxpanel &
      echo "$(date): Panel started"
      
      # Start system info overlay (conky)
      start-system-overlay &
      echo "$(date): System info overlay started"
      
      # Optional: Start tint2 instead of lxpanel
      # XDG_CONFIG_DIRS=/etc/xdg ${pkgs.tint2}/bin/tint2 &
      # echo "$(date): Tint2 started"
      
      echo "$(date): Openbox autostart completed"
    '';
    mode = "0755";
  };
}
