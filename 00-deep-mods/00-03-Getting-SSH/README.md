# Install SSH Server (Dropbear)

This guide explains how to compile a modern **Dropbear SSH server** for the Kobo and integrate it with the existing `inetd` setup from the previous step.  

The result is a lightweight SSH server running directly on the Kobo, providing a more secure alternative to Telnet.

---

## Prerequisites

*   A Kobo with **root Telnet access** from the previous step.
*   A Linux computer with development tools installed.
*   An **ARM cross-compilation toolchain**.

---

# Steps

## 1. Download Dropbear

Download the latest Dropbear source code from the [official Dropbear website](https://matt.ucc.asn.au/dropbear/dropbear.html).

> [!IMPORTANT]
> This guide targets **Dropbear 2026.94 or later**.

Extract the source archive and enter the resulting directory:

```bash
tar xf dropbear-2026.94.tar.bz2

cd dropbear-2026.94
```

---

## 2. Install the ARM Cross-Compiler

-   On Debian/Ubuntu-based Linux systems:

```bash
sudo apt install gcc-arm-linux-gnueabihf
```

-   The compiler used by this guide is:

```text
arm-linux-gnueabihf-gcc
```

-   If not available or you get further dependenies error, add `armhf` architecture temporaly to your dpkg:

```bash
sudo dpkg --add-architecture armhf

sudo apt update
```
---

## 3. Cross-Compile Dropbear

Configure Dropbear for the Kobo's ARM environment:

```bash
./configure \
    --host=arm-linux-gnueabihf \
    --disable-zlib \
    --enable-static
```

Then compile only the required programs:

```bash
make PROGRAMS='dropbear dropbearkey' MULTI=1
```

This produces the multi-call binary:

```text
./dropbearmulti
```

> [!NOTE]
> Building Dropbear statically avoids dependency problems caused by differences between the build environment and the libraries available in the Kobo firmware.

---

## 4. Create the Kobo Directory Structure

- Create the directory structure that will eventually be packaged into `KoboRoot.tgz`:

```bash
mkdir -p KoboRoot/opt/dropbear
```

- Copy the compiled binary:

```bash
cp dropbearmulti KoboRoot/opt/dropbear/
```

The resulting structure should be:

```text
KoboRoot/
└── opt/
    └── dropbear/
        └── dropbearmulti
```

---


---

## 6. Update `inetd.conf`

Edit:

```text
/opt/inetd.conf
```

Add an SSH entry for **TCP port 22**.

For example:

```conf
# Telnet
23 stream tcp nowait root /bin/busybox telnetd -i

# SSH
22 stream tcp nowait root /opt/dropbear/dropbearmulti dropbear -i -r /opt/dropbear/rsa_key -r /opt/dropbear/ecdsa_key -r /opt/dropbear/ed25519_key
```

The `-i` option makes Dropbear operate through `inetd`.

> [!IMPORTANT]
> Keep the Telnet entry until SSH has been tested successfully. Once SSH works, Telnet can be removed.

---

## 7. Prepare the Final `KoboRoot.tgz`

The final package should contain:

```text
KoboRoot/
├── etc/
│   └── inittab
└── opt/
    ├── afterinit.sh
    ├── inetd.conf
    └── dropbear/
        ├── dropbearmulti
        ├── rsa_key
        ├── ecdsa_key
        └── ed25519_key
```

> [!IMPORTANT]
> Include the **original `rcS` only if it was required by your previous Telnet installation process**. Do not accidentally package a modified `rcS` unless the guide specifically requires it.

From inside the `KoboRoot` directory:

```bash
tar czf ../KoboRoot.tgz ./etc/inittab ./opt/
```

If your installation also requires `rcS`:

```bash
tar czf ../KoboRoot.tgz ./etc/init.d/rcS ./etc/inittab ./opt/
```

---

## 8. Apply the Patch

Copy the resulting:

```text
KoboRoot.tgz
```

to the Kobo's:

```text
.kobo/
```

Safely eject the device and allow it to reboot.

During boot, `inetd` will start Dropbear and listen on **TCP port 22**.

---

## 9. Generate SSH Host Keys via TELNET

- Connect to the Kobo using Telnet and create the Dropbear directory:

- Generate the SSH host keys:

```bash
./dropbearmulti dropbearkey -t rsa -f rsa_key
./dropbearmulti dropbearkey -t ecdsa -f ecdsa_key
./dropbearmulti dropbearkey -t ed25519 -f ed25519_key
```

```bash
23697/KoboRoot_4.45.23697/Step-4_OPT_partition_FW_edition$ telnet 192.168.100.252
Trying 192.168.100.252...
Connected to 192.168.100.252.
Escape character is '^]'.

kobo login: root
Password: 
[root@kobo ~]# cd /opt/dropbear/
 
[root@kobo dropbear]# ./dropbearmulti dropbearkey -t rsa -f rsa_key
Generating 2048 bit rsa key, this may take a while...
Public key portion is:
ssh-rsa ... root@kobo
Fingerprint: SHA256:...

[root@kobo dropbear]# ./dropbearmulti dropbearkey -t ecdsa -f ecdsa_key
Generating 256 bit ecdsa key, this may take a while...
Public key portion is:
ecdsa-sha2-nistp256 ... root@kobo
Fingerprint: SHA256:...


[root@kobo dropbear]# ./dropbearmulti dropbearkey -t ed25519  -f ed25519_key
Generating 256 bit ed25519 key, this may take a while...
Public key portion is:
ssh-ed25519 ... root@kobo
Fingerprint: SHA256:...


[root@kobo dropbear]# ls -la /opt/dropbear/*_key
-rw-------    1 root     root           140 Aug 22 16:27 /opt/dropbear/ecdsa_key
-rw-------    1 root     root            83 Aug 22 16:27 /opt/dropbear/ed25519_key
-rw-------    1 root     root           805 Aug 22 16:27 /opt/dropbear/rsa_key

[root@kobo dropbear]# reboot
```

- You should now have:

```text
/opt/dropbear/
├── dropbearmulti
├── rsa_key
├── ecdsa_key
└── ed25519_key
```

> [!WARNING]
> Keep the private host keys secure. They identify your Kobo's SSH server.

---

## 10. Connect via SSH

Find the Kobo's IP address and connect from your computer:

```bash
ssh root@<IP_ADDRESS>
```

If everything is working, you should receive a Dropbear SSH prompt and now you can access Kobo via SSH.

---

---

## Remove Telnet (or not)

If you consider once SSH has been successfully tested, Telnet is no longer necessary, remove it:

```text
/opt/inetd.conf
```

Leaving only the SSH service:

```conf
22 stream tcp nowait root /opt/dropbear/dropbearmulti dropbear -i -r /opt/dropbear/rsa_key -r /opt/dropbear/ecdsa_key -r /opt/dropbear/ed25519_key
```

This makes **SSH the primary remote-access method** and removes the insecure Telnet service.

---

## Summary

The final setup is:

```text
Kobo
│
├── /opt/
│   ├── afterinit.sh
│   ├── inetd.conf
│   └── dropbear/
│       ├── dropbearmulti
│       ├── rsa_key
│       ├── ecdsa_key
│       └── ed25519_key
│
└── /etc/
    └── inittab
```

