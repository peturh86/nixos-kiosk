# Serial port support for Wine applications
{ pkgs }:

{
  check-serial = pkgs.writeShellScriptBin "check-serial" ''
    echo "=== Serial Port Detection ==="
    echo ""
    
    echo "Available serial devices:"
    ls -la /dev/tty{S,USB,ACM}* 2>/dev/null || echo "No serial devices found"
    
    echo ""
    echo "USB-to-Serial devices:"
    lsusb | grep -i "serial\|prolific\|ftdi" || echo "No USB-to-serial adapters detected"
    
    echo ""
    echo "Current user groups:"
    groups
    
    echo ""
    echo "Serial device permissions:"
    ls -la /dev/tty{S,USB,ACM}* 2>/dev/null | head -10
    
    echo ""
    echo "Wine COM port registry (if Wine is set up):"
    if [ -d "$HOME/.wine-app-"* ]; then
        export WINEPREFIX=$(ls -d "$HOME/.wine-app-"* | head -1)
        wine reg query "HKLM\\Software\\Wine\\Ports" 2>/dev/null || echo "No Wine COM ports configured yet"
    else
        echo "Wine not set up yet - run 'ips' first"
    fi
    
    echo ""
    echo "=== COM Port Testing ==="
    echo "To test a specific device:"
    echo "1. Connect your scales to USB/Serial port"
    echo "2. Find the device: ls -la /dev/ttyUSB*"
    echo "3. Test communication: cat /dev/ttyUSB0"
    echo "4. Or use: screen /dev/ttyUSB0 9600"
  '';
  
  test-com = pkgs.writeShellScriptBin "test-com" ''
    if [ -z "$1" ]; then
        echo "Usage: test-com <device>"
        echo "Example: test-com /dev/ttyUSB0"
        echo ""
        echo "Available devices:"
        ls -la /dev/tty{S,USB,ACM}* 2>/dev/null
        exit 1
    fi
    
    DEVICE="$1"
    if [ ! -e "$DEVICE" ]; then
        echo "Device $DEVICE not found"
        exit 1
    fi
    
    echo "Testing communication with $DEVICE"
    echo "Press Ctrl+C to stop"
    echo "Listening for data..."
    
    # Test basic communication
    timeout 10 cat "$DEVICE" || echo "No data received in 10 seconds"
  '';
}
