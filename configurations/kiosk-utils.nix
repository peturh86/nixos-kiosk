# Kiosk management utilities
# These are general system management tools for the kiosk environment
{ config, pkgs, ... }:

let
  # Conky config package
  conky-kiosk-config = pkgs.writeTextFile {
    name = "conky-kiosk.conf";
    destination = "/share/conky/conky-kiosk.conf";
    text = ''
      conky.config = {
          alignment = 'top_right',
          background = false,
          border_width = 0,
          cpu_avg_samples = 2,
          default_color = 'white',
          default_outline_color = 'black',
          default_shade_color = 'black',
          draw_borders = false,
          draw_graph_borders = false,
          draw_outline = true,
          draw_shades = true,
          use_xft = true,
          font = 'DejaVu Sans Mono:size=9',
          gap_x = 15,
          gap_y = 15,
          minimum_height = 5,
          minimum_width = 250,
          net_avg_samples = 2,
          no_buffers = true,
          out_to_console = false,
          out_to_stderr = false,
          extra_newline = false,
          own_window = true,
          own_window_class = 'Conky',
          own_window_type = 'desktop',
          own_window_transparent = true,
          own_window_argb_visual = true,
          own_window_argb_value = 180,
          stippled_borders = 0,
          update_interval = 30.0,
          uppercase = false,
          use_spacer = 'none',
          show_graph_scale = false,
          show_graph_range = false
      }

      conky.text = [[
''${color orange}''${nodename}''${color}
''${time %H:%M:%S}
''${color grey}Up: ''${uptime_short}''${color}
''${color grey}IP: ''${addr eth0}''${color}
      ]]
    '';
  };
in

{
  environment.systemPackages = [
    # Desktop overlay tools
    pkgs.conky
    pkgs.xosd  # For osd_cat fallback
    pkgs.xorg.xwininfo
    pkgs.xorg.xmessage
    conky-kiosk-config
    
    # Simple Wine restart utility
    (pkgs.writeShellScriptBin "restart-wine" ''
      #!/bin/bash
      echo "🔄 Restarting Wine subsystem..."
      
      # Kill all Wine processes
      pkill -f wineserver 2>/dev/null || true
      pkill -f wine 2>/dev/null || true
      
      sleep 2
      echo "✅ Wine subsystem restarted"
      echo "💡 Test with: wine hostname"
    '')

    # Simple system status
    (pkgs.writeShellScriptBin "kiosk-status" ''
      #!/bin/bash
      echo "🖥️  Kiosk System Status"
      echo "======================="
      echo "Hostname: $$(hostname)"
      echo "NixOS: $$(nixos-version | cut -d' ' -f1-2)"
      echo "Uptime: $$(uptime -p)"
      echo ""
      if command -v wine &> /dev/null; then
        echo "Wine available: $$(wine --version 2>/dev/null || echo 'error')"
      fi
      if command -v ips &> /dev/null; then
        echo "✅ IPS launcher available"
      fi
    '')

    # Simple Wine environment
    (pkgs.writeShellScriptBin "wine-env" ''
      #!/bin/bash
      echo "🍷 Wine Environment"
      echo "Setting up Wine PATH..."
      export PATH="${pkgs.wineWowPackages.stable}/bin:$$PATH"
      echo "Wine version: $$(wine --version)"
      echo "Wine hostname: $$(wine hostname)"
      exec $$SHELL
    '')

    # Simple system info display (manual)
    (pkgs.writeShellScriptBin "show-system-info" ''
      #!/bin/bash
      INFO="$$(hostname) | $$(date '+%H:%M') | $$(uptime -p | sed 's/up //')"
      echo "$$INFO"
      # Show as xmessage popup
      echo "$$INFO" | xmessage -file - -geometry +50+50 -timeout 10 2>/dev/null &
    '')

    # Start conky overlay
    (pkgs.writeShellScriptBin "start-conky-overlay" ''
      #!/bin/bash
      echo "Starting conky system info overlay..."
      
      # Kill any existing conky
      pkill conky 2>/dev/null || true
      sleep 1
      
      # Find the config file
      CONKY_CONFIG="${conky-kiosk-config}/share/conky/conky-kiosk.conf"
      
      if [ -f "$CONKY_CONFIG" ]; then
        echo "Using config: $CONKY_CONFIG"
        # Start conky detached from terminal
        nohup conky -c "$CONKY_CONFIG" > /dev/null 2>&1 &
        echo "Conky overlay started (PID: $!)"
      else
        echo "Conky config not found at $CONKY_CONFIG"
        # Fallback: start conky with default config
        echo "Starting conky with default config..."
        nohup conky > /dev/null 2>&1 &
        echo "Conky started with default config (PID: $!)"
      fi
    '')

    # Stop conky overlay  
    (pkgs.writeShellScriptBin "stop-conky-overlay" ''
      #!/bin/bash
      echo "Stopping conky overlay..."
      pkill conky 2>/dev/null || true
      echo "Conky overlay stopped"
    '')

    # OSD fallback using osd_cat
    (pkgs.writeShellScriptBin "start-osd-overlay" ''
      #!/bin/bash
      echo "Starting OSD system info overlay..."
      
      # Kill any existing osd processes
      pkill osd_cat 2>/dev/null || true
      
      # Start detached OSD loop
      nohup bash -c '
        while true; do
          HOSTNAME=$(hostname)
          IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oP "src \K\S+" || echo "no-ip")
          NIXOS=$(nixos-version | cut -d" " -f1-2)
          UPTIME=$(uptime -p | sed "s/up //")
          TIME=$(date "+%Y-%m-%d %H:%M:%S")
          
          echo -e "$HOSTNAME | $IP | $NIXOS\nUptime: $UPTIME | $TIME" | \
            osd_cat --pos=top --align=right --offset=20 \
                    --colour=white --shadow=2 --shadowcolour=black \
                    --font="-*-courier-*-*-*-*-12-*-*-*-*-*-*-*" \
                    --delay=30 &
          
          sleep 30
        done
      ' > /dev/null 2>&1 &
      
      echo "OSD overlay started (PID: $!)"
    '')

    # Auto-start overlay (tries conky first, falls back to osd)
    (pkgs.writeShellScriptBin "start-system-overlay" ''
      #!/bin/bash
      echo "Starting system info overlay..."
      
      # Wait for X11
      sleep 3
      
      # Try conky first
      if command -v conky &> /dev/null; then
        echo "Using conky overlay"
        start-conky-overlay
      elif command -v osd_cat &> /dev/null; then
        echo "Using OSD overlay"
        start-osd-overlay
      else
        echo "No overlay tools available"
        exit 1
      fi
    '')

    # Debug script to test overlay setup
    (pkgs.writeShellScriptBin "debug-overlay" ''
      #!/bin/bash
      echo "=== Overlay Debug Info ==="
      echo "DISPLAY: $DISPLAY"
      echo "USER: $USER"
      echo "HOME: $HOME"
      echo ""
      
      echo "Available tools:"
      command -v conky && echo "✅ conky available" || echo "❌ conky missing"
      command -v osd_cat && echo "✅ osd_cat available" || echo "❌ osd_cat missing"
      echo ""
      
      echo "Running processes:"
      pgrep -f conky && echo "✅ conky running" || echo "❌ conky not running"
      pgrep -f osd_cat && echo "✅ osd_cat running" || echo "❌ osd_cat not running"
      echo ""
      
      echo "Config check:"
      CONKY_CONFIG="${conky-kiosk-config}/share/conky/conky-kiosk.conf"
      [ -f "$CONKY_CONFIG" ] && echo "✅ conky config found: $CONKY_CONFIG" || echo "❌ conky config missing: $CONKY_CONFIG"
      
      if [ -f "$CONKY_CONFIG" ]; then
        echo "Config content preview:"
        head -10 "$CONKY_CONFIG"
      fi
      echo ""
      
      echo "Test simple conky (5 seconds):"
      cat > /tmp/test-conky.conf << 'EOF'
conky.config = {
    alignment = 'top_left',
    background = false,
    own_window = true,
    own_window_type = 'desktop',
    update_interval = 1.0
}
conky.text = [[
$${time %H:%M:%S}
]]
EOF
      echo "Starting test conky..."
      timeout 5 conky -c /tmp/test-conky.conf &
      sleep 6
      rm -f /tmp/test-conky.conf
      echo "Test complete"
    '')

    # Systemd service management
    (pkgs.writeShellScriptBin "conky-service" ''
      #!/bin/bash
      case "$1" in
        start)
          echo "Starting conky overlay service..."
          systemctl --user start conky-overlay.service
          ;;
        stop)
          echo "Stopping conky overlay service..."
          systemctl --user stop conky-overlay.service
          ;;
        restart)
          echo "Restarting conky overlay service..."
          systemctl --user restart conky-overlay.service
          ;;
        status)
          echo "Conky overlay service status:"
          systemctl --user status conky-overlay.service
          ;;
        enable)
          echo "Enabling conky overlay service..."
          systemctl --user enable conky-overlay.service
          ;;
        disable)
          echo "Disabling conky overlay service..."
          systemctl --user disable conky-overlay.service
          ;;
        *)
          echo "Usage: conky-service {start|stop|restart|status|enable|disable}"
          exit 1
          ;;
      esac
    '')
  ];

  # Systemd user service for conky overlay
  systemd.user.services.conky-overlay = {
    description = "Conky System Info Overlay";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.conky}/bin/conky -c ${conky-kiosk-config}/share/conky/conky-kiosk.conf";
      Restart = "always";
      RestartSec = 5;
      Environment = [ "DISPLAY=:0" ];
    };
    
    # Only start if X11 is available
    requisite = [ "graphical-session.target" ];
  };

  # Enable the user service by default
  systemd.user.targets.graphical-session.wants = [ "conky-overlay.service" ];
}
