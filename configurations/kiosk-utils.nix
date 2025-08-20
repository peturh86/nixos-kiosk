# Kiosk management utilities
# These are general system management tools for the kiosk environment
{ config, pkgs, ... }:

{
  environment.systemPackages = [
    # Hostname management for Wine applications
    (pkgs.writeShellScriptBin "set-wine-hostname" ''
      #!/bin/bash
      
      echo "🖥️  Kiosk Wine Hostname Manager"
      echo "This tool sets the hostname that Wine applications will see"
      echo ""
      
      # Find any Wine prefix (not just IPS)
      WINE_PREFIX=""
      for prefix in $HOME/.wine-* $HOME/.wine; do
        if [ -d "$prefix" ]; then
          WINE_PREFIX="$prefix"
          break
        fi
      done
      
      if [ -z "$WINE_PREFIX" ]; then
        echo "❌ No Wine prefix found. Run a Wine application first to create one."
        echo "   Try: wine notepad"
        exit 1
      fi
      
      export WINEPREFIX="$WINE_PREFIX"
      export PATH="${pkgs.wineWowPackages.stable}/bin:$PATH"
      
      echo "Wine prefix: $WINEPREFIX"
      echo ""
      
      # Show current hostname
      echo "Current hostname in Wine:"
      CURRENT_HOSTNAME=$(wine hostname 2>/dev/null || echo "unknown")
      echo "  → $CURRENT_HOSTNAME"
      echo ""
      
      # Get new hostname from user
      if [ -n "$1" ]; then
        NEW_HOSTNAME="$1"
        echo "Setting hostname to: $NEW_HOSTNAME"
      else
        echo "Enter new hostname for Wine applications:"
        echo "(This will be visible to IPS, SAP, and other Windows apps)"
        echo ""
        read -p "Hostname: " NEW_HOSTNAME
        
        if [ -z "$NEW_HOSTNAME" ]; then
          echo "❌ No hostname provided. Canceling."
          exit 1
        fi
      fi
      
      # Validate hostname (basic check)
      if [[ ! "$NEW_HOSTNAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
        echo "❌ Invalid hostname. Use only letters, numbers, and hyphens."
        exit 1
      fi
      
      echo ""
      echo "🔧 Setting Wine hostname to: $NEW_HOSTNAME"
      
      # Set the hostname in Wine registry
      # The hostname is stored in multiple places in Windows registry
      wine reg add "HKLM\\SYSTEM\\CurrentControlSet\\Control\\ComputerName\\ActiveComputerName" /v "ComputerName" /t REG_SZ /d "$NEW_HOSTNAME" /f 2>/dev/null
      wine reg add "HKLM\\SYSTEM\\CurrentControlSet\\Control\\ComputerName\\ComputerName" /v "ComputerName" /t REG_SZ /d "$NEW_HOSTNAME" /f 2>/dev/null
      wine reg add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters" /v "Hostname" /t REG_SZ /d "$NEW_HOSTNAME" /f 2>/dev/null
      wine reg add "HKLM\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters" /v "NV Hostname" /t REG_SZ /d "$NEW_HOSTNAME" /f 2>/dev/null
      
      echo "✅ Hostname set in Wine registry"
      echo ""
      
      # Verify the change
      echo "Verifying new hostname:"
      sleep 1
      NEW_CHECK=$(wine hostname 2>/dev/null || echo "unknown")
      echo "  → $NEW_CHECK"
      
      if [ "$NEW_CHECK" = "$NEW_HOSTNAME" ]; then
        echo "✅ Success! Wine hostname is now: $NEW_HOSTNAME"
        echo ""
        echo "This hostname will be visible to:"
        echo "  • IPS application"
        echo "  • SAP client"
        echo "  • Any other Wine applications"
      else
        echo "⚠️  Warning: Verification shows different hostname."
        echo "   Expected: $NEW_HOSTNAME"
        echo "   Got: $NEW_CHECK"
        echo "   You may need to restart Wine applications."
      fi
      
      echo ""
      echo "💡 Next steps:"
      echo "  • For automatic hostname from hardware: set-hostname-from-serial"
      echo "  • For database-based hostname: set-hostname-from-db"
    '')

    # Future: Hostname from hardware serial number
    (pkgs.writeShellScriptBin "set-hostname-from-serial" ''
      #!/bin/bash
      echo "🔧 Automatic hostname from hardware serial"
      echo ""
      
      # Get system serial number
      SERIAL=$(cat /sys/class/dmi/id/product_serial 2>/dev/null || echo "unknown")
      echo "System serial: $SERIAL"
      
      if [ "$SERIAL" = "unknown" ]; then
        echo "❌ Could not read system serial number"
        echo "   Fallback: using MAC address"
        SERIAL=$(ip link show | grep -o 'link/ether [^[:space:]]*' | head -1 | cut -d' ' -f2 | tr -d ':' | tr '[:lower:]' '[:upper:]')
      fi
      
      # Generate hostname from serial
      HOSTNAME="KIOSK-$SERIAL"
      echo "Generated hostname: $HOSTNAME"
      echo ""
      
      # Call the main hostname setter
      exec set-wine-hostname "$HOSTNAME"
    '')

    # Future: Hostname from database lookup
    (pkgs.writeShellScriptBin "set-hostname-from-db" ''
      #!/bin/bash
      echo "🗄️  Database hostname lookup"
      echo ""
      echo "❌ Not implemented yet"
      echo ""
      echo "This will:"
      echo "  1. Get system serial number"
      echo "  2. Query database for hostname mapping"
      echo "  3. Set Wine hostname automatically"
      echo ""
      echo "For now, use: set-wine-hostname HOSTNAME"
    '')

    # Kiosk status checker
    (pkgs.writeShellScriptBin "kiosk-status" ''
      #!/bin/bash
      echo "🖥️  Kiosk System Status"
      echo "======================="
      echo ""
      
      # System info
      echo "System:"
      echo "  NixOS: $(nixos-version)"
      echo "  Hostname: $(hostname)"
      echo "  Uptime: $(uptime -p)"
      echo ""
      
      # Wine info
      echo "Wine Environment:"
      if command -v wine &> /dev/null; then
        WINE_VERSION=$(wine --version 2>/dev/null || echo "unknown")
        echo "  Wine version: $WINE_VERSION"
        
        # Find Wine prefixes
        WINE_PREFIXES=$(find $HOME -maxdepth 1 -name ".wine*" -type d 2>/dev/null)
        if [ -n "$WINE_PREFIXES" ]; then
          echo "  Wine prefixes:"
          for prefix in $WINE_PREFIXES; do
            echo "    → $(basename $prefix)"
          done
          
          # Check Wine hostname in first prefix
          FIRST_PREFIX=$(echo "$WINE_PREFIXES" | head -1)
          export WINEPREFIX="$FIRST_PREFIX"
          WINE_HOSTNAME=$(wine hostname 2>/dev/null || echo "unknown")
          echo "  Wine hostname: $WINE_HOSTNAME"
        else
          echo "  No Wine prefixes found"
        fi
      else
        echo "  Wine: not available"
      fi
      echo ""
      
      # Application status
      echo "Applications:"
      if command -v ips &> /dev/null; then
        echo "  ✅ IPS launcher available"
      else
        echo "  ❌ IPS launcher not found"
      fi
      
      if command -v firefox &> /dev/null; then
        echo "  ✅ Browser available"
      else
        echo "  ❌ Browser not found"
      fi
      echo ""
      
      # Disk usage
      echo "Storage:"
      df -h / | tail -1 | awk '{print "  Root: " $3 "/" $2 " (" $5 " used)"}'
      echo ""
      
      echo "💡 Management commands:"
      echo "  set-wine-hostname     - Set hostname for Wine apps"
      echo "  set-hostname-from-serial - Auto hostname from hardware"
      echo "  wine-env             - Start Wine environment shell"
    '')
  ];
}
