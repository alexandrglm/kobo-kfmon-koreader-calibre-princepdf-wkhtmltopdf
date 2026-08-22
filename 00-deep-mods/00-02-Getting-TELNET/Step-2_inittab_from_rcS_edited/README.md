# Previous to Enable Telnet Access

This guide explains how to obtain **root Telnet access** to a Kobo e-reader over Wi-Fi by using the device's firmware update mechanism:

-   **DEVICE**:         *Kobo Clara Colour*
-   **FW VERSION**:     *4.45.23697 - 25/05/2026*
-   **Linux Kernel**:   *Linux kobo 4.9.77 #1 SMP PREEMPT e5649aba8-20251107T154948-B1107155140 armv7l GNU/Linux*


---

## Prerequisites

* A **Kobo e-reader**.
* A computer with a command-line interface.
* The Kobo and computer connected to the **same Wi-Fi network**.
* A firmware update file matching your specific Kobo model.

### Kobo Clara Colour

The latest firmware used for testing this guide is:

* **Firmware:** `4.45.23697`
* **Tested on:** Kobo Clara Colour
* [Download `kobo-update-4.45.23697.zip` from official sources](https://ereaderfiles.kobo.com/firmwares/kobo12/May2026/kobo-update-4.45.23697.zip)

> [!IMPORTANT]
> Firmware files are **device-specific**. Make sure you use the firmware corresponding to your Kobo model.

---

# Steps


> [!WARNING]
> **If your firmware already includes a clean copy of `inittab`, skip directly to [Step 6](#6-prepare-telnet-files).**

## 1. Obtain the Firmware

Download the correct firmware for your device and extract the `KoboRoot.tgz` file from the firmware archive.

---

## 2. Modify `rcS`

> [!CAUTION]
> Be extremely careful when modifying `rcS`. An incorrect modification can prevent the Kobo from booting.


- Unpack `KoboRoot.tgz` and edit `/etc/init.d/rcS`

- Add this line `cp /etc/inittab /mnt/onboard/` that copies the system's `inittab` file to the Kobo's onboard storage, **EXACTLY HERE**:ç

-   Always BEFORE `/usr/local/Kobo/hindenburg &` last block, as for example on line 234~235:
    ```bash
    ...

    chmod u+s /libexec/dbus-daemon-launch-helper

    # Kobo Clara Colour TELNET STEP 1 modification HERE !
    cp /etc/inittab /mnt/onboard/

    echo -n 8192 > /proc/sys/vm/min_free_kbytes
    echo -n 67108864 > /proc/sys/kernel/shmmax

    /usr/local/Kobo/pickel can-upgrade

    ...
    ```

- This repo includes the modified file for the Device-FW version in use.


---

## 3. Create a Custom `KoboRoot.tgz`

- Repack the modified `rcS` into a new `KoboRoot.tgz`.

```bash
tar czf ../KoboRoot.tgz ./etc/init.d/rcS
```

---

## 4. Apply the Patch

- Copy the newly created `KoboRoot.tgz` into the Kobo's `.kobo/` paht.  

- Safely eject the device. The Kobo will reboot and automatically apply the update.

---

## 5. Extract the Real `inittab`

After the Kobo has rebooted:

1. Connect it to the computer via USB.
2. Open the root of the Kobo's onboard storage.
3. Copy the extracted `inittab` file to your computer.

You now have the **actual `inittab` from your device**.

---


### Go to Step 4: OTP partition FW edits and follow Steps 6 ~ 10

[Next steps here](../Step-4_OPT_partition_FW_edition/).


---

### Original Guide

This method is adapted from the original guide by [yingtongli.me](https://yingtongli.me/blog/2018/07/30/kobo-telnet-usb.html).

The original guide also covers:

* [Telnet over USB](https://yingtongli.me/blog/2018/07/30/kobo-autostart-usb.html)
* [Automatically switching between USB networking and file transfer](https://yingtongli.me/blog/2018/07/30/kobo-autoswitch-usb.html)

Those methods are **not required for this updated guide**.
