# Bypass Kobo Registration

This module provides a method to skip the mandatory registration screen on a new or factory-reset Kobo e-reader.

## Prerequisites

- A Kobo e-reader.
- A computer with a USB port.

## Steps

1.  Connect the Kobo to your computer via USB.
2.  Locate the `.kobo` directory on the device's internal storage.
3.  Inside `.kobo`, find the `Kobo eReader.conf` file and open it with a text editor.
4.  Add the following line under the `[ApplicationPreferences]` section:
    ```ini
    RegistrationDone=true
