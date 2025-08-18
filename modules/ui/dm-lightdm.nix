{ lib, ... }:
{
  services.xserver = {
    enable = true;
    windowManager.openbox.enable = true;
    desktopManager.xterm.enable = false;
  };

  services.displayManager = {
    lightdm.enable = true;                 # pick LightDM
    sddm.enable   = lib.mkForce false;     # explicitly off
    defaultSession = "none+openbox";
  };
}
