{ pkgs, ... }:
{
  services.xserver.displayManager.sessionCommands = ''
    # Set background
    ${pkgs.xorg.xsetroot}/bin/xsetroot -solid '#2a2a2a'
    
    # Start tint2
    XDG_CONFIG_DIRS=/etc/xdg ${pkgs.tint2}/bin/tint2 &
    
    # Log for debugging
    echo "$(date): X session commands executed" >> /tmp/x-session.log
  '';
}
