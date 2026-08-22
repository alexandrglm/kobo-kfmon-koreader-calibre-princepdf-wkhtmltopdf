#!/bin/sh
# get_install_alpine_3.24.1.sh
# Installs Alpine Linux 3.24.1 (ARMv7) in a chroot on the Kobo
# Run this script on the Kobo via SSH or Telnet

set -e

ALPINE_IMG="/mnt/onboard/alpine.img"
CHROOT_DIR="/mnt/user"
ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/armv7/alpine-minirootfs-3.24.1-armv7.tar.gz"
ALPINE_TAR="/mnt/user/alpine-minirootfs.tar.gz"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root"
    exit 1
fi

# Remove existing image if present
if [ -f "$ALPINE_IMG" ]; then
    echo "Removing existing alpine.img..."
    rm -f "$ALPINE_IMG"
fi

# Create disk image
echo "Creating 4GB disk image..."
dd if=/dev/zero of="$ALPINE_IMG" bs=1M count=4096 2>/dev/null

# Format with ext2
echo "Formatting image as ext2..."
mke2fs -F "$ALPINE_IMG" 2>/dev/null

# Create mount point
mkdir -p "$CHROOT_DIR"

# Mount the image
echo "Mounting image to $CHROOT_DIR..."
mount "$ALPINE_IMG" "$CHROOT_DIR"

# Download Alpine Linux
echo "Downloading Alpine Linux 3.24.1..."
wget -O "$ALPINE_TAR" "$ALPINE_URL"

# Extract the root filesystem
echo "Extracting Alpine root filesystem..."
cd "$CHROOT_DIR"
tar zxf "$ALPINE_TAR"

# Clean up
rm -f "$ALPINE_TAR"

echo "Alpine Linux 3.24.1 installed at $CHROOT_DIR"
echo "Start with: /mnt/onboard/linux.sh start"
echo "Enter with:  /mnt/onboard/linux.sh enter"
