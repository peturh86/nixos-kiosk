{ pkgs, ... }:
{
  # Desktop entries are now defined in tint2-config.nix
  # This ensures they're available system-wide while being referenced correctly in tint2
  environment.systemPackages = [ ];
}
