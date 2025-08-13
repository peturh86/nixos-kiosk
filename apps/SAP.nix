{ pkgs, lib, config, ... }:

let
  sapUrl = "https://sapapp-p1.postur.is/sap/bc/gui/sap/its/webgui";
  chromium = pkgs.chromium;
  launcher = pkgs.writeShellScriptBin "sap-kiosk" ''
    exec ${chromium}/bin/chromium \
      --app=${sapUrl} \
      --no-first-run \
      --disable-translate \
      --disable-infobars \
      --noerrdialogs \
      --disable-features=Translate,PasswordManagerOnboarding,AutofillServerCommunication \
      --password-store=basic \
      --simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT' \
      --window-position=0,0 \
  --start-maximized \
      "$@"
  '';

  desktopFile = pkgs.writeTextFile {
    name = "sap-kiosk.desktop";
    destination = "/share/applications/sap-kiosk.desktop";
    text = ''
      [Desktop Entry]
      Type=Application
      Name=SAP Kiosk
  Comment=SAP WebGUI
      Exec=${launcher}/bin/sap-kiosk
      Terminal=false
  Categories=Network;Office;Kiosk;
  Icon=applications-internet
  NoDisplay=false
  StartupNotify=true
      X-GNOME-Autostart-enabled=true
    '';
  };
in
{
  environment.systemPackages = [ chromium launcher desktopFile ];

  # Place a desktop shortcut for the kiosk user
  systemd.tmpfiles.rules = [
    # Ensure Desktop folder exists
    "d /home/fband/Desktop 0755 fband users - -"
    # Symlink the desktop file for easy access
    "L+ /home/fband/Desktop/SAP Kiosk.desktop - - - - ${desktopFile}/share/applications/sap-kiosk.desktop"
  ];
}
