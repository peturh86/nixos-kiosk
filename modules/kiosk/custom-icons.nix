{ pkgs, lib, ... }:
let
  # Check if custom icon files exist
  iconExists = name: builtins.pathExists (../../../assets/icons + "/${name}");
  
  # Create desktop items with custom icons if they exist
  webIcon = if iconExists "web.png" then "/etc/nixos/custom-icons/web.png" else "firefox";
  ipsIcon = if iconExists "ips.png" then "/etc/nixos/custom-icons/ips.png" else "wine";
  sapIcon = if iconExists "sap.png" then "/etc/nixos/custom-icons/sap.png" else "chromium";
in
{
  # Only install custom icons if they exist
  environment.etc = lib.mkMerge [
    (lib.mkIf (iconExists "web.png") {
      "nixos/custom-icons/web.png".source = ../../../assets/icons/web.png;
    })
    (lib.mkIf (iconExists "ips.png") {
      "nixos/custom-icons/ips.png".source = ../../../assets/icons/ips.png;
    })
    (lib.mkIf (iconExists "sap.png") {
      "nixos/custom-icons/sap.png".source = ../../../assets/icons/sap.png;
    })
  ];

  # You can use this module by importing it and accessing the icon paths
  # This is a template for when you want to add custom icons
}
