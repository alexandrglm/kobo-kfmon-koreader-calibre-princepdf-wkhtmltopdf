# Enable Telnet Access

This guide explains how to obtain **root Telnet access** to a Kobo e-reader over Wi-Fi by using the device's firmware update mechanism.


> [!NOTE]
> This guide comes from [Previous Steps to get Telnet access](../00-02-Getting-TELNET/Step-1_KoboRoot_rcS_edit/README.md).

---

## 6. Prepare Telnet Files

Create the following files and directories.

### `/opt/afterinit.sh`

```bash
#!/bin/sh
mkdir -p /dev/pts
mount -t devpts devpts /dev/pts
```

Make the script executable:

```bash
chmod +x /opt/afterinit.sh
```

### `/opt/inetd.conf`

Create the file with:

```conf
# <service_name> <sock_type> <proto> <flags> <user> <server_path> <args>
# ftp  stream  tcp  nowait  root  /usr/sbin/tcpd  in.ftpd

23 stream tcp nowait root /bin/busybox telnetd -i
```

This configures `inetd` to listen for Telnet connections on **TCP port 23**.

---

## 7. Modify `inittab`

Add the following two lines to the **end** of `inittab`:

```conf
::sysinit:/bin/sh /opt/afterinit.sh
::respawn:/usr/sbin/inetd -f /opt/inetd.conf
```

The complete `inittab` should look like this:

```conf
# This is run first except when booting in single-user mode.
::sysinit:/etc/init.d/rcS
::respawn:/sbin/kobo_getty.sh
::ctrlaltdel:/sbin/reboot
::shutdown:/etc/init.d/rcK
::restart:/sbin/init
::sysinit:/bin/sh /opt/afterinit.sh
::respawn:/usr/sbin/inetd -f /opt/inetd.conf
```

---

## 8. Create the Final Patch

Place the modified `inittab` and the complete `/opt` directory in your working directory.

> [!IMPORTANT]
> If you had to follow Steps **1–5**, use the **original `rcS`** in the final package. Do **not** include the modified `rcS` used to extract `inittab`.

From the directory containing your files, create the final package:

```bash
cd ./folder-where-you-are-editing-files/
tar czf ../KoboRoot.tgz ./opt/ ./etc/inittab
```

The resulting file should be:

```text
../KoboRoot.tgz
```

---

## 9. Apply the Final Patch

Copy the final `KoboRoot.tgz` into:

```text
.kobo/
```

Safely eject the Kobo and allow it to reboot.

The device should now start the Telnet service during boot.

---

## 10. Connect via Telnet

Find the Kobo's IP address in its network settings.

From your computer, connect using:

```bash
telnet <IP_ADDRESS>
```

Log in as:

```text
root
```

The password should normally be **blank**.

> [!NOTE]
> If the root password is not blank after a firmware update and you need to repeat this process, reinstall **KOReader** and use its terminal to set the root password:

```bash
passwd root
```

---

### 🔐 Telnet is insecure

Telnet transmits credentials and data **without encryption**.

Once you have root access, it is strongly recommended to:

1. Change the root password.
2. Replace Telnet with **SSH**, [here](../../00-03-Getting-SSH/README.md).

---


### Original Guide

This method is adapted from the original guide by [yingtongli.me](https://yingtongli.me/blog/2018/07/30/kobo-telnet-usb.html).

The original guide also covers:

* [Telnet over USB](https://yingtongli.me/blog/2018/07/30/kobo-autostart-usb.html)
* [Automatically switching between USB networking and file transfer](https://yingtongli.me/blog/2018/07/30/kobo-autoswitch-usb.html)

Those methods are **not required for this updated guide**.
