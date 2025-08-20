# Clean IPS application with modular components
{ config, pkgs, ... }:

let
  ipsApp = import ./ips-simple.nix { inherit pkgs; };
  dbTools = import ./database-tools.nix { inherit pkgs; };
in
{
  # Install main IPS application for all users
  environment.systemPackages = [
    ipsApp.ips
  ];
  
  # Optional: Add database tools to system packages if needed for debugging
  # Uncomment the line below if you need database configuration tools
  # environment.systemPackages = [ ipsApp.ips dbTools.odbc-setup dbTools.db-auth-setup ];
}
