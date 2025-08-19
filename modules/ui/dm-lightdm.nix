{ lib, ... }:
{
  services.xserver = {
    enable = true;
    windowManager.openbox.enable = true;
    desktopManager.xterm.enable = false;
  };

  services.xserver.displayManager = {
    lightdm.enable = true;                 # pick LightDM
    sddm.enable = lib.mkForce false;     # explicitly off
  };

  services.displayManager = {
    defaultSession = "none+openbox";
  };
}
