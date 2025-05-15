# Orange Pi Zero 3 Initial Setup Guide with Armbian

This guide covers essential post-installation steps after booting your Orange Pi Zero 3 with Armbian for the first time.

## 1. First Login

After booting from your prepared SD card, you can access your Orange Pi Zero 3 using one of these methods:

- **SSH**: Connect via terminal using `ssh root@orangepizero3.local` or `ssh root@IP_ADDRESS`
- **Serial Console**: Connect via UART pins if available
- **HDMI**: Connect a monitor and USB keyboard directly

Default credentials:
- Username: `root`
- Password: `1234` (you'll be prompted to change this on first login)

## 2. Initial Security Setup

On first login, you'll be asked to:
1. Change the root password
2. Create a regular user account
3. Configure your timezone and locale

Example SSH session:
