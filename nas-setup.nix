{ config, pkgs, ... }:
{
  fileSystems."/mnt/ips" = {
    device = "nfs-server.example.com:/exports/ips";
    fsType = "nfs";
    options = [ "rw" "vers=4" ];
  };
}