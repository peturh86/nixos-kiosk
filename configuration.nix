{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./nas-setup.nix
    ./apps.nix

    ./configurations/system.nix
    ./configurations/users.nix
    ./configurations/programs.nix
    ./configurations/nixpkgs.nix
    ./configurations/kiosk-utils.nix

    ./modules/ui/xserver-openbox.nix
    ./modules/ui/dm-lightdm.nix
    ./modules/ui/openbox-menu.nix
    ./modules/panel/tint2-packages.nix
    ./modules/panel/tint2-config.nix
    ./modules/apps/desktop-entries.nix
    ./modules/kiosk/autostart.nix
    ./modules/kiosk/autostart-add-tint2.nix
  ./modules/kiosk/x-session-commands.nix
  ./modules/hostname/runtime-hostname.nix
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

  # Hostname is handled by the installer; installed system contains
  # /etc/nixos/assets/serial-hostname-map.json and derive-hostname.sh
  # which will set the hostname at first boot if needed.
  services.runtimeHostname.enable = true;

}
