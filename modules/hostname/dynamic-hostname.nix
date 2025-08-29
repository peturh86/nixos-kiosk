# Dynamic hostname assignment based on motherboard serial
{ config, lib, pkgs, ... }:

let
  # Script to derive hostname from motherboard serial
  hostnameScript = pkgs.writeShellScript "derive-hostname" ''
    #!/usr/bin/env bash
    set -euo pipefail

    # Try to get motherboard serial
    serial=""
    if [[ -r /sys/class/dmi/id/board_serial ]]; then
      serial=$(cat /sys/class/dmi/id/board_serial | tr -d '[:space:]')
    elif [[ -r /sys/class/dmi/id/product_serial ]]; then
      serial=$(cat /sys/class/dmi/id/product_serial | tr -d '[:space:]')
    fi

    if [[ -z "$serial" ]]; then
      echo "fband"  # Fallback hostname
      exit 0
    fi

    # Check for JSON mapping file
    map_file="/etc/nixos/assets/serial-hostname-map.json"
    if [[ -f "$map_file" ]] && command -v ${pkgs.jq}/bin/jq >/dev/null 2>&1; then
      mapped_hostname=$(${pkgs.jq}/bin/jq -r --arg s "$serial" '.[$s] // empty' "$map_file")
      if [[ -n "$mapped_hostname" ]]; then
        echo "$mapped_hostname"
        exit 0
      fi
    fi

    # Fallback: generate hostname from last 4 chars of serial
    suffix="''${serial: -4}"
    echo "wh-''${suffix}"
  '';
in
{
  options = {
    services.dynamicHostname = {
      enable = lib.mkEnableOption "dynamic hostname assignment based on motherboard serial";
      mapFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to JSON file mapping serial numbers to hostnames";
      };
    };
  };

  config = lib.mkIf config.services.dynamicHostname.enable {
    # Copy the mapping file to the system if provided
    environment.etc = lib.mkIf (config.services.dynamicHostname.mapFile != null) {
      "serial-hostname-map.json".source = config.services.dynamicHostname.mapFile;
    };

    # Set hostname using the derivation script
    networking.hostName = lib.mkForce (builtins.readFile (pkgs.runCommand "hostname" {} ''
      ${hostnameScript} > $out
    ''));

    # Alternative: Use systemd service to set hostname at boot
    systemd.services.set-dynamic-hostname = {
      description = "Set dynamic hostname based on motherboard serial";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${hostnameScript}";
        RemainAfterExit = true;
      };
      script = ''
        HOSTNAME=$(${hostnameScript})
        hostnamectl set-hostname "$HOSTNAME"
        echo "Set hostname to: $HOSTNAME"
      '';
    };
  };
}
