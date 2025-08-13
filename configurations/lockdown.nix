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

  # Enforce kiosk settings at session start in case user config overrides exist
  systemd.user.services.kde-kiosk-enforce = {
    description = "Enforce KDE Kiosk settings";
    wantedBy = [ "plasma-workspace.target" "default.target" ];
    after = [ "plasma-workspace.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "enforce-kde-kiosk" ''
        set -euo pipefail
        cfgdir="$XDG_CONFIG_HOME"
        [ -z "$cfgdir" ] && cfgdir="$HOME/.config"

        # Disable KRunner and Alt-Tab shortcuts for the user
        ${pkgs.kdePackages.kconfig}/bin/kwriteconfig5 --file kglobalshortcutsrc --group krunner.desktop --key "Run Command" "none,none,Run Command"
        ${pkgs.kdePackages.kconfig}/bin/kwriteconfig5 --file kglobalshortcutsrc --group kwin --key "Walk Through Windows" "none,none,Walk Through Windows"
        ${pkgs.kdePackages.kconfig}/bin/kwriteconfig5 --file kglobalshortcutsrc --group kwin --key "Walk Through Windows (Reverse)" "none,none,Walk Through Windows (Reverse)"

        # Action restrictions
        ${pkgs.kdePackages.kconfig}/bin/kwriteconfig5 --file kdeglobals --group "KDE Action Restrictions" --key lock_screen false
        ${pkgs.kdePackages.kconfig}/bin/kwriteconfig5 --file kdeglobals --group "KDE Action Restrictions" --key logout false
        ${pkgs.kdePackages.kconfig}/bin/kwriteconfig5 --file kdeglobals --group "KDE Action Restrictions" --key run_command false
        ${pkgs.kdePackages.kconfig}/bin/kwriteconfig5 --file kdeglobals --group "KDE Action Restrictions" --key start_new_session false
        ${pkgs.kdePackages.kconfig}/bin/kwriteconfig5 --file kdeglobals --group "KDE Action Restrictions" --key switch_user false
      '';
    };
  };
}
