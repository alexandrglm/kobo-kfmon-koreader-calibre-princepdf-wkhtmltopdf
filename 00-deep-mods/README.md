# Deep Mods for Kobo

This directory contains a collection of modules for deep modification of a Kobo e-reader. Each module is self-contained and focuses on a specific task, from bypassing initial registration to setting up a full Linux environment.


Methods used here are adaptations and refinements of an existing work for old Kobo's device, FW and linux kernel (2.x), but updated and tested on modern device and firmware:

-   **DEVICE**:         *Kobo Clara Colour*
-   **FW VERSION**:     *4.45.23697 - 25/05/2026*
-   **Linux Kernel**:   *Linux kobo 4.9.77 #1 SMP PREEMPT e5649aba8-20251107T154948-B1107155140 armv7l GNU/Linux*

---


## Modules

| Module | Description |
| :--- | :--- |
| **00-01-Bypassing-Kobo-Registration** | Steps to bypass the mandatory registration screen on a new or factory-reset Kobo |
| **00-02-Getting-TELNET** | A guide to enable root telnet access to your Kobo, providing a direct shell over WiFi. |
| **00-03-Getting-SSH** | Instructions to compile and add latest Dropbear SSH server binaries  |
| **00-04-Getting-ALPINE-chroot** | A complete walkthrough for creating and running an Alpine Linux chroot environment |

---

## Credits

These guides updates the previous foundational work and scripts from the Kobo hacking community.  

Special thanks to:

-   **Run As Sudo - Ying Tong Li** ([https://yingtongli.me](https://github.com/RunasSudo)) for the early, comprehensive guides on gaining telnet access on the Clara HD.


