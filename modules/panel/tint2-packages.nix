{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    openbox
    tint2
    xorg.xsetroot
    xorg.xprop
    wmctrl
    xdotool
  ];
}
