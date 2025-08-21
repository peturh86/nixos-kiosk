{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    chromium
    # firefox is enabled via programs.firefox.enable in configurations/programs.nix
  ];
}
