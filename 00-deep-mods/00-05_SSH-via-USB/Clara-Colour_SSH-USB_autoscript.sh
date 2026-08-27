#!/bin/sh
# Kobo Clara Colour - USB Ethernet (RNDIS) Auto-Setup Script
# This script detects if the device is a Clara Colour, checks for existing setup,
# and installs the USB Ethernet gadget if not already configured.

set -e

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Colour

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ----------------------------------------------------------------------
# 1. Device Detection
# ----------------------------------------------------------------------
log_info "Detecting device model..."

if grep -qi "MT8110" /proc/cpuinfo; then
    log_info "Device detected: Kobo Clara Colour (MediaTek MT8113T)"
else
    log_warn "Unknown CPU, please, check you are using this script in a Kobo Clara Colour"
    exit 1
fi

# ----------------------------------------------------------------------
# 2. Check for Existing Setup
# ----------------------------------------------------------------------
log_info "Checking for existing USB gadget setup..."

GADGET_DIR="/sys/kernel/config/usb_gadget/g1"
WRAPPER="/usr/bin/usb"

if [ -d "$GADGET_DIR" ] && [ -f "$WRAPPER" ]; then
    log_warn "USB Ethernet gadget appears to be already installed."
    echo "  - Gadget directory: $GADGET_DIR"
    echo "  - Wrapper script: $WRAPPER"
    echo ""
    read -p "Do you want to reinstall/overwrite? (y/N): " -r OVERWRITE
    if [ ! "$OVERWRITE" = "y" ] && [ ! "$OVERWRITE" = "Y" ]; then
        log_info "Exiting without changes."
        exit 0
    fi
    log_info "Proceeding with reinstall..."
fi

# ----------------------------------------------------------------------
# 3. Create the USB Gadget
# ----------------------------------------------------------------------
log_info "Setting up USB Ethernet gadget (RNDIS)..."

# 3.1 Create gadget directory
mkdir -p /sys/kernel/config/usb_gadget/g1
cd /sys/kernel/config/usb_gadget/g1

# 3.2 Set IDs
echo 0x0525 > idVendor   # Netchip
echo 0xa4a2 > idProduct  # Ethernet/RNDIS

# 3.3 Strings
mkdir -p strings/0x409
echo "Kobo" > strings/0x409/manufacturer
echo "USB Ethernet (RNDIS)" > strings/0x409/product

# 3.4 RNDIS function
mkdir -p functions/rndis.usb0
echo "00:11:22:33:44:55" > functions/rndis.usb0/dev_addr
echo "00:11:22:33:44:56" > functions/rndis.usb0/host_addr

# 3.5 Configuration
mkdir -p configs/c.1
echo 120 > configs/c.1/MaxPower
ln -s functions/rndis.usb0 configs/c.1

# 3.6 Find the UDC controller
UDC=$(ls /sys/class/udc/ 2>/dev/null | head -1)
if [ -z "$UDC" ]; then
    log_error "No UDC (USB Device Controller) found. Is USB gadget support enabled in the kernel?"
fi

echo "$UDC" > UDC
log_info "USB gadget activated with UDC: $UDC"

# ----------------------------------------------------------------------
# 4. Create the Wrapper Script
# ----------------------------------------------------------------------
log_info "Creating wrapper script: /usr/bin/usb"

cat > /usr/bin/usb << 'EOF'
#!/bin/sh

GADGET_DIR="/sys/kernel/config/usb_gadget/g1"
UDC_FILE="$GADGET_DIR/UDC"
INTERFACE="rndis0"

case "$1" in
    on)
        if [ -f "$UDC_FILE" ]; then
            UDC=$(ls /sys/class/udc/ 2>/dev/null | head -1)
            if [ -n "$UDC" ]; then
                echo "$UDC" > "$UDC_FILE"
                ifconfig "$INTERFACE" 192.168.8.2
                echo "USB Ethernet active on 192.168.8.2 (interface: $INTERFACE)"
            else
                echo "Error: No UDC available"
                exit 1
            fi
        else
            echo "Error: Gadget not configured. Run setup script first."
            exit 1
        fi
        ;;
    off)
        if [ -f "$UDC_FILE" ]; then
            echo "" > "$UDC_FILE"
            echo "USB Ethernet deactivated"
        else
            echo "Error: Gadget not configured"
            exit 1
        fi
        ;;
    status)
        if [ -f "$UDC_FILE" ]; then
            UDC=$(cat "$UDC_FILE" 2>/dev/null)
            if [ -n "$UDC" ]; then
                IP=$(ifconfig "$INTERFACE" 2>/dev/null | grep 'inet addr' | awk '{print $2}')
                echo "USB Ethernet: ACTIVE on $IP"
            else
                echo "USB Ethernet: INACTIVE"
            fi
        else
            echo "Error: Gadget not configured"
            exit 1
        fi
        ;;
    *)
        echo "Usage: usb {on|off|status}"
        echo "  on      - Activate USB Ethernet (RNDIS) on 192.168.8.2"
        echo "  off     - Deactivate USB Ethernet"
        echo "  status  - Show current status"
        exit 1
        ;;
esac
EOF

chmod +x /usr/bin/usb
log_info "Wrapper script created: /usr/bin/usb"

# ----------------------------------------------------------------------
# 5. Final Status
# ----------------------------------------------------------------------
echo ""
log_info "Setup complete."
echo ""
echo "Summary:"
echo "  - Device: Kobo Clara Colour (MT8113T)"
echo "  - USB Gadget: RNDIS Ethernet"
echo "  - Kobo IP: 192.168.8.2"
echo "  - Host IP: 192.168.8.1 (set manually on host)"
echo ""
echo "Commands:"
echo "  - Activate:   usb on"
echo "  - Deactivate: usb off"
echo "  - Status:     usb status"
echo ""
echo "On your host (Linux), after connecting:"
echo "  sudo ip addr add 192.168.8.1/24 dev enx<your-interface>"
echo "  sudo ip link set enx<your-interface> up"
echo "  ssh root@192.168.8.2"
echo ""
echo "To prevent the USB interface from becoming your default gateway:"
echo "  nmcli con mod usb_SSH ipv4.never-default yes"
echo ""

# ----------------------------------------------------------------------
# 6. Optional: Activate now?
# ----------------------------------------------------------------------
read -p "Do you want to activate the USB Ethernet now? (y/N): " -r ACTIVATE
if [ "$ACTIVATE" = "y" ] || [ "$ACTIVATE" = "Y" ]; then
    /usr/bin/usb on
fi
