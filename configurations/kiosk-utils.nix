# Kiosk management utilities
# These are general system management tools for the kiosk environment
{ config, pkgs, ... }:

{
  environment.systemPackages = [
    # Desktop overlay tools
    pkgs.conky
    pkgs.xosd  # For osd_cat fallback
    pkgs.xorg.xwininfo
    pkgs.xorg.xmessage
    
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

    # Conky configuration for persistent desktop overlay
    (pkgs.writeTextFile {
      name = "conky-kiosk.conf";
      destination = "/etc/conky/conky-kiosk.conf";
      text = ''
        conky.config = {
            alignment = 'top_right',
            background = false,
            border_width = 1,
            cpu_avg_samples = 2,
            default_color = 'white',
            default_outline_color = 'white',
            default_shade_color = 'white',
            draw_borders = false,
            draw_graph_borders = true,
            draw_outline = false,
            draw_shades = false,
            use_xft = true,
            font = 'DejaVu Sans Mono:size=10',
            gap_x = 20,
            gap_y = 20,
            minimum_height = 5,
            minimum_width = 300,
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
            own_window_argb_value = 200,
            stippled_borders = 0,
            update_interval = 30.0,
            uppercase = false,
            use_spacer = 'none',
            show_graph_scale = false,
            show_graph_range = false
        }

        conky.text = [[
        ''${color orange}SYSTEM INFO''${color}
        Hostname: ''${nodename}
        IP: ''${addr eth0}
        NixOS: ''${exec nixos-version | cut -d' ' -f1-2}
        Uptime: ''${uptime}
        Time: ''${time %Y-%m-%d %H:%M:%S}
        
        ''${color orange}HARDWARE''${color}
        CPU: ''${cpu cpu0}%
        RAM: ''${memperc}% (''${mem}/''${memmax})
        Disk: ''${fs_used_perc /}% (''${fs_used /}/''${fs_size /})
        ]]
      '';
    })

    # Start conky overlay
    (pkgs.writeShellScriptBin "start-conky-overlay" ''
      #!/bin/bash
      echo "Starting conky system info overlay..."
      
      # Kill any existing conky
      pkill conky 2>/dev/null || true
      sleep 1
      
      # Start conky with our config
      conky -c /etc/conky/conky-kiosk.conf &
      
      echo "Conky overlay started"
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
      
      # Continuous OSD display
      while true; do
        HOSTNAME=$(hostname)
        IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || echo "no-ip")
        NIXOS=$(nixos-version | cut -d' ' -f1-2)
        UPTIME=$(uptime -p | sed 's/up //')
        TIME=$(date '+%Y-%m-%d %H:%M:%S')
        
        echo -e "$HOSTNAME | $IP | $NIXOS\nUptime: $UPTIME | $TIME" | \
          osd_cat --pos=top --align=right --offset=20 \
                  --colour=white --shadow=2 --shadowcolour=black \
                  --font='-*-courier-*-*-*-*-12-*-*-*-*-*-*-*' \
                  --delay=30 &
        
        sleep 30
      done
    '')

    # Auto-start overlay (tries conky first, falls back to osd)
    (pkgs.writeShellScriptBin "start-system-overlay" ''
      #!/bin/bash
      echo "Starting system info overlay..."
      
      # Wait for X11
      sleep 3
      
      # Try conky first
      if command -v conky &> /dev/null && [ -f /etc/conky/conky-kiosk.conf ]; then
        echo "Using conky overlay"
        start-conky-overlay
      elif command -v osd_cat &> /dev/null; then
        echo "Using OSD overlay"
        start-osd-overlay &
      else
        echo "No overlay tools available"
        exit 1
      fi
    '')
  ];
}
