{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # Add utility packages here as needed
    # unzip
    # curl
    # wget
  ];
}