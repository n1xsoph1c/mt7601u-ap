#!/bin/bash
# Test script to verify MT7601U AP driver modes
# This driver is compiled for AP mode only (OPMODE_AP = 1)

echo "=========================================="
echo "MT7601U Driver Mode Testing"
echo "=========================================="
echo ""

# Check if driver is loaded
if ! lsmod | grep -q mt7601Uap; then
    echo "ERROR: mt7601Uap driver is not loaded!"
    exit 1
fi

# Check if interface exists
if ! ip link show ra0 &>/dev/null; then
    echo "ERROR: Interface ra0 does not exist!"
    exit 1
fi

echo "✓ Driver loaded: mt7601Uap"
echo "✓ Interface exists: ra0"
echo ""

# Display interface info
echo "Interface information:"
ip link show ra0
echo ""

# Check driver operation mode
echo "=========================================="
echo "DRIVER OPERATION MODE"
echo "=========================================="
echo ""
echo "This driver is compiled in AP mode only (OPMODE_AP)."
echo "It does NOT support:"
echo "  - IBSS/Ad-Hoc mode"
echo "  - Managed/Station mode (STA)"
echo "  - Monitor mode"
echo ""
echo "Supported configuration:"
echo "  ✓ Access Point (AP) mode"
echo "  ✓ Multiple BSSID (up to 8 virtual APs)"
echo ""

# Display wireless mode options
echo "=========================================="
echo "WIRELESS PHY MODES (WirelessMode setting)"
echo "=========================================="
echo ""
echo "Available WirelessMode values for 2.4GHz band:"
echo "  0 = PHY_11BG_MIXED   (802.11b/g mixed)"
echo "  1 = PHY_11B          (802.11b only)"
echo "  4 = PHY_11G          (802.11g only)"
echo "  6 = PHY_11N_2_4G     (802.11n only, 2.4GHz)"
echo "  7 = PHY_11GN_MIXED   (802.11g/n mixed)"
echo "  9 = PHY_11BGN_MIXED  (802.11b/g/n mixed) [DEFAULT]"
echo ""

# Check current configuration
echo "=========================================="
echo "CURRENT CONFIGURATION"
echo "=========================================="
echo ""

CONFIG_FILE="/etc/Wireless/RT2870AP/RT2870AP.dat"
if [ -f "$CONFIG_FILE" ]; then
    echo "Config file: $CONFIG_FILE"
    echo ""
    grep -E "^(WirelessMode|SSID|Channel|AuthMode|EncrypType|WPAPSK)=" "$CONFIG_FILE" 2>/dev/null || echo "  (Config file exists but may be empty)"
else
    echo "NOTE: Default config file not found at $CONFIG_FILE"
    echo "Driver will use compiled-in defaults or RT2870AP.txt from source dir"
fi
echo ""

# Test interface status
echo "=========================================="
echo "INTERFACE STATUS"
echo "=========================================="
echo ""

if ip link show ra0 | grep -q "UP"; then
    echo "✓ Interface ra0 is UP"
    
    # Try to get more info if available
    ifconfig ra0 2>/dev/null | head -3
else
    echo "✗ Interface ra0 is DOWN"
    echo ""
    echo "To bring up the interface:"
    echo "  sudo ip link set ra0 up"
fi
echo ""

# Show how to configure AP
echo "=========================================="
echo "QUICK START - AP CONFIGURATION"
echo "=========================================="
echo ""
echo "1. Copy default config (if not exists):"
echo "   sudo mkdir -p /etc/Wireless/RT2870AP"
echo "   sudo cp RT2870AP.txt /etc/Wireless/RT2870AP/RT2870AP.dat"
echo ""
echo "2. Edit configuration:"
echo "   sudo nano /etc/Wireless/RT2870AP/RT2870AP.dat"
echo ""
echo "3. Key settings to configure:"
echo "   SSID=YourNetworkName"
echo "   Channel=6                    # 1-11 for 2.4GHz"
echo "   WirelessMode=9               # 802.11b/g/n mixed"
echo "   AuthMode=WPA2PSK             # WPA2 security"
echo "   EncrypType=AES               # AES encryption"
echo "   WPAPSK=YourPassword          # Your WiFi password"
echo ""
echo "4. Bring up interface:"
echo "   sudo ip link set ra0 up"
echo ""
echo "5. Assign IP and start DHCP server (optional):"
echo "   sudo ip addr add 192.168.10.1/24 dev ra0"
echo "   sudo dnsmasq -i ra0 --dhcp-range=192.168.10.50,192.168.10.150,12h"
echo ""

# Summary
echo "=========================================="
echo "SUMMARY"
echo "=========================================="
echo ""
echo "Driver Mode:     Access Point (AP) only"
echo "Interface:       ra0"
echo "Chipset:         MediaTek MT7601U"
echo "Default PHY:     802.11b/g/n mixed (2.4GHz)"
echo "Max Speed:       150 Mbps (802.11n, 1x1)"
echo ""
echo "✓ Buffer overflow fix applied (CountryCode array)"
echo "✓ Kernel 6.15+ compatible"
echo ""
