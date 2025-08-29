{ config, lib, pkgs, ... }:

{
  options = {
    services.runtimeHostname = {
      enable = lib.mkEnableOption "Set hostname at first boot using on-disk derive-hostname script";
    };
  };

  config = lib.mkIf config.services.runtimeHostname.enable {
    # Ensure runtime tools needed by the on-disk script are available
    environment.systemPackages = [ pkgs.jq pkgs.bash ];

    # A simple oneshot service that runs the installer-provided
    # /etc/nixos/assets/derive-hostname.sh script and applies its output
    # with hostnamectl. This performs hostname detection entirely at
    # runtime on the installed machine (no compile-time assumptions).
    systemd.services.set-dynamic-hostname = {
      description = "Set hostname on first boot from DMI serial and mapping";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''${pkgs.bash}/bin/bash -c 'if [ -x /etc/nixos/assets/derive-hostname.sh ]; then /etc/nixos/assets/derive-hostname.sh | xargs -r -I{} ${pkgs.systemd}/bin/hostnamectl set-hostname {}; else echo "derive-hostname script missing"; fi' '';
        RemainAfterExit = true;
      };
    };
  };
}
