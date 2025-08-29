# NixOS Kiosk System

A NixOS-based kiosk system designed for automated deployment with hardware-based hostname derivation and application lockdown.

## Overview

This NixOS configuration creates a kiosk system with:
- **Openbox** window manager for lightweight desktop environment
- **LightDM** display manager with auto-login
- **Chromium** and **Firefox** browsers
- Custom applications (IPS, SAP) via Wine
- Hardware-based hostname assignment using motherboard serial numbers
- Automated disk partitioning with Disko
- Network management with NetworkManager

## System Requirements

### Hardware
- x86_64 compatible system
- At least 4GB RAM (8GB recommended)
- 20GB+ storage
- Motherboard with accessible serial number (for hostname derivation)

### Software
- NixOS 25.05 or later
- `jq` command-line JSON processor
- USB boot media for installation

## Quick Deployment

### 1. Prepare Installation Media

Download the latest NixOS ISO and create a bootable USB drive:

```bash
# On Linux/macOS
sudo dd if=nixos.iso of=/dev/sdX bs=4M status=progress

# On Windows (using Rufus or similar)
# Use Rufus to create bootable USB from nixos.iso
```

### 2. Boot and Clone Repository

Boot from the USB drive and clone this repository:

```bash
# Set up networking (if needed)
sudo systemctl start wpa_supplicant
wpa_cli -i wlan0 add_network
wpa_cli -i wlan0 set_network 0 ssid "YOUR_WIFI_SSID"
wpa_cli -i wlan0 set_network 0 psk "YOUR_WIFI_PASSWORD"
wpa_cli -i wlan0 enable_network 0

# Clone the repository
git clone https://github.com/peturh86/nixos-kiosk.git
cd nixos-kiosk
```

### 3. Run Installation

Execute the installation script. If `DISK` is not provided the script will prompt you to select a device:

```bash
./scripts/install-kiosk.sh
```

The script will:
- Detect the target disk automatically (largest available)
- Read motherboard serial number for hostname derivation
- Partition and format the disk using Disko (via flake configuration)
- Install NixOS with the kiosk configuration (via flake)
- Reboot into the installed system

**Note:** The installation uses Nix flakes for reproducible builds. The appropriate disk configuration is automatically selected based on the detected disk device.

## Hostname Management

### Automatic Hostname Assignment

The system automatically derives hostnames from motherboard serial numbers:

1. **Primary Source**: `/sys/class/dmi/id/board_serial`
2. **Fallback Source**: `/sys/class/dmi/id/product_serial`
3. **Naming Pattern**: `wh-<last4chars>` (e.g., `wh-1234`)

### Custom Hostname Mapping

For controlled hostname assignment, edit `assets/serial-hostname-map.json`:

```json
{
  "ABCDEF123456": "kiosk-01",
  "XYZ987654321": "kiosk-02",
  "1234ABCD5678": "kiosk-03"
}
```

**Format**: `"SERIAL_NUMBER": "DESIRED_HOSTNAME"`

### Managing Hostname Mappings

Use the hostname management script for easy mapping management:

```bash
# List all current mappings
./scripts/manage-hostnames.sh list

# Add a new mapping
./scripts/manage-hostnames.sh add ABC123 kiosk-01

# Remove a mapping
./scripts/manage-hostnames.sh remove ABC123

# Get hostname for a specific serial
./scripts/manage-hostnames.sh get ABC123

# Test hostname derivation
./scripts/manage-hostnames.sh test ABC123
```

### Manual Hostname Override

Override automatic hostname detection:

```bash
HOSTNAME=my-custom-hostname ./scripts/install-kiosk.sh
```

## Configuration Options

### Environment Variables

| Variable    | Description              | Default                         |
| ----------- | ------------------------ | ------------------------------- |
| `DISK`      | Target installation disk | Auto-detected (largest disk)    |
| `HOSTNAME`  | System hostname          | Derived from motherboard serial |
| `ROOT_HASH` | Root password hash       | No password                     |
| `USER_HASH` | User password hash       | No password                     |

### Disk Configuration

The flake provides multiple disk configurations for different hardware:

| Disk Device    | Flake Configuration | Description         |
| -------------- | ------------------- | ------------------- |
| `/dev/sda`     | `kiosk` (default)   | Primary SATA disk   |
| `/dev/sdb`     | `kiosk-sdb`         | Secondary SATA disk |
| `/dev/sdc`     | `kiosk-sdc`         | Tertiary SATA disk  |
| `/dev/nvme0n1` | `kiosk-nvme`        | NVMe SSD            |

**Manual disk specification:**
```bash
# Install to specific disk
DISK=/dev/sdb ./scripts/install-kiosk.sh

# The script will automatically select the appropriate flake configuration
```

**Custom disk configuration:**
If your disk isn't pre-configured, you can:
1. Add a new configuration to `flake.nix`
2. Or modify the existing disk layout for your needs

### Setting Passwords

Generate password hashes:

```bash
# Generate root password hash
mkpasswd -m sha-512

# Generate user password hash
mkpasswd -m sha-512
```

Set during installation:

```bash
ROOT_HASH='$6$...' USER_HASH='$6$...' ./scripts/install-kiosk.sh
```

## System Configuration

### Desktop Environment
- **Window Manager**: Openbox (lightweight, configurable)
- **Panel**: Tint2 (taskbar and system tray)
- **Display Manager**: LightDM with auto-login
- **Auto-login User**: `fband`

### Applications
- **Browsers**: Chromium, Firefox
- **Custom Apps**: IPS, SAP (via Wine)
- **Utilities**: SSH client, Git, various system tools

### Localization
- **Timezone**: Atlantic/Reykjavik (Iceland)
- **Locale**: Icelandic (is_IS.UTF-8)
- **Keyboard Layout**: Icelandic

### Network
- **Manager**: NetworkManager (automatically manages wired and wireless connections)
- **Wired**: Automatic DHCP configuration (plug-and-play)
- **WiFi**: Supported with WPA supplicant
- **Firewall**: SSH (port 22) allowed by default
- **User Permissions**: Kiosk user has NetworkManager access

## Post-Installation Setup

### Network Configuration

The system uses NetworkManager for network configuration. DHCP is automatically configured for wired connections.

#### DHCP Wired Networking

**Automatic DHCP (Default):**
The system automatically obtains an IP address via DHCP on wired connections. No additional configuration is needed.

**Check wired connection status:**
```bash
# Show all network devices and their status
nmcli device status

# Show detailed connection information
nmcli connection show

# Show IP address information
ip addr show
```

**Manual wired connection setup (if needed):**
```bash
# List available Ethernet devices
nmcli device

# Create a new wired connection (if auto-detection fails)
sudo nmcli connection add type ethernet con-name "Wired Connection" ifname eth0

# Bring up the connection
sudo nmcli connection up "Wired Connection"

# Set connection to auto-connect
sudo nmcli connection modify "Wired Connection" connection.autoconnect yes
```

**Static IP configuration (optional):**
```bash
# Create a static IP connection
sudo nmcli connection add type ethernet con-name "Static Wired" ifname eth0 \
  ipv4.addresses "192.168.1.100/24" \
  ipv4.gateway "192.168.1.1" \
  ipv4.dns "8.8.8.8,8.8.4.4" \
  ipv4.method manual

# Activate the static connection
sudo nmcli connection up "Static Wired"
```

#### WiFi Configuration

```bash
# Connect to WiFi
nmcli device wifi connect YOUR_SSID password YOUR_PASSWORD

# Check connection status
nmcli connection show
```

**WiFi troubleshooting:**
```bash
# List available WiFi networks
nmcli device wifi list

# Show WiFi connection details
nmcli device wifi show

# Restart WiFi
sudo nmcli radio wifi off && sudo nmcli radio wifi on
```

### User Management

The system creates a kiosk user `fband` with auto-login. To add additional users:

```bash
# As root or with sudo
useradd -m newuser
passwd newuser
```

### Application Updates

Update the system and applications:

```bash
# Update NixOS channels
sudo nix-channel --update

# Rebuild and switch to new configuration
sudo nixos-rebuild switch

# Update specific packages
sudo nix-env -u
```

## Troubleshooting

### Installation Issues

**No disk detected:**
```bash
# Check available disks
lsblk -d

# Specify disk manually
DISK=/dev/sda ./scripts/install-kiosk.sh
```

**No motherboard serial found:**
```bash
# Check serial availability
cat /sys/class/dmi/id/board_serial
cat /sys/class/dmi/id/product_serial

# Set hostname manually
HOSTNAME=kiosk-01 ./scripts/install-kiosk.sh
```

**jq command not found:**
```bash
# Install jq in the live environment
nix-env -i jq
```

### Boot Issues

**System doesn't boot after installation:**
- Check boot order in BIOS/UEFI
- Verify disk partitioning: `fdisk -l /dev/sda`
- Reinstall bootloader: `sudo nixos-rebuild boot`

**Network not working:**
```bash
# Restart NetworkManager
sudo systemctl restart NetworkManager

# Check network status
ip addr show
nmcli device status

# Check if DHCP is working
journalctl -u NetworkManager -n 20

# Test network connectivity
ping -c 3 8.8.8.8

# Check DNS resolution
nslookup google.com
```

**Wired connection issues:**
```bash
# Check Ethernet link status
ethtool eth0

# Check cable connection
nmcli device show eth0

# Force DHCP renewal
sudo dhclient -r eth0
sudo dhclient eth0
```

**WiFi connection issues:**
```bash
# Check WiFi device status
nmcli radio wifi

# Rescan for networks
nmcli device wifi rescan

# Check signal strength
nmcli device wifi list
```

### Application Issues

**Wine applications not starting:**
```bash
# Check Wine installation
wine --version

# Reinstall Wine applications
sudo nixos-rebuild switch
```

**Browser issues:**
```bash
# Reset browser configuration
rm -rf ~/.config/chromium/*
rm -rf ~/.mozilla/firefox/*.default
```

## Development

### Local Testing

Test configuration changes without full installation:

```bash
# Build configuration
sudo nixos-rebuild build

# Build specific flake configuration
nix build .#nixosConfigurations.kiosk.config.system.build.toplevel

# Test in VM (requires VirtualBox)
sudo nixos-rebuild build-vm

# Switch to new configuration
sudo nixos-rebuild switch
```

### Flake Development

The project uses Nix flakes for reproducible builds:

```bash
# Enter development shell
nix develop

# List available configurations
nix flake show

# Build specific disk configuration
nix build .#nixosConfigurations.kiosk-sdb

# Update flake inputs
nix flake update
```

### Modifying Configuration

Edit NixOS configuration files:

- `configuration.nix` - Main system configuration
- `configurations/` - Modular configuration files
- `apps/` - Application-specific configurations
- `modules/` - Custom NixOS modules

### Adding Applications

1. Create new app configuration in `apps/`
2. Import in `apps.nix`
3. Rebuild: `sudo nixos-rebuild switch`

## File Structure

```
├── flake.nix                 # Nix flake definition with disk configurations
├── configuration.nix          # Main NixOS configuration
├── apps.nix                   # Application imports
├── nas-setup.nix             # NAS configuration
├── configurations/           # System configurations
│   ├── system.nix           # Boot, networking, localization
│   ├── desktop.nix          # X11, Openbox, auto-login
│   ├── users.nix            # User accounts
│   └── ...
├── apps/                     # Application configurations
│   ├── browsers.nix         # Chromium, Firefox
│   ├── IPS.nix             # IPS application
│   └── ...
├── modules/                  # Custom NixOS modules
│   ├── ui/                  # Desktop environment
│   ├── panel/               # Tint2 configuration
│   ├── hostname/            # Dynamic hostname management
│   └── ...
├── desktop/                  # Desktop session files
├── assets/                   # Static assets
│   └── serial-hostname-map.json  # Hostname mappings
└── scripts/                  # Installation and utility scripts
    ├── install-kiosk.sh     # Automated installation
    └── manage-hostnames.sh  # Hostname mapping management
```

## Security Considerations

- **Auto-login**: Enabled for kiosk functionality
- **No root password**: Set during installation if needed
- **Firewall**: Configured via NixOS defaults
- **User permissions**: Kiosk user has limited sudo access

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test locally
4. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
- Check the troubleshooting section
- Review NixOS documentation: https://nixos.org/manual/nixos/stable/
- Open an issue on GitHub
