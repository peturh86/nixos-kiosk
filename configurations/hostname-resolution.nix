{ config, pkgs, ... }:

{
  # Make sure needed tools are available
  environment.systemPackages = with pkgs; [
    curl
    jq
  ];

  # Systemd service to set hostname at boot
  systemd.services.set-dynamic-hostname = {
    description = "Set hostname from Snipe-IT using serial number";
    wantedBy = [ "network.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = ''
        serial=$(cat /sys/class/dmi/id/product_serial)
        if [ -n "$serial" ]; then
          hostname=$(curl -s "https://snipeit.example/api/v1/hardware/byserial/$serial" \
            -H "Authorization: Bearer YOURTOKEN" \
            | jq -r '.name')
          if [ -n "$hostname" ] && [ "$hostname" != "null" ]; then
            echo "Setting hostname to $hostname"
            hostnamectl set-hostname "$hostname"
          else
            echo "Snipe-IT did not return a valid hostname for serial: $serial"
          fi
        else
          echo "No serial number found."
        fi
      '';
    };
  };
}
