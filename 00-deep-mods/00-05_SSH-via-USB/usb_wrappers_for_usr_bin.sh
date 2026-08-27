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
