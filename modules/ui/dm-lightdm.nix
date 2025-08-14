{ lib, ... }:
{
  services.xserver = {
    enable = true;

    displayManager = {
      lightdm.enable = true;                 # pick LightDM
      sddm.enable   = lib.mkForce false;     # explicitly off
      gdm.enable    = lib.mkForce false;     # (optional) off if present in your channel
      defaultSession = "none+openbox";
    };

    windowManager.openbox.enable = true;
    desktopManager.xterm.enable = false;
  };
}
