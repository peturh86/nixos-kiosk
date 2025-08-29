{ config, lib, pkgs, ... }:
{
  # Minimal placeholder hardware configuration.
  # The real hardware-specific configuration (file systems, boot devices)
  # is normally created by `nixos-generate-config` during install.
  # This minimal module returns an empty configuration so flakes can be
  # evaluated when a full hardware config isn't present.

  # Example: keep /boot as default, no extra kernel modules here.
  # boot.kernelModules = lib.optionalList false [];

  # No-op; override in real installs if needed.
}
