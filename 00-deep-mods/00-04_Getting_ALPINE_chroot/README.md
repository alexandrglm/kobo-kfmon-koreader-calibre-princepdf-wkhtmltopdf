# Create an Alpine Linux Chroot

This guide explains how to create a complete **Alpine Linux chroot environment** on your Kobo.

The chroot provides an independent, package-managed Linux userspace while still using the Kobo's existing kernel.

## Prerequisites

* A Kobo with **root access** via SSH or Telnet with a 4.x.x linux kernel
* Sufficient free space on the Kobo's onboard storage.

---

## Steps

### 1. Create a Disk Image

Create an empty **4 GB** image on the Kobo's onboard storage:

```bash
dd if=/dev/zero of=/mnt/onboard/alpine.img bs=1M count=4096
```


---

### 2. Format the Image

Format the image with a Linux filesystem:

```bash
mke2fs -F /mnt/onboard/alpine.img
```

---

### 3. Mount the Image

Create a mount point and mount the image:

```bash
mkdir -p /mnt/user
mount /mnt/onboard/alpine.img /mnt/user
```

The filesystem is now available at:

```text
/mnt/user
```

---


### 4. Download Alpine Linux

Download an Alpine Linux **ARMv7 minirootfs**:

```bash
wget -O /mnt/user/alpine-minirootfs.tar.gz  https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/armv7/alpine-minirootfs-3.24.1-armv7.tar.gz
```

> **Note:** The example above uses Alpine Linux **3.24.1**. For a new installation, verify that the selected Alpine release is still appropriate for your Kobo before proceeding.

---


### 5. Extract the Root Filesystem

Extract the Alpine root filesystem into the mounted image:

```bash
cd /mnt/user
tar zxvf alpine-minirootfs.tar.gz
```

You should now have the Alpine userspace inside `/mnt/user`.

### 6. Create the Helper Script

- Create a helper script on the Kobo's onboard storage, for example, at `/mnt/onboard/linux.sh`


- The script should handle:

    * Mounting `/dev`.
    * Mounting `/proc`.
    * Mounting `/sys`.
    * Making `/mnt/onboard` available inside the chroot.
    * Starting the chroot.
    * Entering the running environment.
    * Stopping the chroot.
    * Checking its status.

The repository's `linux.sh` script provides a robust implementation of these operations:

```bash
# Alpine Linux Chroot Script for Kobo
# Usage: ./alpine-chroot.sh [start|stop|enter|status]

ALPINE_IMG="/mnt/onboard/alpine.img"
CHROOT_DIR="/mnt/user"

start_chroot() {
    echo "Starting Alpine chroot..."
    
    # Check if image exists
    if [ ! -f "$ALPINE_IMG" ]; then
        echo "Error: Alpine image not found at $ALPINE_IMG"
        exit 1
    fi
    
    # Create mount point if it doesn't exist
    mkdir -p "$CHROOT_DIR"
    
    # Mount the Alpine image
    if ! mountpoint -q "$CHROOT_DIR"; then
        echo "Mounting Alpine image..."
        mount "$ALPINE_IMG" "$CHROOT_DIR"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to mount Alpine image"
            exit 1
        fi
    else
        echo "Alpine image already mounted"
    fi
    
    # Create directories BEFORE mounting
    mkdir -p "$CHROOT_DIR/mnt/onboard" 2>/dev/null || true
    mkdir -p "$CHROOT_DIR/mnt/kobo-root" 2>/dev/null || true
    mkdir -p "$CHROOT_DIR/dev/shm" 2>/dev/null || true
    
    # Mount system directories for full compatibility
    echo "Binding system directories..."
    
    # Essential filesystems
    mount -o bind /dev "$CHROOT_DIR/dev" 2>/dev/null || true
    mount -o bind /dev/pts "$CHROOT_DIR/dev/pts" 2>/dev/null || true
    mount -t proc proc "$CHROOT_DIR/proc" 2>/dev/null || true
    mount -t sysfs sysfs "$CHROOT_DIR/sys" 2>/dev/null || true
    mount -t tmpfs tmpfs "$CHROOT_DIR/run" 2>/dev/null || true
    
    # Additional Kobo-specific mounts for full device access
    mount -o bind /tmp "$CHROOT_DIR/tmp" 2>/dev/null || true
    mount -o bind /mnt/onboard "$CHROOT_DIR/mnt/onboard" 2>/dev/null || true
    mount -o bind,ro / "$CHROOT_DIR/mnt/kobo-root" 2>/dev/null || true
    
    # Mount shared memory
    mount -t tmpfs tmpfs "$CHROOT_DIR/dev/shm" 2>/dev/null || true
    
    # Copy essential configuration files
    cp /etc/resolv.conf "$CHROOT_DIR/etc/resolv.conf" 2>/dev/null || true
    cp /etc/hosts "$CHROOT_DIR/etc/hosts" 2>/dev/null || true
    cp /etc/passwd "$CHROOT_DIR/etc/passwd.kobo" 2>/dev/null || true
    cp /etc/group "$CHROOT_DIR/etc/group.kobo" 2>/dev/null || true
    
    # Set up timezone if available
    if [ -f /etc/localtime ]; then
        cp /etc/localtime "$CHROOT_DIR/etc/localtime" 2>/dev/null || true
    fi
    
    # Create device nodes that might be missing
    if [ ! -c "$CHROOT_DIR/dev/null" ]; then
        mknod -m 666 "$CHROOT_DIR/dev/null" c 1 3 2>/dev/null || true
    fi
    if [ ! -c "$CHROOT_DIR/dev/zero" ]; then
        mknod -m 666 "$CHROOT_DIR/dev/zero" c 1 5 2>/dev/null || true
    fi
    if [ ! -c "$CHROOT_DIR/dev/random" ]; then
        mknod -m 644 "$CHROOT_DIR/dev/random" c 1 8 2>/dev/null || true
    fi
    if [ ! -c "$CHROOT_DIR/dev/urandom" ]; then
        mknod -m 644 "$CHROOT_DIR/dev/urandom" c 1 9 2>/dev/null || true
    fi
    
    echo "Alpine chroot ready!"
    echo "Available storage:"
    df -h "$CHROOT_DIR" 2>/dev/null || true
}

stop_chroot() {
    echo "Stopping Alpine chroot..."
    
    # Kill any processes still running in chroot
    if mountpoint -q "$CHROOT_DIR"; then
        echo "Terminating chroot processes..."
        fuser -k "$CHROOT_DIR" 2>/dev/null || true
        sleep 2
    fi
    
    # Unmount in reverse order (very important!)
    umount "$CHROOT_DIR/dev/shm" 2>/dev/null || true
    umount "$CHROOT_DIR/mnt/kobo-root" 2>/dev/null || true
    umount "$CHROOT_DIR/mnt/onboard" 2>/dev/null || true
    umount "$CHROOT_DIR/tmp" 2>/dev/null || true
    umount "$CHROOT_DIR/run" 2>/dev/null || true
    umount "$CHROOT_DIR/sys" 2>/dev/null || true
    umount "$CHROOT_DIR/proc" 2>/dev/null || true
    umount "$CHROOT_DIR/dev/pts" 2>/dev/null || true
    umount "$CHROOT_DIR/dev" 2>/dev/null || true
    umount "$CHROOT_DIR" 2>/dev/null || true
    
    echo "Alpine chroot stopped!"
}

enter_chroot() {
    # Start if not already running
    if ! mountpoint -q "$CHROOT_DIR"; then
        start_chroot
    fi
    
    echo "Entering Alpine chroot..."
    echo "Type 'exit' to leave chroot"
    echo "Access Kobo files at: /mnt/onboard/"
    echo "Access Kobo system at: /mnt/kobo-root/ (read-only)"
    echo "---"
    
    # Set up environment variables for better experience
    chroot "$CHROOT_DIR" /bin/sh -c "
        export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
        export HOME=/root
        export TERM=xterm
        export PS1='[Alpine-\u@kobo \W]# '
        cd /root
        /bin/sh
    "
}

status_chroot() {
    echo "Alpine chroot status:"
    
    if [ -f "$ALPINE_IMG" ]; then
        echo "✓ Alpine image exists: $ALPINE_IMG"
        echo "  Size: $(du -h "$ALPINE_IMG" 2>/dev/null | cut -f1)"
    else
        echo "✗ Alpine image not found: $ALPINE_IMG"
    fi
    
    if mountpoint -q "$CHROOT_DIR"; then
        echo "✓ Alpine chroot is mounted and running"
        echo "  Mount point: $CHROOT_DIR"
        echo "  Available space:"
        df -h "$CHROOT_DIR" 2>/dev/null | tail -1 | awk '{print "    " $4 " free of " $2 " total (" $5 " used)"}'
        
        echo "  Active mounts:"
        mount | grep "$CHROOT_DIR" | while read line; do
            echo "    $line"
        done
        
        # Check for running processes
        if command -v fuser >/dev/null 2>&1; then
            PROCS=$(fuser "$CHROOT_DIR" 2>/dev/null | wc -w)
            if [ "$PROCS" -gt 0 ]; then
                echo "  Active processes: $PROCS"
            fi
        fi
    else
        echo "✗ Alpine chroot is not mounted"
    fi
}

case "$1" in
    start)
        start_chroot
        ;;
    stop)
        stop_chroot
        ;;
    enter)
        enter_chroot
        ;;
    status)
        status_chroot
        ;;
    restart)
        stop_chroot
        sleep 2
        start_chroot
        ;;
    *)
        echo "Usage: $0 {start|stop|enter|status|restart}"
        echo "  start   - Mount Alpine chroot"
        echo "  stop    - Unmount Alpine chroot"
        echo "  enter   - Enter Alpine chroot (auto-starts if needed)"
        echo "  status  - Show chroot status and information"
        echo "  restart - Stop and start chroot"
        exit 1
        ;;
esac

```
---

### 7. Start and Enter the Chroot

Start the Alpine environment:

```bash
/mnt/onboard/linux.sh start
```

Then enter it:

```bash
/mnt/onboard/linux.sh enter
```

If everything is working, you should now be inside the Alpine Linux environment.

---


### 8. Configure Alpine

Update the package index:

```bash
apk update
```

Install some basic tools:

```bash
apk add nano vim git
```

You can now use Alpine's `apk` package manager to install additional software.

---

## Filesystem Layout

Inside the Alpine chroot:

```text
/mnt/onboard
```

provides access to the Kobo's onboard storage.

The Kobo's original root filesystem is available at:

```text
/mnt/kobo-root
```

This allows the Alpine environment to interact with the underlying Kobo system when necessary.

---

## Notes

* The Alpine installation is stored in `alpine.img`, so it is independent of the Kobo's normal root filesystem.
* The chroot can persist across Kobo firmware updates because its filesystem resides on the onboard storage.
* The repository's `linux.sh` script handles the required mounts and provides commands to **start, stop, enter, and check the status** of the Alpine environment.
* A chroot does **not** provide a separate kernel; Alpine uses the Kobo's existing kernel.
* This method applies to any other linux ARMV7 version.
