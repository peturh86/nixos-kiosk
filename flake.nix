{
  description = "NixOS Kiosk System";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Function to create kiosk configuration. The target disk is read from
      # the DISK environment variable at evaluation time (use --impure when
      # running `nixos-install` to allow this). Falls back to /dev/sda.
      mkKioskConfig = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./configuration.nix

          disko.nixosModules.disko

          (let
            diskDevice = if builtins.hasEnv "DISK" then builtins.getEnv "DISK" else "/dev/sda";
          in {
            disko.devices = {
              disk = {
                main = {
                  device = diskDevice;
                  type = "disk";
                  content = {
                    type = "gpt";
                    partitions = {
                      bios = { size = "1M"; type = "EF02"; };
                      ESP = {
                        size = "512M"; type = "EF00";
                        content = { type = "filesystem"; format = "vfat"; label = "disk-main-esp"; mountpoint = "/boot"; };
                      };
                      root = {
                        size = "100%";
                        content = { type = "filesystem"; format = "ext4"; label = "disk-main-root"; mountpoint = "/"; };
                      };
                    };
                  };
                };
              };
            };
          })
        ];
        specialArgs = { inherit inputs; };
      };
    in {
  # Single kiosk configuration; the installer should set DISK=/dev/XXX
  # before evaluating the flake (use --impure) so the device is picked
  # at install time.
  nixosConfigurations.kiosk = mkKioskConfig;

      # Expose packages for development
      packages.${system} = {
        default = self.nixosConfigurations.kiosk.config.system.build.toplevel;
      };

      # Development shell
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          nixos-generators
          disko
          jq
        ];
        shellHook = ''
          echo "NixOS Kiosk Development Environment"
          echo "Available commands:"
          echo "  nixos-rebuild build - Build the configuration"
          echo "  nixos-rebuild switch - Apply configuration to running system"
          echo "  ./scripts/manage-hostnames.sh - Manage hostname mappings"
          echo ""
          echo "Available flake configurations:"
          echo "  nixosConfigurations.kiosk (default: /dev/sda)"
          echo "  nixosConfigurations.kiosk-sdb (/dev/sdb)"
          echo "  nixosConfigurations.kiosk-sdc (/dev/sdc)"
          echo "  nixosConfigurations.kiosk-nvme (/dev/nvme0n1)"
        '';
      };
    };
}
