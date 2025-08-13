{ config, pkgs, ... }:
{
  users.users.fband = {
    isNormalUser = true;
    description = "fband";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      kdePackages.kate
    ];
  };
}
