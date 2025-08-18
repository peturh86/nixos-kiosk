{ lib, ... }:
{
  services.xserver = {
    enable = true;
    windowManager.openbox.enable = true;
    desktopManager.xterm.enable = false;
    displayManager = {
      lightdm.enable = true;                 # pick LightDM
      defaultSession = "none+openbox";
    };
  };

  services.displayManager = {
    sddm.enable = lib.mkForce false;     # explicitly off
  };
}
