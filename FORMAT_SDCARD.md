# Preparing the SD Card for Armbian on Orange Pi Zero 3 using macOS

Writing an Armbian image file (`.img` or `.img.xz`) directly to the SD card using macOS tools will automatically create the necessary BOOT (FAT32) and rootfs (ext4) partitions. This is the recommended method when using macOS.

## Using macOS Tools

You can use either the command-line `dd` tool or a graphical application like Balena Etcher.

1. **Download an Armbian Image:**

    Obtain the desired Armbian `.img.xz` file for the Orange Pi Zero 3.

    * **Official Images:** <https://www.armbian.com/orange-pi-zero-3/> (Usually includes CLI and minimal desktop options)
    * **Specific Builds (e.g., GNOME Desktop):** <https://dl.armbian.com/orangepizero3/Noble_current_gnome/> (Check parent directories for other releases/flavors)
    * **Community Discussion & Builds:** Check the Armbian forum thread for Orange Pi Zero 3 for community feedback, troubleshooting, and potentially alternative builds: <https://forum.armbian.com/topic/29202-orange-pi-zero-3/>

    Note the path to the downloaded `.img.xz` file (e.g., `~/Downloads/Armbian_community_25.5.0-trunk.444_Orangepizero3_noble_current_6.12.23_gnome_desktop.img.xz`).

2. **Identify Your SD Card:**

    Insert the SD card into your Mac (using a reader if necessary). Open **Terminal** and run:

    ```bash
    diskutil list
    ```

    Identify the correct disk identifier for your SD card (e.g., `/dev/diskX`, where X is a number). Look for the disk matching the size of your SD card. **Be absolutely sure you have the correct identifier, as the next step will erase it.**

3. **Unmount the SD Card:**

    Before writing, unmount the SD card to prevent conflicts. Replace `X` with your disk number.

    ```bash
    diskutil unmountDisk /dev/diskX
    ```

4. **Write the Image:**

    **Option A: Using Balena Etcher (Recommended GUI)**

    * Download and install Balena Etcher: <https://www.balena.io/etcher/>
    * Open Etcher.
    * Select the downloaded Armbian `.img.xz` file.
    * Select the correct SD card device (Etcher usually detects it automatically but double-check).
    * Click "Flash!". Etcher handles decompression and writing.

    **Option B: Using `dd` (Command Line - Use with Caution!)**

    * The `.img.xz` file needs to be decompressed first if `dd` doesn't handle it directly (macOS `dd` might not). You can use `xz` if installed (e.g., via Homebrew: `brew install xz`).

        ```bash
        # Decompress the image (creates a .img file)
        xz -dk ~/Downloads/Armbian_community_25.5.0-trunk.444_Orangepizero3_noble_current_6.12.23_gnome_desktop.img.xz
        ```

    * Write the decompressed `.img` file using `dd`. Replace `X` with your disk number. Use `rdiskX` for potentially faster raw disk access. **Triple-check the `of=` parameter.**

        ```bash
        # Example using the decompressed image:
        sudo dd bs=4m if=~/Downloads/Armbian_community_25.5.0-trunk.444_Orangepizero3_noble_current_6.12.23_gnome_desktop.img of=/dev/rdiskX status=progress
        ```

        * `bs=4m`: Sets block size for potentially faster writing.
        * `if=...img`: Input file (the decompressed image).
        * `of=/dev/rdiskX`: Output file (the raw SD card device). **Incorrect device here will wipe the wrong disk!**
        * `status=progress`: Shows progress during writing (requires newer `dd` versions).

5. **Wait for Completion:**

    Writing the image will take several minutes. `dd` provides no feedback until finished unless `status=progress` works. Etcher shows a progress bar.

6. **Eject Safely:**

    Once writing is complete, macOS might show warnings about unreadable disks – this is normal because it can't read the Linux `ext4` partition. Eject the card safely using Finder or Disk Utility.

    ```bash
    diskutil eject /dev/diskX
    ```

The SD card is now ready to boot Armbian on your Orange Pi Zero 3. Using a fresh image should resolve partitioning issues and potentially the `mtdblock4` error.
