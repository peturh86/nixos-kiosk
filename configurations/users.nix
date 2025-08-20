{ config, pkgs, ... }:
{
  users.users.fband = {
    isNormalUser = true;
    description = "fband";
    extraGroups = [ "networkmanager" "wheel" "dialout" "tty" "uucp" ];
    packages = with pkgs; [
      kdePackages.kate
    ];
  };
}
