{ lib, ... }:
{
  services.displayManager = {
    lightdm.enable = true;
    sddm.enable = lib.mkForce false;
    # gdm.enable  = lib.mkForce false; # Removed: not a valid option
  };
}
