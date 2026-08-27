# USB Ethernet Gadget for Kobo Clara Colour

This guide adapts the [USB Telnet method for the Kobo Clara HD](https://yingtongli.me/blog/2018/07/30/kobo-telnet-usb.html) for the Kobo Clara Colour, which uses a different hardware.

- The original guide relied on kernel modules (`g_ether.ko`) that are not present on the Clara Colour.   

- However, the Clara Colour's kernel (4.9.77) has built-in support for USB gadget functions, including RNDIS.   

The approach therefore shifts from loading modules to configuring the gadget directly through configfs.


| Aspect | Clara HD (Original) | Clara Colour (Adapted) |
|--------|---------------------|------------------------|
| SoC | Freescale i.MX | MediaTek MT8113T |
| USB Function | `g_ether` | RNDIS (built-in) |
| Method | Module loading (`insmod`) | Configfs direct setup |
| IP Assignment | `usb0` interface | `rndis0` interface |

---

## Steps


### On the Kobo Clara Colour

1.  **Setting up the USB gadget via configfs**

The USB gadget is configured through the kernel's configfs interface, which provides a filesystem-based API for setting up USB device functions. This method is used because the Clara Colour does not include the `g_ether.ko` kernel module that the original guide relied on. Instead, the kernel has built-in support for USB gadget functions that can be configured directly via configfs.

-   *1.1 Create the gadget directory*

The first step is to create a directory for the USB gadget under `/sys/kernel/config/usb_gadget/`. This directory will hold all the configuration files for the gadget.

```bash
mkdir -p /sys/kernel/config/usb_gadget/g1

cd /sys/kernel/config/usb_gadget/g1
```

-   *1.2 Set USB vendor and product IDs*

The USB vendor and product IDs identify the device to the host computer. The values `0x0525` (Netchip Technology) and `0xa4a2` (Ethernet/RNDIS Gadget) are standard identifiers for this type of USB gadget.

```bash
echo 0x0525 > idVendor
echo 0xa4a2 > idProduct
```

-   *1.3 Configure device strings*

These are stored in a subdirectory named after the language code (`0x409` for English).

```bash
mkdir -p strings/0x409
echo "Kobo" > strings/0x409/manufacturer
echo "USB Ethernet" > strings/0x409/product
```

-   *1.4 Create the RNDIS function*

RNDIS is the USB Ethernet profile that is most compatible with modern operating systems. The `dev_addr` is the MAC address that the Kobo will use, and `host_addr` is the MAC address that the host computer will see. Use the MAC at your own.

```bash
mkdir -p functions/rndis.usb0

echo "00:11:22:33:44:55" > functions/rndis.usb0/dev_addr
echo "00:11:22:33:44:56" > functions/rndis.usb0/host_addr
```

-   *1.5 Create the configuration and link the function*

The configuration groups together the functions that the gadget will provide. The `MaxPower` setting specifies the maximum power consumption of the device in milliamps. The RNDIS function is then linked to this configuration.

```bash
mkdir -p configs/c.1

echo 120 > configs/c.1/MaxPower

ln -s functions/rndis.usb0 configs/c.1
```

-   *1.6 Activate the gadget*

The gadget is activated by writing the UDC (USB Device Controller) name to the `UDC` file. The controller name (`11211000.usb`) is specific to the MediaTek MT8113T SoC and can be found in `/sys/class/udc/`.

```bash
echo "11211000.usb" > UDC
```

---

2.  **Assigning an IP address**

Once the gadget is active, the `rndis0` network interface appears. An IP address must be assigned to this interface to enable network communication with the host as, for example, 192.168.8.2:

```bash
ifconfig rndis0 192.168.8.2
```

---

3.  **Creatint a handler script/wrapper to automate the process**

To simplify activation and deactivation of the USB Ethernet connection, a wrapper/script called `/usr/bin/usb` could be created. This script might provide three subcommands:

-   `usb on`:   Activates the USB gadget and assigns the IP address
-   `usb off`:  Deactivates the USB gadget
-   `usb status`:   Displays the current status of the connection

```bash
#!/bin/sh

case "$1" in
    on)
        echo "11211000.usb" > /sys/kernel/config/usb_gadget/g1/UDC
        ifconfig rndis0 192.168.8.2
        ;;
    off)
        echo "" > /sys/kernel/config/usb_gadget/g1/UDC
        ;;
    status)
        if [ -n "$(cat /sys/kernel/config/usb_gadget/g1/UDC 2>/dev/null)" ]; then
            echo "USB Ethernet active on $(ifconfig rndis0 | grep 'inet addr' | awk '{print $2}')"
        else
            echo "USB Ethernet inactive"
        fi
        ;;
esac
```

- *Mark the script as executable:*

```bash
chmod +x /usr/bin/usb
```

The script can then be invoked at any time to control the USB Ethernet connection.

---

### On the Host Computer (Linux)

1.  **Identify the USB network interface**

When the Kobo is connected with the USB gadget active, the host computer detects a new network interface.   

This interface is usually named `enxxxxxx` or `enspxxxxxxxx`, followed by random numbers or by the MAC address (e.g., `enx001122334456`).

Using a `ip link` will show which interface is:

```bash
ip link | grep -E "usb|enx"
```

2.  **Assign an IP address to the interface**

Once the interface is identified, an IP address is assigned to it. The host computer can use any `/24` address (for example `192.168.8.1`), which is on the same subnet as the Kobo's chosen IP `192.168.8.2`.

```bash
sudo ip addr add 192.168.8.1/24 dev enx001122334456

sudo ip link set enx001122334456 up
```

> [IMPORTANT]
> **Prevent the interface from becoming the default gateway**
> To avoid network conflicts where the USB interface might override the host's primary internet connection, the interface can be configured so that it's never used as the default gateway,as for example:
>
> ```bash
> nmcli con mod <Network manager profile name> ipv4.never-default yes
> nmcli con mod <Network manager profile name> ipv6.never-default yes
> ```
>
> If NetworkManager is not being used, the same effect can be achieved by assigning a high metric to the interface route.

---

### Testing

Once the IP addresses are set on both sides, the USB Ethernet connection can be tested.

```bash
ping 192.168.8.2
```

If the ping succeeds, the connection is functioning correctly. SSH, Telnet or any other services can be accessed over the USB link:

```bash
ssh root@192.168.8.2
```

---

## What Happens with USB Mass Storage?

> [!WARNING]
> **USB Mass Storage is Disabled While the USB Ethernet Gadget is Active**
>
> When the USB Ethernet gadget is enabled (`usb on`), the Kobo's USB port is occupied by the network function. This means that **USB Mass Storage** the normal mode used to transfer books and files via USB is **completely unavailable**.
>
> This affects not only the Kobo's built-in "Computer detected" dialog and Nickel's USB connection mode, but also **KOReader's USB Mass Storage feature**. In KOReader, the "USB Mass Storage" menu option will fail to work because the USB device is already claimed by the Ethernet gadget.
>
> To restore USB Mass Storage functionality:
>
> 1.  Deactivate the USB Ethernet gadget:
>     ```bash
>     usb off
>     ```
> 2.  On the Kobo, tap "Connect" in the "Computer detected" dialog, or within KOReader, select "USB Mass Storage".
> 3.  USB Mass Storage will now work normally.
>
> After you have finished transferring files, you can reactivate the USB Ethernet gadget with:
> ```bash
> usb on
> ```



