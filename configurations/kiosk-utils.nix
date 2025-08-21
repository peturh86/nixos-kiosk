# Kiosk management utilities
# These are general system management tools for the kiosk environment
{ config, pkgs, ... }:

{
  environment.systemPackages = [
    # Desktop overlay tool
    pkgs.conky
    
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
      echo "  restart-wine         - Restart Wine subsystem"
      echo "  wine-env             - Start Wine environment shell"
    # Wine environment helper for manual debugging
    (pkgs.writeShellScriptBin "wine-env" ''
      #!/bin/bash
      
      # Find Wine prefix
      WINE_PREFIX=$(ls -d $HOME/.wine-ips-* 2>/dev/null | head -1)
      if [ -z "$WINE_PREFIX" ]; then
        echo "❌ No Wine prefix found. Run 'ips' first to create one."
        exit 1
      fi
      
      export WINEPREFIX="$WINE_PREFIX"
      export PATH="${pkgs.wineWowPackages.stable}/bin:$PATH"
      
      echo "🍷 Wine environment ready!"
      echo "Wine prefix: $WINEPREFIX"
      echo "Wine version: $(wine --version)"
      echo "Wine hostname: $(wine hostname)"
      echo ""
      echo "You can now run Wine commands like:"
      echo "  wine notepad"
      echo "  wine regedit"
      echo "  wine uninstaller"
      echo ""
      echo "Starting a shell with Wine environment..."
      exec $SHELL
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
        
        # Get uptime
        UPTIME=$(uptime -p | sed 's/up //')
        
        # Current timestamp
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        
        # Display using conky
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
$NIXOS_VERSION | Up: $UPTIME
$TIMESTAMP
]]
EOF
          
          conky -c "$CONKY_CONFIG" &
          CONKY_PID=$!
          
          # Wait 30 seconds, then restart to refresh info
          sleep 30
          kill $CONKY_PID 2>/dev/null || true
          
        else
          # Fallback: simple overlay
          echo "$HOSTNAME | $SERIAL | $IP_ADDR | $NIXOS_VERSION | Up: $UPTIME | $TIMESTAMP" > /tmp/system-info.txt
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
