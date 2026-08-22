# Bypassing Kobo Registration

This guide explains how to bypass the **mandatory Kobo account registration** on a factory-reset or newly configured Kobo.

> [!NOTE]
> **Source:** [yingtongli.me](https://yingtongli.me/blog/2018/07/30/kobo-rego.html)
>
> Confirmed working on **Kobo Clara Colour** in August 2026

* The Kobo's **sync functionality will not work normally**, because the dummy user is not associated with a real Kobo account.

* The device can still **check for and install firmware updates**.

---

## Steps

### 1. Start the Kobo

Turn on the Kobo and proceed until you reach:

> **Welcome to Kobo!**

Do **not** connect the device to Wi-Fi.

Instead, select:

> **Don't have a WiFi network?**

---

### 2. Connect the Kobo via USB

Connect the Kobo to your computer using a USB cable.

The internal storage should appear as a removable drive.

---

### 3. Locate `KoboReader.sqlite`

Open the Kobo's internal storage and navigate to:

```text
.kobo/
```

> [!NOTE]
> The `.kobo` directory may be hidden by default. Enable the display of hidden files if necessary.

Locate:

```text
KoboReader.sqlite
```

---

### 4. Install SQLite

You need the `sqlite3` command-line tool.

**Linux / macOS**

`sqlite3` is usually available through the system package manager.

**Windows**

Download the **SQLite command-line tools** from the [official SQLite website](https://www.sqlite.org/download.html).

---

### 5. Open the Database

Open a terminal in the directory containing `KoboReader.sqlite` and run:

```bash
sqlite3 KoboReader.sqlite
```

You should now see the SQLite prompt:

```text
sqlite>
```

---

### 6. Insert a Dummy User

At the SQLite prompt, execute:

```sql
INSERT INTO user(UserID,UserKey) VALUES('1','');
```

This creates the dummy user record required to bypass the registration process.

---

### 7. Exit SQLite

Exit the SQLite shell with:

```sql
.exit
```

---

### 8. Safely Eject the Kobo

Safely eject the Kobo's internal storage from your computer.

Once the device has been safely unmounted, disconnect the USB cable.

---

### 9. Complete the Setup

The Kobo should now continue past the registration screen as if it had already been registered.

The following features remain available:

* Reading and library management.
* Beta features, including the web browser.
* Firmware updates.
* Other normal device functionality.

---

## 10.  Lock the Database

> [!WARNING]
> A firmware update or forced synchronization **may modify the database** and remove the dummy user entry.

To prevent the database from being modified, you can make it immutable.

### Make the Database Immutable

From the Kobo via SSH/Telnet:

```bash
chattr +i /mnt/onboard/.kobo/KoboReader.sqlite
```

Alternatively, run the command from your computer if the Kobo's storage is mounted and the filesystem supports the operation:

```bash
chattr +i /mnt/onboard/.kobo/KoboReader.sqlite
```

The `chattr +i` flag makes the file **immutable**, preventing it from being modified, deleted, or replaced.

### Unlock the Database

If you later need to modify the database legitimately, remove the immutable flag:

```bash
chattr -i /mnt/onboard/.kobo/KoboReader.sqlite
```

> [!IMPORTANT]
> Unlock the database before performing operations that need to modify `KoboReader.sqlite`.

---


