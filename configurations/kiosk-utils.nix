# Kiosk management utilities
# These are general system management tools for the kiosk environment
{ config, pkgs, ... }:

{
  environment.systemPackages = [
    # Basic debugging tools
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
  ];
}
