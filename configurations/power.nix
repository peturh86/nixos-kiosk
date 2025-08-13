{ config, pkgs, lib, ... }:

{
  # System-wide idle suspend after 20 minutes (systemd-logind)
  services.logind.settings = {
    # Suspend the system after 20 minutes of user idleness
    IdleAction = "suspend";
    IdleActionSec = "20min";
  };

  # X11: turn off the display after 10 minutes and disable screensaver/DPMS
  # For Wayland/Plasma sessions, KWin/PowerDevil manages display power. The suspend above still applies.
  services.xserver.displayManager.sessionCommands = ''
    if command -v xset >/dev/null 2>&1; then
      # disable the X screensaver and set DPMS: standby/suspend/off = 0/0/600 seconds
      xset s off -dpms
      xset dpms 0 0 600
    fi
  '';

  # Ensure xset is available
  environment.systemPackages = [ pkgs.xorg.xset ];

  # Disable KDE screen locking so no lock/login screen appears on idle or resume
  # Applied system-wide via /etc/xdg defaults; users could still override.
  environment.etc."xdg/kscreenlockerrc".text = ''
    [Daemon]
    Autolock=false
    LockOnResume=false
  '';

  # Provide KDE PowerDevil defaults to turn off screen at 10min and suspend at 20min.
  # Note: Plasma may migrate/override these into user ~/.config on first login.
  environment.etc."xdg/powermanagementprofilesrc".text = ''
    [AC]
    icon=preferences-system-power
    name=On AC Power

    [AC][DimDisplay]
    dimDisplay=true
    idleTime=600000

    [AC][DPMSControl]
    DPMSControl=true
    idleTime=600000

    [AC][SuspendSession]
    idleTime=1200000
    suspendThenHibernate=false
    suspendType=1

    [Battery]
    icon=preferences-system-power
    name=On Battery

    [Battery][DimDisplay]
    dimDisplay=true
    idleTime=600000

    [Battery][DPMSControl]
    DPMSControl=true
    idleTime=600000

    [Battery][SuspendSession]
    idleTime=1200000
    suspendThenHibernate=false
    suspendType=1
  '';
}
