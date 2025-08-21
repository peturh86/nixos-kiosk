# Kiosk management utilities
# These are general system management tools for the kiosk environment
{ config, pkgs, ... }:

{
  environment.systemPackages = [
    # Desktop overlay tool
    pkgs.conky
    
    # NixOS System Hostname Manager (replaces Wine-specific approach)
    (pkgs.writeShellScriptBin "set-system-hostname" ''
      #!/bin/bash
      
      echo "🖥️  NixOS System Hostname Manager"
      echo "This changes the actual system hostname (which Wine inherits)"
      echo ""
      
      # Show current hostname
      echo "Current system hostname: $(hostname)"
      echo "Current hosts file entries:"
      grep -E "127\.0\.0\.1|::1" /etc/hosts | head -3
      echo ""
      
      # Get new hostname from user
      if [ -n "$1" ]; then
        NEW_HOSTNAME="$1"
        echo "Setting hostname to: $NEW_HOSTNAME"
      else
        echo "Enter new system hostname:"
        echo "(This will be visible to all applications including IPS)"
        echo ""
        read -p "Hostname: " NEW_HOSTNAME
        
        if [ -z "$NEW_HOSTNAME" ]; then
          echo "❌ No hostname provided. Canceling."
          exit 1
        fi
      fi
      
      # Validate hostname
      if [[ ! "$NEW_HOSTNAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
        echo "❌ Invalid hostname. Use only letters, numbers, and hyphens."
        exit 1
      fi
      
      if [ ''${#NEW_HOSTNAME} -gt 63 ]; then
        echo "❌ Hostname too long (max 63 characters)."
        exit 1
      fi
      
      echo ""
      echo "⚠️  WARNING: This will temporarily affect network connectivity!"
      echo "🔧 Changing system hostname to: $NEW_HOSTNAME"
      echo ""
      
      # Immediate hostname change (temporary until reboot)
      echo "Setting runtime hostname..."
      if ! sudo hostnamectl set-hostname "$NEW_HOSTNAME"; then
        echo "❌ Failed to set hostname. Do you have sudo privileges?"
        exit 1
      fi
      
      # Update /etc/hosts to prevent DNS issues
      echo "Updating /etc/hosts..."
      sudo sed -i.backup "s/127\.0\.0\.1.*/127.0.0.1 localhost $NEW_HOSTNAME/" /etc/hosts
      sudo sed -i "s/::1.*/::1 localhost $NEW_HOSTNAME ip6-localhost ip6-loopback/" /etc/hosts
      
      echo "✅ System hostname changed to: $NEW_HOSTNAME"
      echo ""
      
      # Restart Wine to pick up new hostname
      echo "🍷 Restarting Wine subsystem..."
      # Find and restart all Wine prefixes
      for prefix in $HOME/.wine-* $HOME/.wine; do
        if [ -d "$prefix" ]; then
          echo "  Restarting Wine prefix: $(basename $prefix)"
          export WINEPREFIX="$prefix"
          wineserver -k 2>/dev/null || true
        fi
      done
      
      sleep 2
      echo "✅ Wine subsystem restarted"
      echo ""
      
      # Test Wine hostname
      echo "Testing Wine hostname:"
      WINE_PREFIX=$(ls -d $HOME/.wine-ips-* 2>/dev/null | head -1)
      if [ -n "$WINE_PREFIX" ]; then
        export WINEPREFIX="$WINE_PREFIX"
        export PATH="${pkgs.wineWowPackages.stable}/bin:$PATH"
        WINE_HOSTNAME=$(wine hostname 2>/dev/null || echo "unknown")
        echo "  Wine hostname: $WINE_HOSTNAME"
        
        if [ "$WINE_HOSTNAME" = "$NEW_HOSTNAME" ]; then
          echo "  ✅ Wine picked up new hostname!"
        else
          echo "  ⚠️  Wine still shows old hostname. Wine server may need more time."
        fi
      else
        echo "  No Wine prefix found to test"
      fi
      
      echo ""
      echo "🎯 Hostname change completed!"
      echo ""
      echo "Current status:"
      echo "  System hostname: $(hostname)"
      echo "  Wine hostname: ''${WINE_HOSTNAME:-N/A}"
      echo ""
      echo "💡 Next steps:"
      echo "  • Test IPS: ips"
      echo "  • Check system status: kiosk-status"
      echo "  • For permanent hostname: update NixOS configuration"
      echo ""
      echo "⚠️  Note: For permanent hostname changes across reboots,"
      echo "   update networking.hostName in your NixOS configuration"
    '')

    # Legacy Wine hostname tool (now recommends system hostname approach)
    (pkgs.writeShellScriptBin "set-wine-hostname" ''
      #!/bin/bash
      echo "⚠️  DEPRECATED: Use 'set-system-hostname' instead"
      echo ""
      echo "Wine inherits the system hostname, so it's better to change"
      echo "the actual NixOS hostname rather than fighting with Wine registry."
      echo ""
      if [ -n "$1" ]; then
        echo "Running: set-system-hostname $1"
        exec set-system-hostname "$1"
      else
        echo "Running: set-system-hostname (interactive)"
        exec set-system-hostname
      fi
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
      
      # Call the system hostname setter
      exec set-system-hostname "$HOSTNAME"
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

    # Wine server restart utility
    (pkgs.writeShellScriptBin "restart-wine" ''
      #!/bin/bash
      echo "🔄 Restarting Wine subsystem..."
      echo ""
      
      # Find Wine prefix
      WINE_PREFIX=""
      for prefix in $HOME/.wine-* $HOME/.wine; do
        if [ -d "$prefix" ]; then
          WINE_PREFIX="$prefix"
          echo "Found Wine prefix: $(basename $prefix)"
          break
        fi
      done
      
      if [ -z "$WINE_PREFIX" ]; then
        echo "❌ No Wine prefix found. Nothing to restart."
        exit 1
      fi
      
      export WINEPREFIX="$WINE_PREFIX"
      export PATH="${pkgs.wineWowPackages.stable}/bin:$PATH"
      
      # Kill Wine server
      echo "Stopping Wine server..."
      wineserver -k 2>/dev/null || true
      
      # Wait a moment
      sleep 2
      
      # Verify it's stopped
      if pgrep -f wineserver > /dev/null; then
        echo "⚠️  Wine server still running, force killing..."
        pkill -9 -f wineserver 2>/dev/null || true
        sleep 1
      fi
      
      echo "✅ Wine server stopped"
      echo ""
      echo "Wine subsystem restarted. Next Wine command will start fresh server."
      echo ""
      echo "💡 Test with: wine hostname"
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
      df -h / | tail -1 | while read fs size used avail percent mount; do
        echo "  Root: $used/$size ($percent used)"
      done
      echo ""
      
      echo "💡 Management commands:"
      echo "  set-system-hostname   - Change system hostname (recommended)"
      echo "  set-wine-hostname     - Legacy Wine hostname (deprecated)"
      echo "  set-hostname-from-serial - Auto hostname from hardware"
      echo "  wine-env             - Start Wine environment shell"
    '')

    # Desktop system info overlay
    (pkgs.writeShellScriptBin "show-system-info-overlay" ''
      #!/bin/bash
      
      # Kill any existing overlay
      pkill -f "system-info-overlay" 2>/dev/null || true
      
      # Create system info display
      while true; do
        # Get system information
        HOSTNAME=$(hostname)
        NIXOS_VERSION=$(nixos-version | cut -d' ' -f1-2)
        
        # Get serial number (try multiple sources)
        SERIAL=$(cat /sys/class/dmi/id/product_serial 2>/dev/null || cat /sys/class/dmi/id/board_serial 2>/dev/null || echo "unknown")
        if [ "$SERIAL" = "unknown" ] || [ -z "$SERIAL" ]; then
          # Fallback to MAC address
          SERIAL=$(ip link show | grep -o 'link/ether [^[:space:]]*' | head -1 | cut -d' ' -f2 | tr -d ':' | tr '[:lower:]' '[:upper:]' | cut -c7-12)
          SERIAL="MAC-$SERIAL"
        fi
        
        # Get primary IP address
        IP_ADDR=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || echo "no-network")
        
        # Get Wine hostname if available
        WINE_HOSTNAME="N/A"
        WINE_PREFIX=$(ls -d $HOME/.wine-ips-* 2>/dev/null | head -1)
        if [ -n "$WINE_PREFIX" ] && command -v wine &> /dev/null; then
          export WINEPREFIX="$WINE_PREFIX"
          export PATH="${pkgs.wineWowPackages.stable}/bin:$PATH"
          WINE_HOSTNAME=$(wine hostname 2>/dev/null || echo "N/A")
        fi
        
        # Get uptime
        UPTIME=$(uptime -p | sed 's/up //')
        
        # Current timestamp
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        
        # Create info text
        INFO_TEXT="$HOSTNAME | $SERIAL | $IP_ADDR
Wine: $WINE_HOSTNAME | $NIXOS_VERSION
Up: $UPTIME | $TIMESTAMP"
        
        # Display using conky (if available) or fallback to xterm
        if command -v conky &> /dev/null; then
          # Create temporary conky config
          CONKY_CONFIG="/tmp/system-info-conky.conf"
          cat > "$CONKY_CONFIG" << EOF
conky.config = {
    alignment = 'top_right',
    gap_x = 20,
    gap_y = 20,
    minimum_height = 5,
    minimum_width = 5,
    net_avg_samples = 2,
    no_buffers = true,
    out_to_console = false,
    out_to_ncurses = false,
    out_to_stderr = false,
    out_to_x = true,
    own_window = true,
    own_window_class = 'Conky',
    own_window_type = 'override',
    own_window_transparent = true,
    own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',
    own_window_colour = 'black',
    own_window_argb_visual = true,
    own_window_argb_value = 0,
    update_interval = 30.0,
    uppercase = false,
    use_spacer = 'none',
    show_graph_scale = false,
    show_graph_range = false,
    double_buffer = true,
    font = 'DejaVu Sans Mono:size=10',
    default_color = 'white',
    default_outline_color = 'black',
    default_shade_color = 'black',
    draw_borders = false,
    draw_graph_borders = true,
    draw_outline = true,
    draw_shades = false,
    use_xft = true,
}

conky.text = [[
$HOSTNAME | $SERIAL | $IP_ADDR
Wine: $WINE_HOSTNAME | $NIXOS_VERSION  
Up: $UPTIME
$TIMESTAMP
]]
EOF
          
          conky -c "$CONKY_CONFIG" &
          CONKY_PID=$!
          
          # Wait 30 seconds, then restart to refresh info
          sleep 30
          kill $CONKY_PID 2>/dev/null || true
          
        else
          # Fallback: use xterm overlay (less elegant but works)
          echo "$INFO_TEXT" | ${pkgs.xterm}/bin/xterm -geometry 50x4+$(($(${pkgs.xorg.xrandr}/bin/xrandr | grep 'primary' | grep -o '[0-9]*x[0-9]*' | cut -d'x' -f1) - 400))+20 -title "System Info" -fg white -bg black -fn "fixed" -e "cat; sleep 30" &
          sleep 30
        fi
        
      done
    '')

    # Start system info overlay at login
    (pkgs.writeShellScriptBin "start-system-info-overlay" ''
      #!/bin/bash
      
      # Wait a bit for desktop to load
      sleep 3
      
      # Start the overlay in background
      show-system-info-overlay &
      
      # Mark as system info process for easy identification
      echo $! > /tmp/system-info-overlay.pid
    '')

    # Stop system info overlay
    (pkgs.writeShellScriptBin "stop-system-info-overlay" ''
      #!/bin/bash
      
      echo "Stopping system info overlay..."
      
      # Kill by process name
      pkill -f "show-system-info-overlay" 2>/dev/null || true
      pkill -f "system-info-conky" 2>/dev/null || true
      pkill -f "conky.*system-info" 2>/dev/null || true
      
      # Kill by PID file
      if [ -f /tmp/system-info-overlay.pid ]; then
        PID=$(cat /tmp/system-info-overlay.pid)
        kill $PID 2>/dev/null || true
        rm /tmp/system-info-overlay.pid
      fi
      
      echo "System info overlay stopped"
    '')
  ];
}
