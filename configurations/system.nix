{ config, pkgs, ... }:
{
  # Use systemd-boot (UEFI) to match the GPT + ESP layout created by the
  # flake's Disko configuration. Installing legacy GRUB onto a GPT disk
  # without a bios_grub partition will fail (embedding not possible).
  boot.loader.grub.enable = false;
  boot.loader.systemd-boot.enable = true;
  # Allow the installer to write EFI variables (needed to register the boot entry)
  boot.loader.efi.canTouchEfiVariables = true;

  # Kernel modules for serial/USB devices (scales, etc.)
  boot.kernelModules = [ "usbserial" "ftdi_sio" "pl2303" "cp210x" ];

  networking.networkmanager.enable = true;

  time.timeZone = "Atlantic/Reykjavik";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "is_IS.UTF-8";
    LC_IDENTIFICATION = "is_IS.UTF-8";
    LC_MEASUREMENT = "is_IS.UTF-8";
    LC_MONETARY = "is_IS.UTF-8";
    LC_NAME = "is_IS.UTF-8";
    LC_NUMERIC = "is_IS.UTF-8";
    LC_PAPER = "is_IS.UTF-8";
    LC_TELEPHONE = "is_IS.UTF-8";
    LC_TIME = "is_IS.UTF-8";
  };

  console.keyMap = "is-latin1";
  
  # Services for serial device support
  services.udev.enable = true;
}
