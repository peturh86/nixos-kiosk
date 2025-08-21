# NixOS Kiosk Configuration

A clean, modular NixOS configuration for kiosk deployments with Wine applications.

## Structure

```
├── configuration.nix              # Main entry point
├── hardware-configuration.nix     # Auto-generated hardware config
├── nas-setup.nix                  # NAS/SMB mounting
│
├── configurations/                # Core system configuration
│   ├── system.nix                # Boot, kernel, networking, hostname
│   ├── users.nix                 # User accounts and permissions
│   ├── programs.nix              # System programs (Firefox, etc.)
│   ├── nixpkgs.nix               # Package sources and overlays
│   ├── hardware.nix              # Audio, printing, power management
│   └── kiosk-utils.nix           # Management tools and monitoring
│
├── desktop/                       # Desktop environment
│   └── session.nix               # Unified Openbox + LightDM + autostart
│
├── apps/                          # Application configurations
│   ├── browsers.nix              # Chromium configuration
│   ├── IPS-clean.nix             # Windows IPS application via Wine
│   ├── SAP.nix                   # SAP client configuration
│   ├── ssh.nix                   # SSH client setup
│   ├── git.nix                   # Git configuration
│   └── utils.nix                 # System utilities
│
├── modules/                       # Reusable NixOS modules
│   ├── ui/openbox-menu.nix       # Right-click context menu
│   └── apps/desktop-entries.nix  # .desktop files for applications
│
├── scripts/                       # Management scripts
│   └── set-hostname-from-snipeit.sh  # Hostname management via Snipe-IT API
│
└── assets/                        # Static files (icons, configs)
```

## Key Features

- **Minimal Desktop**: Openbox + LXPanel for normal desktop feel
- **Wine Integration**: 32-bit Wine environment for Windows applications
- **System Monitoring**: Conky overlay showing hostname, IP, uptime
- **Power Management**: 10min display off, 20min suspend
- **Remote Management**: Hostname setting via Snipe-IT API
- **Kiosk Security**: No screen locking, controlled application access

## Management Commands

```bash
# System monitoring
kiosk-status                    # Show system status
conky-service status           # Check system info overlay

# Wine management  
restart-wine                   # Restart Wine subsystem
wine-env                       # Start Wine environment shell

# Application shortcuts
ips                           # Launch IPS application
firefox-kiosk                 # Launch browser in kiosk mode

# Hostname management
set-hostname-from-snipeit     # Update hostname from Snipe-IT
```

## Deployment

1. **Base installation**: Standard NixOS installation
2. **Apply configuration**: `sudo nixos-rebuild switch`
3. **Set hostname**: Configure Snipe-IT API credentials and run hostname script
4. **User login**: System ready for kiosk use

## Configuration Notes

- Hostname is set declaratively in `configurations/system.nix`
- Use `set-hostname-from-snipeit` script to update hostname dynamically
- Conky overlay auto-starts with session
- Wine prefixes are created per-application
- All management tools available in system PATH

## Customization

- **Panel**: Switch between LXPanel and Tint2 in `desktop/session.nix`
- **Applications**: Add new apps in `apps/` directory
- **Monitoring**: Modify conky config in `configurations/kiosk-utils.nix`
- **Security**: Adjust lockdown settings in individual configuration files
