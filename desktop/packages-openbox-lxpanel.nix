{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Core
    openbox
    lxpanel

    # Optional helpers (handy during setup)
    obconf          # Openbox config GUI
    xorg.xprop
    wmctrl
    xdotool
  ];
}
