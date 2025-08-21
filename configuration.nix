{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./nas-setup.nix
    ./apps.nix

    # Core system configuration
    ./configurations/system.nix
    ./configurations/users.nix
    ./configurations/programs.nix
    ./configurations/nixpkgs.nix
    ./configurations/hardware.nix
    ./configurations/kiosk-utils.nix

    # Desktop environment (unified)
    ./desktop/session.nix

    # Keep only essential modules
    ./modules/ui/openbox-menu.nix
    ./modules/apps/desktop-entries.nix
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

}
