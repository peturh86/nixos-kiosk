# Hardware and power management configuration
{ config, pkgs, lib, ... }:

{
  # Audio configuration (PipeWire - modern audio system)
  # Note: sound.enable is deprecated, PipeWire handles everything
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Printing
  services.printing.enable = true;

  # Power management - kiosk appropriate settings
  services.logind.extraConfig = ''
    # Suspend after 20 minutes of idle
    IdleAction=suspend
    IdleActionSec=20min
  '';

  # Display power management
  services.xserver.displayManager.sessionCommands = ''
    if command -v xset >/dev/null 2>&1; then
      # Disable screensaver, turn off display after 10 minutes
      xset s off -dpms
      xset dpms 0 0 600
    fi
  '';

  # Disable screen locking (kiosk mode)
  environment.etc."xdg/kscreenlockerrc".text = ''
    [Daemon]
    Autolock=false
    LockOnResume=false
  '';

  # System packages for hardware management
  environment.systemPackages = with pkgs; [
    xorg.xset
  ];
}
