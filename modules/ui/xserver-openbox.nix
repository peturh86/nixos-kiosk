{ config, lib, pkgs, ... }:
{
  services.xserver.enable = true;
  services.xserver.windowManager.openbox.enable = true;

  # Leave DM choice to a separate module; just default the session name
  services.xserver.displayManager.defaultSession = "none+openbox";

  services.xserver.desktopManager.xterm.enable = false;
}
