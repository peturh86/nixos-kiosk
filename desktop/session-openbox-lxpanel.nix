{ config, pkgs, lib, ... }:

{
  services.xserver = {
    enable = true;

    # Use LightDM (simple + widely used). Swap if you prefer another DM.
    displayManager = {
      lightdm.enable = true;
      # Use Openbox session (not a full DE).
      defaultSession = "none+openbox";
    };

    # Enable Openbox as the window manager.
    windowManager.openbox = {
      enable = true;
      # package = pkgs.openbox;  # (default)
    };

    # Optional: don't autostart xterm demo session
    desktopManager.xterm.enable = false;
  };

  # Start lxpanel for a normal-desktop feel when Openbox session starts.
  # This is a global Openbox autostart script.
  environment.etc."xdg/openbox/autostart" = {
    text = ''
      #!/bin/sh
      # Panel
      ${pkgs.lxpanel}/bin/lxpanel &
      
      # System info overlay
      start-system-overlay &
    '';
    mode = "0755";
  };
}
