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

      # Function to create kiosk configuration with custom disk
      mkKioskConfig = diskDevice: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          # Import the main configuration
          ./configuration.nix

          # Include disko for disk partitioning
          disko.nixosModules.disko

          # Define disk layout for kiosk
          {
            disko.devices = {
              disk = {
                main = {
                  device = diskDevice;
                  type = "disk";
                  content = {
                    type = "gpt";
                    partitions = {
                      # Small bios_grub partition so GRUB can embed on GPT if
                      # the machine boots in BIOS mode. Size is minimal (1M).
                      bios = {
                          size = "1M";
                          type = "EF02"; # bios_grub
                          # No content block: this partition is intentionally left
                          # unformatted (raw) so GRUB can use it for embedding.
                      };
                      ESP = {
                        size = "512M";
                        type = "EF00";
                        # Partition label (PARTLABEL) for human-friendly identification
                        partlabel = "disk-main-esp";
                        content = {
                          type = "filesystem";
                          format = "vfat";
                          # Filesystem label for /dev/disk/by-label
                          label = "disk-main-esp";
                          mountpoint = "/boot";
                        };
                      };
                      root = {
                        size = "100%";
                        partlabel = "disk-main-root";
                        content = {
                          type = "filesystem";
                          format = "ext4";
                          # Filesystem label (helpful) and mountpoint
                          label = "disk-main-root";
                          mountpoint = "/";
                        };
                      };
                    };
                  };
                };
              };
            };
          }
        ];
        specialArgs = { inherit inputs; };
      };
    in {
      # Default kiosk configuration (uses /dev/sda)
      nixosConfigurations.kiosk = mkKioskConfig "/dev/sda";
      

      # Alternative configurations for different disks
      nixosConfigurations.kiosk-sdb = mkKioskConfig "/dev/sdb";
      nixosConfigurations.kiosk-sdc = mkKioskConfig "/dev/sdc";
      nixosConfigurations.kiosk-nvme = mkKioskConfig "/dev/nvme0n1";

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
