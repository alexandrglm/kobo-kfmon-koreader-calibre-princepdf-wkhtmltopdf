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
