{ lib, pkgs, config, ... }:

{
  # Basic KDE Kiosk lock-down: disable run command, lock screen, logout, user switching, and settings
  environment.etc."xdg/kdeglobals".text = ''
    [KDE Action Restrictions][$i]
    lock_screen=false
    logout=false
    run_command=false
    start_new_session=false
    switch_user=false
    edit_filetype=false
    open_settings=false
  '';

  # Disable common global shortcuts (Alt+Space/Alt+F2 KRunner, Alt+Tab switching)
  environment.etc."xdg/kglobalshortcutsrc".text = ''
    [krunner.desktop][$i]
    _k_friendly_name=KRunner
    Run Command=none,none,Run Command

    [kwin][$i]
    Walk Through Windows=none,none,Walk Through Windows
    Walk Through Windows (Reverse)=none,none,Walk Through Windows (Reverse)
    Walk Through Windows Alternative=none,none,Walk Through Windows Alternative
    Walk Through Windows Alternative (Reverse)=none,none,Walk Through Windows Alternative (Reverse)
    Walk Through Desktop List=none,none,Walk Through Desktop List
    Walk Through Desktop List (Reverse)=none,none,Walk Through Desktop List (Reverse)
  '';

  # Optional: hide the Plasma toolbox and lock panel editing by default
  environment.etc."xdg/plasmarc".text = ''
    [PlasmaToolTips]
    Delay=0
  '';
}
