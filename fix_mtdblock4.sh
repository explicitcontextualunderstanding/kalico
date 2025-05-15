#!/bin/bash

# Fix MTDBlock4 mount failure for Orange Pi Zero 3
# This script addresses the specific "failed to mount /mtdblock4" error

# Text formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if run as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}This script must be run as root. Please use sudo.${NC}"
    exit 1
fi

echo -e "${BLUE}=== FIXING MTDBLOCK4 MOUNT ERROR ===${NC}"
echo -e "${YELLOW}This script will fix the 'failed to mount /mtdblock4' error on Orange Pi Zero 3.${NC}"

# Mount point for the SD card
MOUNT_POINT="/mnt/sdcard"
mkdir -p "$MOUNT_POINT"

# Ask user for SD card device
echo -e "\n${YELLOW}Please enter your SD card device name (e.g., mmcblk0 or sdb):${NC}"
read -p "Device: " SD_DEVICE

# Basic validation
if [ -z "$SD_DEVICE" ]; then
    echo -e "${RED}Empty device name provided. Exiting.${NC}"
    exit 1
fi

# Always add /dev/ prefix if not present
if [[ ! "$SD_DEVICE" == /dev/* ]]; then
    SD_DEVICE="/dev/$SD_DEVICE"
    echo -e "${YELLOW}Adding /dev prefix. Using ${SD_DEVICE}${NC}"
fi

# Determine partition scheme
if ls -la ${SD_DEVICE}p* >/dev/null 2>&1; then
    ROOT_PARTITION="${SD_DEVICE}p2"
    echo -e "${GREEN}Detected eMMC/MMC-style partitioning (p1, p2)${NC}"
elif ls -la ${SD_DEVICE}[1-9] >/dev/null 2>&1; then
    ROOT_PARTITION="${SD_DEVICE}2"
    echo -e "${GREEN}Detected SD/USB-style partitioning (1, 2)${NC}"
else
    echo -e "${RED}Could not determine partition scheme. Please specify root partition:${NC}"
    read -p "Root partition (e.g., /dev/mmcblk0p2): " ROOT_PARTITION
fi

# Check if root partition exists
if [ ! -e "$ROOT_PARTITION" ]; then
    echo -e "${RED}Root partition $ROOT_PARTITION does not exist.${NC}"
    echo -e "${YELLOW}Available partitions:${NC}"
    ls -la ${SD_DEVICE}* | grep -v "$(basename $SD_DEVICE)$"
    echo -e "${YELLOW}Enter the full path to the root partition:${NC}"
    read -p "Root partition: " ROOT_PARTITION
    
    if [ ! -e "$ROOT_PARTITION" ]; then
        echo -e "${RED}Root partition still not found. Exiting.${NC}"
        exit 1
    fi
fi

# Mount the root partition
echo -e "\n${YELLOW}Mounting root partition ${ROOT_PARTITION}...${NC}"
mount "$ROOT_PARTITION" "$MOUNT_POINT" || {
    echo -e "${RED}Failed to mount root partition. Trying filesystem detection...${NC}"
    
    # Try with different filesystem types
    for fs_type in ext4 ext3 ext2 f2fs btrfs; do
        echo -e "${YELLOW}Trying with $fs_type filesystem...${NC}"
        mount -t $fs_type "$ROOT_PARTITION" "$MOUNT_POINT" && {
            echo -e "${GREEN}Successfully mounted as $fs_type filesystem${NC}"
            break
        }
    done
    
    # Check if mount was successful
    if ! mount | grep -q "$MOUNT_POINT"; then
        echo -e "${RED}Failed to mount root partition. Exiting.${NC}"
        exit 1
    fi
}

# Check if etc/fstab exists in the mounted filesystem
if [ ! -f "${MOUNT_POINT}/etc/fstab" ]; then
    echo -e "${RED}This doesn't look like a valid root partition (no /etc/fstab found).${NC}"
    echo -e "${YELLOW}Contents of mounted filesystem:${NC}"
    ls -la "$MOUNT_POINT"
    echo -e "${RED}Exiting.${NC}"
    umount "$MOUNT_POINT" 2>/dev/null
    exit 1
fi

# 1. Fix /etc/fstab to remove or comment the mtdblock4 entry
echo -e "\n${YELLOW}Checking fstab for mtdblock4 entries...${NC}"
if grep -q "mtdblock4" "${MOUNT_POINT}/etc/fstab"; then
    echo -e "${GREEN}Found mtdblock4 entries in fstab. Creating backup and fixing...${NC}"
    cp "${MOUNT_POINT}/etc/fstab" "${MOUNT_POINT}/etc/fstab.backup.$(date +%Y%m%d%H%M%S)"
    sed -i '/mtdblock4/s/^/#/' "${MOUNT_POINT}/etc/fstab"
    echo -e "${GREEN}Commented out mtdblock4 entries in fstab.${NC}"
    echo -e "${YELLOW}Original fstab saved as ${MOUNT_POINT}/etc/fstab.backup.$(date +%Y%m%d%H%M%S)${NC}"
    
    echo -e "${GREEN}Updated fstab contents:${NC}"
    cat "${MOUNT_POINT}/etc/fstab"
else
    echo -e "${YELLOW}No mtdblock4 entries found in fstab.${NC}"
    
    echo -e "${GREEN}Current fstab contents:${NC}"
    cat "${MOUNT_POINT}/etc/fstab"
fi

# 2. Create a bootloader hook script to ensure mtdblock module is loaded
echo -e "\n${YELLOW}Creating mtdblock boot script...${NC}"
mkdir -p "${MOUNT_POINT}/etc/initramfs-tools/scripts/init-bottom/"
cat > "${MOUNT_POINT}/etc/initramfs-tools/scripts/init-bottom/mtdblock-fix" << 'EOF'
#!/bin/sh

PREREQ=""

prereqs()
{
    echo "$PREREQ"
}

case $1 in
prereqs)
    prereqs
    exit 0
    ;;
esac

# Ensure mtdblock module is loaded
modprobe mtdblock 2>/dev/null || true

# Create mtdblock device nodes if missing
for i in $(seq 0 10); do
    [ ! -e "/dev/mtdblock$i" ] && mknod "/dev/mtdblock$i" b 31 $i
done

exit 0
EOF

chmod +x "${MOUNT_POINT}/etc/initramfs-tools/scripts/init-bottom/mtdblock-fix"
echo -e "${GREEN}Created mtdblock boot initialization script.${NC}"

# 3. Create systemd service to handle mtdblock4 at boot
echo -e "\n${YELLOW}Creating systemd service for mtdblock4...${NC}"
mkdir -p "${MOUNT_POINT}/etc/systemd/system/"
cat > "${MOUNT_POINT}/etc/systemd/system/mtdblock-fix.service" << 'EOF'
[Unit]
Description=Fix MTDBlock devices at boot
DefaultDependencies=no
After=local-fs.target
Before=sysinit.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'modprobe mtdblock; for i in $(seq 0 10); do [ ! -e "/dev/mtdblock$i" ] && mknod "/dev/mtdblock$i" b 31 $i; done'
RemainAfterExit=yes

[Install]
WantedBy=sysinit.target
EOF

# 4. Enable the systemd service
mkdir -p "${MOUNT_POINT}/etc/systemd/system/sysinit.target.wants/"
ln -sf "/etc/systemd/system/mtdblock-fix.service" "${MOUNT_POINT}/etc/systemd/system/sysinit.target.wants/mtdblock-fix.service"

echo -e "${GREEN}Created and enabled mtdblock-fix systemd service.${NC}"

# 5. Create a more comprehensive fix script
echo -e "\n${YELLOW}Creating comprehensive fix script in /usr/local/sbin...${NC}"
mkdir -p "${MOUNT_POINT}/usr/local/sbin/"
cat > "${MOUNT_POINT}/usr/local/sbin/fix-mtdblock.sh" << 'EOF'
#!/bin/bash

# Comprehensive fix for mtdblock4 mount issues
echo "Fixing mtdblock device nodes..."

# Load necessary modules
modprobe mtd 2>/dev/null || true
modprobe mtdblock 2>/dev/null || true
modprobe mtdchar 2>/dev/null || true

# Create mtdblock devices if missing
echo "Creating mtdblock devices if missing..."
for i in $(seq 0 10); do
    if [ ! -e "/dev/mtdblock$i" ]; then
        echo "Creating /dev/mtdblock$i"
        mknod "/dev/mtdblock$i" b 31 $i
    fi
done

# Create mtd devices if missing
echo "Creating mtd devices if missing..."
for i in $(seq 0 10); do
    if [ ! -e "/dev/mtd$i" ]; then
        echo "Creating /dev/mtd$i"
        mknod "/dev/mtd$i" c 90 $((i*2))
    fi
done

# Fix fstab if needed
if grep -q "mtdblock4" "/etc/fstab" && ! grep -q "^#.*mtdblock4" "/etc/fstab"; then
    echo "Fixing fstab entries for mtdblock4..."
    sed -i '/mtdblock4/s/^/#/' /etc/fstab
fi

echo "MTDBlock fix completed. Please reboot the system."
EOF

chmod +x "${MOUNT_POINT}/usr/local/sbin/fix-mtdblock.sh"
echo -e "${GREEN}Created comprehensive fix script at /usr/local/sbin/fix-mtdblock.sh${NC}"

# 6. Create a reference script to understand the issue
cat > "${MOUNT_POINT}/root/mtdblock4-explanation.txt" << 'EOF'
EXPLANATION: MTDBlock4 Mount Failure on Orange Pi Zero 3

The "failed to mount /mtdblock4" error typically occurs because:

1. The Armbian Linux kernel expects MTD (Memory Technology Device) devices,
   which are commonly used for accessing raw flash memory.

2. In Orange Pi Zero 3 with Armbian, mtdblock4 is often referenced in fstab
   but the necessary device nodes might be missing.

3. The problem usually stems from one or more of these causes:
   - Missing mtdblock kernel module
   - Missing device nodes in /dev
   - Incorrect fstab entries
   - Timing issues during boot

The fixes applied:
1. Commented out mtdblock entries in /etc/fstab
2. Created a boot-time script to ensure the mtdblock module is loaded
3. Created a systemd service to create necessary device nodes at boot
4. Added a comprehensive fix script at /usr/local/sbin/fix-mtdblock.sh

If you still encounter issues after a reboot, run:
   sudo /usr/local/sbin/fix-mtdblock.sh

Reference: Many Armbian users encounter this issue due to the specific way
the system handles flash memory devices on Allwinner H616 SOCs.
EOF

echo -e "${GREEN}Created explanation document at /root/mtdblock4-explanation.txt${NC}"

# 7. Create a check script to run after boot
cat > "${MOUNT_POINT}/usr/local/sbin/check-mtdblock.sh" << 'EOF'
#!/bin/bash

echo "Checking MTDBlock device status..."

# Check for modules
echo -n "MTD module loaded: "
lsmod | grep -q mtd && echo "Yes" || echo "No"

echo -n "MTDBlock module loaded: "
lsmod | grep -q mtdblock && echo "Yes" || echo "No"

# Check for device nodes
echo -n "MTDBlock4 device exists: "
[ -e "/dev/mtdblock4" ] && echo "Yes" || echo "No"

# Check fstab
echo -n "MTDBlock4 in fstab (active): "
grep -q "mtdblock4" /etc/fstab && ! grep -q "^#.*mtdblock4" /etc/fstab && echo "Yes" || echo "No"

# Check mount status
echo -n "MTDBlock4 currently mounted: "
mount | grep -q "mtdblock4" && echo "Yes" || echo "No"

echo "Check complete."
EOF

chmod +x "${MOUNT_POINT}/usr/local/sbin/check-mtdblock.sh"
echo -e "${GREEN}Created diagnostic script at /usr/local/sbin/check-mtdblock.sh${NC}"

# Update rc.local to run the fix at boot
echo -e "\n${YELLOW}Updating system startup files...${NC}"

# Create new rc.local content
cat > "${MOUNT_POINT}/etc/rc.local.new" << 'EOF'
#!/bin/sh -e
#
# rc.local - executed at the end of each multiuser runlevel
#

# Fix for mtdblock4 issues
if [ ! -e "/dev/mtdblock4" ] && grep -q "mtdblock4" /etc/fstab; then
    echo "Creating missing mtdblock devices..."
    for i in $(seq 0 10); do
        [ ! -e "/dev/mtdblock$i" ] && mknod "/dev/mtdblock$i" b 31 $i
    done
    # Comment out mtdblock4 in fstab if it's causing problems
    sed -i '/mtdblock4/s/^/#/' /etc/fstab
fi

exit 0
EOF

# Create/update rc.local
if [ -f "${MOUNT_POINT}/etc/rc.local" ]; then
    echo -e "${YELLOW}Updating existing rc.local...${NC}"
    mv "${MOUNT_POINT}/etc/rc.local" "${MOUNT_POINT}/etc/rc.local.backup.$(date +%Y%m%d%H%M%S)"
    mv "${MOUNT_POINT}/etc/rc.local.new" "${MOUNT_POINT}/etc/rc.local"
else
    echo -e "${YELLOW}Creating new rc.local...${NC}"
    mv "${MOUNT_POINT}/etc/rc.local.new" "${MOUNT_POINT}/etc/rc.local"
fi

chmod +x "${MOUNT_POINT}/etc/rc.local"
echo -e "${GREEN}Updated rc.local to include mtdblock4 fix${NC}"

# 8. Update kernel command line if possible
if [ -f "${MOUNT_POINT}/boot/armbianEnv.txt" ]; then
    echo -e "\n${YELLOW}Updating Armbian environment to help with MTD issues...${NC}"
    # Backup the file first
    cp "${MOUNT_POINT}/boot/armbianEnv.txt" "${MOUNT_POINT}/boot/armbianEnv.txt.backup.$(date +%Y%m%d%H%M%S)"
    
    # Add modules to load early if not already present
    if ! grep -q "^extraargs=" "${MOUNT_POINT}/boot/armbianEnv.txt"; then
        echo "extraargs=mtdblock.mtd_part_parser=1" >> "${MOUNT_POINT}/boot/armbianEnv.txt"
    else
        sed -i 's/^extraargs=\(.*\)/extraargs=\1 mtdblock.mtd_part_parser=1/' "${MOUNT_POINT}/boot/armbianEnv.txt"
    fi
    
    echo -e "${GREEN}Updated armbianEnv.txt${NC}"
fi

# Unmount
echo -e "\n${YELLOW}Unmounting ${MOUNT_POINT}...${NC}"
sync  # Ensure all writes are complete
umount "$MOUNT_POINT" || {
    echo -e "${RED}Failed to unmount cleanly. Forcing...${NC}"
    umount -f "$MOUNT_POINT" 2>/dev/null || echo -e "${RED}Forced unmount failed. You may need to reboot.${NC}"
}

echo -e "\n${GREEN}=== MTDBlock4 fix has been applied! ===${NC}"
echo -e "${YELLOW}Please reboot your Orange Pi Zero 3 for the changes to take effect.${NC}"
echo -e "${YELLOW}If you still encounter the issue after reboot, run:${NC}"
echo -e "${GREEN}  sudo /usr/local/sbin/fix-mtdblock.sh${NC}"
echo -e "\n${YELLOW}To check the status of mtdblock devices after booting, run:${NC}"
echo -e "${GREEN}  sudo /usr/local/sbin/check-mtdblock.sh${NC}"
echo -e "\n${YELLOW}This script has:${NC}"
echo -e "  1. ${GREEN}Commented out problematic mtdblock4 entries in /etc/fstab${NC}"
echo -e "  2. ${GREEN}Created tools to ensure mtdblock devices are created at boot${NC}"
echo -e "  3. ${GREEN}Added startup scripts to handle the mtdblock issue${NC}"
echo -e "  4. ${GREEN}Provided documentation about the issue${NC}"
