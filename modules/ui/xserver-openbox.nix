{ config, lib, pkgs, ... }:
{
  services.xserver.enable = true;
  services.xserver.windowManager.openbox.enable = true;
  services.xserver.desktopManager.xterm.enable = false;

  # Leave DM choice to a separate module; just default the session name
  services.displayManager.defaultSession = "none+openbox";
}
