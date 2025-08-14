{ config, pkgs, ... }:
{
  services.xserver.enable = true;
  #services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  services.xserver.xkb = {
    layout = "is";
    variant = "";
  };

  # Autologin
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "fband";
}
