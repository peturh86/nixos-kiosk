/* DEPRECATED
  This module's functionality has been moved to the installer script
  `scripts/install-kiosk.sh`. The installer writes `assets/derive-hostname.sh`
  into the repository prior to installation and copies it to
  `/etc/nixos/assets/` on the installed system. The installer also computes
  and exports `HOSTNAME` for `nixos-install` when possible.

  The configuration import was removed from `configuration.nix` so this
  file is intentionally inert. You can safely delete this file from the
  repository if you prefer; it's kept here as a migration record.
*/

{ config, lib, pkgs, ... }:

{ }
