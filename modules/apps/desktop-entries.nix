{ pkgs, ... }:
let
  sap = pkgs.makeDesktopItem {
    name = "sap-web";
    desktopName = "SAP (Web)";
    exec = "firefox --new-window https://sap.example.com";
    icon = "firefox";
    categories = [ "Network" ];
  };

  ips = pkgs.makeDesktopItem {
    name = "ips";
    desktopName = "IPS";
    exec = "env WINEPREFIX=\"$HOME/.wine-ips\" wine C:\\Program Files\\IPS\\ips.exe";
    icon = "wine";
    categories = [ "Utility" ];
  };

  intranet = pkgs.makeDesktopItem {
    name = "intranet";
    desktopName = "Intranet";
    exec = "chromium --app=https://intranet.example.com";
    icon = "chromium";
    categories = [ "Network" ];
  };
in
{
  environment.systemPackages = [ sap ips intranet ];
}
