# Kobo's Must: `KFMon`, `NickelMenu`, `NickelDBus`, `KOReader` & `Plato`

This repository contains the resources, configuration files, and step-by-step instructions for installing and maintaining a complete third-party launcher and remote control setup on Kobo e-readers.

> [!WARNING] 
> **Tested on Kobo Clara Colour. FW 4.x** 
>  If you are using a different e-reader model, ensure that component versions match your hardware architecture and firmware requirements (especially regarding Qt5/Qt4 vs. Qt6/KoboOS 5.x compatibility).


| Component | Description | Firmware Survival |
| :--- | :--- | :--- |
| **KFMon** | File-trigger based launcher that watches for specific files/icons and launches third-party apps when opened. | ❌ Requires re-installation after firmware updates |
| **NickelMenu** | In-app GUI extension adding custom menu entries directly to Kobo's stock interface (*Nickel*). | ✅ High survival rate across firmware updates |
| **NickelDBus** | Headless D-Bus interface exposing Nickel’s internal Qt actions/methods to the Linux shell via the `qndb` CLI tool. | ✅ Survives updates; essential for SSH control |
| **KOReader** | The premier open-source document reader for e-ink devices (PDF, EPUB, CBZ, reflow support). | ✅ Preserved during updates |
| **Plato** | A minimalist, high-performance document reader designed as a lightweight alternative to KOReader. | ✅ Preserved during updates |

---

### Part 1: Prepare the eReader

1. Connect your Kobo to your PC via USB and edit `./.kobo/Kobo/Kobo eReader.conf`.
2. Locate the `[FeatureSettings]` section (or create it if absent) and append `ExcludeSyncFolders`:
```ini
[FeatureSettings]
AntiAliasing=true
ExcludeSyncFolders=((?!kobo|adobe).+|([^.][^/]*/)+.+)

```


3. Safely disconnect and restart your device. This prevents Kobo from indexing hidden software directories like `.adds` or `.kobo`.


### Part 2: Install KFMon (Optional Launcher)

> [!IMPORTANT]
> *Note:*   KFMon must be reinstalled whenever the official Kobo firmware updates.

1. Locate `KFMon-v1.4.6-191/KFMon-v1.4.6-191-gca31869.zip` from this repository.
2. Uncompress its contents directly to the root directory of your Kobo storage via USB.
3. **DO NOT** manually extract any internal `KoboRoot.tgz` file; copy it as-is to `/.kobo/KoboRoot.tgz`.
4. Eject and unplug your device to allow the installation reboot cycle to finish.



### Part 3: Install NickelMenu (GUI Menu Extension)

1. Extract `NickelMenu_0.6.0.zip` or locate the `KoboRoot.tgz` inside `NickelMenu_0.6.0/`.
2. Copy `KoboRoot.tgz` into the `/.kobo/` directory on your device.
3. Copy your custom configuration folder `nm/` to `/mnt/onboard/.adds/nm/`.
4. Eject the device. Upon reboot, a new **NickelMenu** button will appear in the lower-right corner of the Home screen.

> [!NOTE]
> A pre-configured nm file is proveded [here](./NickelMenu_0.6.0/nm). Configure it as you need (read /doc document included in NickelMenu)

```text
# Services
menu_item :main :GDrive :nickel_open :library:gdrive
menu_item :main :DropBox :nickel_open :library:dropbox
#menu_item :main :Overdrive :nickel_open :store:overdrive
#menu_item :main :Pocket :nickel_open :library:pocket
menu_item :main :Instapaper :nickel_open :library:instapaper

# Games
menu_item :main :Solitario :nickel_extras :solitaire
menu_item :main :Sudoku    :nickel_extras :sudoku
menu_item :main :Scribble :nickel_extras :word_scramble
menu_item :main :Unblock It :nickel_extras :unblock_it

# Web Browser
menu_item :main :Web Browser :nickel_browser :https://www.duck.com
# NEEDED to add "Quit" menu on web browser fullscreen
menu_item :browser:Quit:nickel_misc:home
menu_item :main :Web Browser in a Modal :nickel_browser :modal:https://duckduckgo.com

# Apps Readers
menu_item :main :KOReader :cmd_spawn :quiet :exec /mnt/onboard/.adds/koreader/koreader.sh
menu_item : main : Plato : cmd_spawn : quiet : exec /mnt/onboard/.adds/plato/plato.sh

# USB Dialogs and/or others
menu_item :main :Start USB :nickel_misc :force_usb_connection

# Power
menu_item :main :Reboot :power :reboot
menu_item :main :Power Off :power :shutdown
```


### Part 4: Install NickelDBus (D-Bus & Terminal Control)

> [!IMPORTANT]
> NickelDBus allows controlling Nickel natively from an SSH shell using the `qndb` executable without requiring an on-screen menu.

1. Locate `NickelDBus_0.2.0/KoboRoot.tgz` in this repository.
2. Copy `KoboRoot.tgz` directly into the `/.kobo/` directory on your Kobo.
3. Eject and unplug the device to let it reboot and install the `qndb` CLI utility and `libndb.so` plugin.
4. Verify installation via SSH:
```bash
[root@kobo ~]# qndb --help
Usage: qndb [options] [args...]
Qt CLI for NickelDBus

Options:
  -h, --help                  Displays this help.
  -v, --version               Displays version information.
  -s, --signal <signal name>  Wait for signal, and prints its output, if any.
  -t, --timeout <timeout ms>  Signal timeout in milliseconds.
  -m, --method <method name>  Method to invoke.
  -a, --api                   Print API usage

Arguments:
  arguments                   Arguments to pass to method. Have no affect when
                              a method is not set.
```

---

### Part 5: Prepare KOReader & Plato

1. Unzip `KOreader_2026.07.1/koreader-kobo-v2026.07.1.zip`.
2. Copy the resulting `koreader` directory into `/mnt/onboard/.adds/koreader/`.
3. If using Plato, copy the `plato` folder into `/mnt/onboard/.adds/plato/`.

---

## SSH Control & Headless Management (via `qndb`)

When NickelMenu is unavailable or when operating headlessly via SSH, you can trigger internal Nickel actions directly using NickelDBus:

### Essential Commands

* **Open Web Browser:**
```bash
qndb -m bwmOpenBrowser true "[https://duckduckgo.com](https://duckduckgo.com)"

```


* **Display Toast Notification:**
```bash
qndb -m mwcToast 3000 "SSH Session" "Executing command..."

```


* **Return to Home Screen:**
```bash
qndb -m mwcHome

```


* **Force USB Mass Storage:**
```bash
qndb -m nsAutoUSBGadget "enable"

```


* **Power Management:**
```bash
qndb -m pwrSleep    # Suspend
qndb -m pwrReboot   # Reboot
qndb -m pwrShutdown # Power off

```


* **Launch KOReader / Plato (Stopping Nickel First):**
```bash
# KOReader
pkill -9 nickel; /mnt/onboard/.adds/koreader/koreader.sh

# Plato
pkill -9 nickel; /mnt/onboard/.adds/plato/plato.sh

```

```bash
[root@kobo ~]# qndb -a
The following methods and their arguments can be called:
    bwmOpenBrowser
    bwmOpenBrowser <bool> modal
    bwmOpenBrowser <bool> modal, <QString> url
    bwmOpenBrowser <bool> modal, <QString> url, <QString> css
    dlgConfirmAccept <QString> title, <QString> body, <QString> acceptText
    dlgConfirmAcceptReject <QString> title, <QString> body, <QString> acceptText, <QString> rejectText
    dlgConfirmClose
    dlgConfirmCreate
    dlgConfirmCreate <bool> createLineEdit
    dlgConfirmNoBtn <QString> title, <QString> body
    dlgConfirmReject <QString> title, <QString> body, <QString> rejectText
    dlgConfirmSetAccept <QString> acceptText
    dlgConfirmSetBody <QString> body
    dlgConfirmSetLEPassword <bool> password
    dlgConfirmSetLEPlaceholder <QString> placeholder
    dlgConfirmSetModal <bool> modal
    dlgConfirmSetProgress <int> min, <int> max, <int> val
    dlgConfirmSetProgress <int> min, <int> max, <int> val, <QString> format
    dlgConfirmSetReject <QString> rejectText
    dlgConfirmSetTitle <QString> title
    dlgConfirmShow
    dlgConfirmShowClose <bool> show
    mwcHome
    mwcToast <int> toastDuration, <QString> msgMain
    mwcToast <int> toastDuration, <QString> msgMain, <QString> msgSub
    ndbCurrentView
    ndbFirmwareVersion
    ndbNickelClassDetails <QString> staticMmetaobjectSymbol
    ndbNickelWidgets
    ndbSignalConnected <QString> signalName
    ndbVersion
    nsAutoUSBGadget <QString> action
    nsForceWifi <QString> action
    nsInvert <QString> action
    nsLockscreen <QString> action
    nsScreenshots <QString> action
    pfmRescanBooks
    pfmRescanBooksFull
    pwrReboot
    pwrShutdown
    pwrSleep
    wfmConnectWireless
    wfmConnectWirelessSilently
    wfmSetAirplaneMode <QString> action

The following signals and their 'return' value can be waited for:
    dlgConfirmResult <int> result
    dlgConfirmTextInput <QString> input
    ndbViewChanged <QString> newView
    pfmAboutToConnect
    pfmDoneProcessing
    rvPageChanged <int> pageNum
    wmLinkQualityForConnectedNetwork <double> quality
    wmMacAddressAvailable <QString> mac
    wmNetworkConnected
    wmNetworkDisconnected
    wmNetworkFailedToConnect
    wmNetworkForgotten
    wmScanningAborted
    wmScanningFinished
    wmScanningStarted
    wmTryingToConnect
    wmWifiEnabled <bool> enabled
```


---


## About Firmware Updates

> [!WARNING]
> Official firmware updates will **disable KFMon**, requiring a fresh re-installation of its `KoboRoot.tgz`.
> **NickelMenu** and **NickelDBus** generally survive firmware updates without modification.

> [!IMPORTANT]
> *Qt6 Note:* KoboOS 5.x releases built on Qt6 require Qt6-compiled versions of `libnm.so` and `libndb.so`.

---

## About Clean-Uninstalling

To completely strip custom launchers:

1. Copy the official `KFMon` uninstall package or an empty `KoboRoot.tgz` into `/.kobo/`.
2. Delete `/mnt/onboard/.adds/koreader`, `/mnt/onboard/.adds/plato`, `/mnt/onboard/.adds/nm`, and `/usr/bin/qndb`.
3. Reboot the device.

---

## Credits & Resources

* **KOReader**: [https://github.com/koreader/koreader](https://github.com/koreader/koreader)
* **NickelMenu**: [https://github.com/pgaskin/NickelMenu](https://github.com/pgaskin/NickelMenu)
* **NickelDBus**: [https://github.com/shermp/NickelDBus](https://github.com/shermp/NickelDBus)
* **KFMon**: [https://github.com/NiLuJe/kfmon](https://github.com/NiLuJe/kfmon)
* **Plato**: [https://github.com/baskerville/plato](https://github.com/baskerville/plato)
* **MobileRead Community**: [https://www.mobileread.com/forums/](https://www.mobileread.com/forums/)

