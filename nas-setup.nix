{ config, pkgs, ... }:
{
  # NFS client setup for accessing the Linux NAS
  services.rpcbind.enable = true;
  
  fileSystems."/mnt/nas-share" = {
    device = "10.201.10.63:/mnt/sdb_share";
    fsType = "nfs";
    options = [ "rw" "vers=4" "soft" "intr" "timeo=30" "retrans=2" ];
  };
  
  # Ensure the mount point exists
  systemd.tmpfiles.rules = [
    "d /mnt/nas-share 0755 root root -"
  ];
  
  # Make sure NFS utilities are available
  environment.systemPackages = with pkgs; [
    nfs-utils
  ];
}