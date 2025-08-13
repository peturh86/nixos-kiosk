{ config, pkgs, ... }:

{
  services.openssh = {
    enable = true;

    # Security settings
    settings = {
      PermitRootLogin = "no";                # Safer: no direct root login
      PasswordAuthentication = true;         # Allow passwords for now
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
    };
  };

  # Optional firewall opening
  networking.firewall.allowedTCPPorts = [ 22 ];
}
