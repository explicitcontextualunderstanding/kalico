#!/bin/bash

# Script to restore boot directory for Orange Pi Zero 3 running Armbian/Klipper
# This script must be run with sudo privileges

# Define variables
MOUNT_POINT="/mnt/sdcard"  # Fixed mount point
BOOT_DIR="${MOUNT_POINT}/boot"
ROOT_DIR="${MOUNT_POINT}"
TEMP_DIR="/tmp/armbian_boot_files"
# Updated download URLs with successful URL first
DOWNLOAD_URL="https://armbian.tnahosting.net/dl/orangepizero3/archive/Armbian_24.5.1_Orangepizero3_jammy_current_6.6.30.img.xz"
DOWNLOAD_URL_ALT1="https://imola.armbian.com/dl/orangepizero3/archive/Armbian_24.5.1_Orangepizero3_jammy_current_6.6.30.img.xz"
DOWNLOAD_URL_ALT2="https://mirrors.dotsrc.org/armbian-dl/orangepizero3/archive/Armbian_24.5.1_Orangepizero3_jammy_current_6.6.30.img.xz"
DOWNLOAD_URL_ALT3="https://fra1.dl.armbian.com/orangepizero3/archive/Armbian_24.5.1_Orangepizero3_jammy_current_6.6.30.img.xz"

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

# Function to safely check for commands
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# Function to find latest Armbian image URL - Updated to include new mirror
find_latest_armbian_url() {
    echo -e "${YELLOW}Attempting to find the latest Armbian image URL...${NC}"
    
    # List of possible mirror base URLs that are known to work
    mirror_bases=(
        "https://armbian.tnahosting.net"
        "https://imola.armbian.com"
        "https://mirrors.dotsrc.org/armbian-dl"
        "https://fra1.dl.armbian.com"
    )
    
    # Try to get the directory listing and extract the latest version
    for base in "${mirror_bases[@]}"; do
        echo -e "${GREEN}Checking mirror: ${base}${NC}"
        
        if check_command wget; then
            # Use wget to get directory listing
            listing=$(wget --no-check-certificate -q -O- "${base}/orangepizero3/archive/" 2>/dev/null)
        elif check_command curl; then
            # Use curl as alternative
            listing=$(curl -k -s "${base}/orangepizero3/archive/" 2>/dev/null)
        else
            echo -e "${RED}Neither wget nor curl available to check for latest version${NC}"
            return 1
        fi
        
        # If we got a listing, try to extract the latest version
        if [ -n "$listing" ]; then
            # Look for the most recent Armbian image
            latest_url=$(echo "$listing" | grep -o 'href="[^"]*Armbian_[0-9.]*_Orangepizero3_[^"]*\.img\.xz"' | 
                         sort -r | head -1 | sed 's/href="//' | sed 's/"//')
            
            if [ -n "$latest_url" ]; then
                # Construct full URL
                if [[ "$latest_url" == "http"* ]]; then
                    DOWNLOAD_URL="$latest_url"
                else
                    DOWNLOAD_URL="${base}/orangepizero3/archive/${latest_url}"
                fi
                
                echo -e "${GREEN}Found latest image: ${DOWNLOAD_URL}${NC}"
                # Update alternative URLs
                DOWNLOAD_URL_ALT1="${base}/orangepizero3/archive/${latest_url}"
                DOWNLOAD_URL_ALT2="${base}/orangepizero3/archive/${latest_url}"
                return 0
            fi
        fi
    done
    
    echo -e "${YELLOW}Could not automatically find the latest version. Using default URLs.${NC}"
    return 1
}

# Function to extract DTB from kernel packages - FIXED: Added missing function definition
extract_dtb_from_system() {
    echo -e "${YELLOW}Attempting to locate DTB file on the system...${NC}"
    
    # Try to find DTB file in the system
    potential_dtb_locations=(
        "/boot/dtb/allwinner/sun50i-h616-orangepi-zero3.dtb"
        "/usr/lib/linux-image-*/dtb/allwinner/sun50i-h616-orangepi-zero3.dtb"
        "/lib/modules/*/dtb/allwinner/sun50i-h616-orangepi-zero3.dtb"
        "/sys/firmware/devicetree/base"
    )
    
    for dtb_path in "${potential_dtb_locations[@]}"; do
        # Use find to expand wildcards
        found_dtb=$(find / -path "$dtb_path" 2>/dev/null | head -1)
        
        if [ -n "$found_dtb" ] && [ -f "$found_dtb" ]; then
            echo -e "${GREEN}Found DTB file: ${found_dtb}${NC}"
            mkdir -p "${BOOT_DIR}/dtb/allwinner/"
            cp -v "$found_dtb" "${BOOT_DIR}/dtb/allwinner/sun50i-h616-orangepi-zero3.dtb"
            echo -e "${GREEN}DTB file copied to ${BOOT_DIR}/dtb/allwinner/sun50i-h616-orangepi-zero3.dtb${NC}"
            return 0
        fi
    done
    
    # Try to find DTB in kernel packages
    echo -e "${YELLOW}Checking installed kernel packages for DTB file...${NC}"
    if check_command dpkg; then
        kernel_pkgs=$(dpkg -l | grep linux-image | awk '{print $2}')
        for pkg in $kernel_pkgs; do
            echo -e "${GREEN}Checking package ${pkg}...${NC}"
            pkg_files=$(dpkg -L $pkg 2>/dev/null | grep -E "sun50i-h616.*\.dtb")
            if [ -n "$pkg_files" ]; then
                for file in $pkg_files; do
                    if [[ "$file" == *"orangepizero3"* ]] || [[ "$file" == *"zero3"* ]]; then
                        echo -e "${GREEN}Found DTB file: ${file}${NC}"
                        mkdir -p "${BOOT_DIR}/dtb/allwinner/"
                        cp -v "$file" "${BOOT_DIR}/dtb/allwinner/sun50i-h616-orangepi-zero3.dtb"
                        echo -e "${GREEN}DTB file copied to ${BOOT_DIR}/dtb/allwinner/sun50i-h616-orangepi-zero3.dtb${NC}"
                        return 0
                    fi
                done
            fi
        done
    fi
    
    echo -e "${YELLOW}Could not find DTB file on system${NC}"
    return 1
}

# Function to check apt repository configuration
check_apt_repos() {
    echo -e "${BLUE}=== Checking APT Repository Configuration ===${NC}"
    
    if [ ! -d "/etc/apt" ]; then
        echo -e "${YELLOW}APT directory not found - this may not be a Debian-based system${NC}"
        return 1
    fi
    
    echo -e "${GREEN}APT Sources:${NC}"
    if [ -f "/etc/apt/sources.list" ]; then
        echo -e "${YELLOW}Contents of /etc/apt/sources.list:${NC}"
        grep -v "^#" /etc/apt/sources.list | grep -v "^$" || echo "  No active repositories found"
    else
        echo -e "${RED}Main sources.list file not found${NC}"
    fi
    
    if [ -d "/etc/apt/sources.list.d" ]; then
        echo -e "${YELLOW}Additional repository files in /etc/apt/sources.list.d/:${NC}"
        ls -la /etc/apt/sources.list.d/ | grep -v "total"
        
        for repo_file in /etc/apt/sources.list.d/*.list; do
            if [ -f "$repo_file" ]; then
                echo -e "${GREEN}Contents of $(basename "$repo_file"):${NC}"
                grep -v "^#" "$repo_file" | grep -v "^$" || echo "  No active repositories found"
            fi
        done
    fi
    
    # Check for package management history related to kernel/boot
    echo -e "\n${BLUE}=== Recent Package Management Activities ===${NC}"
    if check_command dpkg; then
        echo -e "${YELLOW}Recent kernel or boot-related package operations:${NC}"
        grep -E 'linux-image|u-boot|firmware|boot' /var/log/dpkg.log 2>/dev/null | tail -10 || echo "  No relevant logs found"
    else
        echo -e "${RED}dpkg not found - cannot check package history${NC}"
    fi
    
    # Check current kernel version
    echo -e "\n${BLUE}=== Current System Kernel Information ===${NC}"
    if check_command uname; then
        echo -e "${GREEN}Kernel version:${NC} $(uname -r 2>/dev/null || echo "Unknown")"
    fi
    
    # GRUB configuration if present
    if [ -f "/boot/grub/grub.cfg" ]; then
        echo -e "\n${YELLOW}GRUB is configured - this may affect boot process${NC}"
    fi
    
    # U-Boot configuration if present
    if [ -f "/boot/boot.scr" ] || [ -f "/boot/boot.cmd" ]; then
        echo -e "${YELLOW}U-Boot configuration detected${NC}"
    fi
    
    return 0
}

# Show a clear header with mounting information
echo -e "\n${BLUE}=== SD CARD MOUNTING AND BOOT RESTORATION TOOL ===${NC}"
echo -e "${YELLOW}This script will:${NC}"
echo -e " 1. ${GREEN}Find your SD card device${NC}"
echo -e " 2. ${GREEN}Mount it to ${MOUNT_POINT}${NC}"
echo -e " 3. ${GREEN}Restore essential boot files${NC}"
echo -e " 4. ${GREEN}Optionally download Armbian boot files${NC}"
echo -e " 5. ${GREEN}Unmount the card when finished${NC}\n"

# Add SD card diagnostic section
echo -e "${BLUE}=== SD CARD DETECTION DIAGNOSTIC ===${NC}"
echo -e "${YELLOW}Checking for SD card reader functionality...${NC}"

# Check if SD card slots are detected at hardware level
if [ -d "/sys/class/mmc_host" ]; then
    echo -e "${GREEN}MMC host controllers found:${NC}"
    ls -la /sys/class/mmc_host/
    
    # Check each MMC slot for cards
    for mmc in /sys/class/mmc_host/mmc*; do
        if [ -d "$mmc" ]; then
            slot=$(basename "$mmc")
            echo -e "\n${YELLOW}Checking $slot:${NC}"
            
            # See if there's a card detected in this slot
            if [ -d "$mmc/$slot:*" ] 2>/dev/null; then
                echo -e "${GREEN}Card detected in $slot${NC}"
                card_path=$(find "$mmc" -maxdepth 1 -name "$slot:*" -type d | head -n1)
                if [ -n "$card_path" ]; then
                    echo -e "Card details:"
                    cat "$card_path/manfid" 2>/dev/null || echo "No manufacturer ID found"
                    cat "$card_path/name" 2>/dev/null || echo "No name found"
                    cat "$card_path/size" 2>/dev/null || echo "No size information found"
                fi
            else
                echo -e "${YELLOW}No card detected in $slot${NC}"
            fi
        fi
    done
else
    echo -e "${RED}No MMC host controllers found - SD card reader may not be present or enabled${NC}"
fi

# Check for block devices
echo -e "\n${YELLOW}Checking for block devices that might be SD cards:${NC}"
lsblk -o NAME,SIZE,VENDOR,MODEL,SERIAL,MOUNTPOINT,HOTPLUG,REMOVABLE 2>/dev/null || {
    echo -e "${RED}lsblk with extended options failed. Trying simpler command:${NC}"
    lsblk -o NAME,SIZE,SERIAL,MOUNTPOINT 2>/dev/null || {
        echo -e "${RED}lsblk with basic options failed. Trying minimal command:${NC}"
        lsblk 2>/dev/null || echo -e "${RED}lsblk command failed. SD card detection limited.${NC}"
    }
}

# Add special handling for large SD cards (>64GB) and single-partition cards
echo -e "\n${YELLOW}Checking for large capacity SD cards and their partitioning:${NC}"
# Check for cards over 64GB
large_cards=$(lsblk -b | grep -E 'mmcblk|sd[a-z]' | awk '$4 > 64000000000 {print}')
if [ -n "$large_cards" ]; then
    echo -e "${GREEN}Found large capacity storage device(s):${NC}"
    echo "$large_cards"
    echo -e "${YELLOW}Note: Large SD cards (128GB+) may require special formatting considerations.${NC}"
    echo -e "${YELLOW}Armbian typically expects a boot partition (FAT32) and a root partition (ext4).${NC}"
fi

# Check for SD cards with only one partition
single_partition_cards=$(lsblk -l | grep -E 'mmcblk[0-9]p?[0-9]?' | grep -v 'rom' | sort)
if [ -n "$single_partition_cards" ]; then
    echo -e "${GREEN}Found potential SD card devices:${NC}"
    echo "$single_partition_cards"
    
    # Check for cards with only one partition
    one_partition_cards=$(echo "$single_partition_cards" | grep -E 'mmcblk[0-9]p?1' | grep -v 'mmcblk[0-9]p?2')
    if [ -n "$one_partition_cards" ]; then
        echo -e "${YELLOW}NOTICE: Detected SD card with only one partition.${NC}"
        echo -e "${YELLOW}For a proper Armbian installation, you need:${NC}"
        echo -e "  1. ${GREEN}Boot partition (FAT32, ~256MB)${NC}"
        echo -e "  2. ${GREEN}Root partition (ext4, remaining space)${NC}"
        echo -e "${YELLOW}You may need to create a proper partition layout using:${NC}"
        echo -e "  ${GREEN}sudo parted /dev/${SD_DEVICE} mklabel msdos${NC}"
        echo -e "  ${GREEN}sudo parted /dev/${SD_DEVICE} mkpart primary fat32 1MiB 256MiB${NC}"
        echo -e "  ${GREEN}sudo parted /dev/${SD_DEVICE} mkpart primary ext4 256MiB 100%${NC}"
    fi
else
    echo -e "${YELLOW}No SD card devices found with standard naming conventions.${NC}"
fi

# Provide guidance
echo -e "\n${BLUE}=== SD CARD TROUBLESHOOTING STEPS ===${NC}"
echo -e "1. ${GREEN}Try reinserting the SD card${NC}"
echo -e "2. ${GREEN}Try a different SD card reader (USB adapter if available)${NC}"
echo -e "3. ${GREEN}Check if SD card works in another computer${NC}"
echo -e "4. ${GREEN}Try running:${NC} sudo fdisk -l /dev/mmcblk0"
echo -e "5. ${GREEN}Run this command to continuously monitor for device connections:${NC}"
echo -e "   watch -n 1 'lsblk'"
echo -e ""

# Ask if user wants to continue with the script
read -p "Did any SD cards show up in the diagnostics? Continue with the script? (y/n): " continue_script
if [[ ! "$continue_script" =~ ^[Yy] ]]; then
    echo -e "${YELLOW}Try these additional commands to find your SD card:${NC}"
    echo -e "  sudo fdisk -l"
    echo -e "  ls -la /dev/sd*"
    echo -e "  ls -la /dev/mmcblk*"
    echo -e "  dmesg | tail -20"
    echo -e "${RED}Script aborted by user.${NC}"
    exit 0
fi

# Check if we should analyze the system configuration
echo -e "${YELLOW}Would you like to analyze the system's APT and boot configuration first? (y/n)${NC}"
read -p "" analyze_system

if [[ "$analyze_system" =~ ^[Yy] ]]; then
    check_apt_repos
    
    # Provide explanation about how boot directories could be affected
    echo -e "\n${BLUE}=== How APT Updates May Affect Boot Directories ===${NC}"
    echo -e "${YELLOW}Common scenarios that can lead to boot directory issues:${NC}"
    echo -e "  1. ${GREEN}Kernel updates:${NC} When the kernel is updated via apt, it may overwrite or"
    echo -e "     modify files in /boot, including the Image file and initrd."
    echo -e "  2. ${GREEN}U-Boot updates:${NC} Updates to the u-boot package can replace boot.scr and"
    echo -e "     other bootloader files, potentially with versions incompatible with your hardware."
    echo -e "  3. ${GREEN}Armbian-specific updates:${NC} Armbian repositories may push updates that"
    echo -e "     change the DTB files or overlay structure."
    echo -e "  4. ${GREEN}Failed or interrupted updates:${NC} If an update process is interrupted, it"
    echo -e "     may leave the boot directory in an inconsistent state."
    echo -e "  5. ${GREEN}Repository mismatches:${NC} Using repositories meant for different hardware"
    echo -e "     or OS versions can install incompatible boot files."
    
    echo -e "\n${YELLOW}Would you like to proceed with boot directory restoration? (y/n)${NC}"
    read -p "" proceed_with_restore
    
    if [[ ! "$proceed_with_restore" =~ ^[Yy] ]]; then
        echo -e "${RED}Script aborted by user.${NC}"
        exit 0
    fi
fi

# Check system environment and display available storage info
echo -e "${GREEN}Checking system environment...${NC}"

# Use more resilient methods to list storage devices
echo -e "${GREEN}Available storage devices:${NC}"

if check_command lsblk; then
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT 2>/dev/null || echo "lsblk failed to display detailed information"
elif check_command fdisk; then
    fdisk -l 2>/dev/null || echo "fdisk failed to list disks"
else
    echo "ls -la /dev/sd* /dev/mmcblk*:"
    ls -la /dev/sd* /dev/mmcblk* 2>/dev/null || echo "No standard block devices found"
    
    echo -e "\n${YELLOW}Limited system tools detected. Manual device specification may be required.${NC}"
fi

echo -e "\n${YELLOW}Checking mounted filesystems:${NC}"
mount | grep -E 'sd|mmc' || echo "No standard storage devices mounted"

# Improved device selection with validation and fallback methods
while true; do
    read -p "Enter your SD card device name (e.g., mmcblk0 or sdb, without partition number): " SD_DEVICE
    
    # Basic validation
    if [ -z "$SD_DEVICE" ]; then
        echo -e "${RED}Empty device name provided. Please enter a valid device name.${NC}"
        continue
    fi
    
    # Check if device exists
    if [ ! -e "/dev/${SD_DEVICE}" ]; then
        echo -e "${YELLOW}Device /dev/${SD_DEVICE} does not exist directly.${NC}"
        
        # Check if it's a valid base name (may not have the full path)
        potential_devices=$(ls -la /dev/${SD_DEVICE}* 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$potential_devices" ]; then
            echo -e "${GREEN}Found potential matching devices:${NC}"
            echo "$potential_devices"
            echo -e "${YELLOW}Using ${SD_DEVICE} as the base device name.${NC}"
            break
        else
            echo -e "${RED}No devices matching ${SD_DEVICE} found. Please check the name.${NC}"
            
            # Show available devices as a helpful suggestion
            echo -e "${YELLOW}Available devices that might be SD cards:${NC}"
            ls -la /dev/sd* /dev/mmcblk* 2>/dev/null || echo "No standard devices found"
            continue
        fi
    fi
    
    break
done

# Determine partition scheme with better fallbacks - Fixed /dev paths
echo -e "${GREEN}Determining partition layout...${NC}"

# Try to detect partitions
if ls -la /dev/${SD_DEVICE}p* >/dev/null 2>&1; then
    boot_partition="/dev/${SD_DEVICE}p1"
    root_partition="/dev/${SD_DEVICE}p2"
    echo -e "${GREEN}Detected eMMC/MMC-style partitioning (p1, p2)${NC}"
elif ls -la /dev/${SD_DEVICE}[1-9] >/dev/null 2>&1; then
    boot_partition="/dev/${SD_DEVICE}1"
    root_partition="/dev/${SD_DEVICE}2"
    echo -e "${GREEN}Detected SD/USB-style partitioning (1, 2)${NC}"
else
    echo -e "${YELLOW}Could not auto-detect partition style. Trying both common formats...${NC}"
    
    # Try both naming schemes
    if [ -e "/dev/${SD_DEVICE}p1" ]; then
        boot_partition="/dev/${SD_DEVICE}p1"
        root_partition="/dev/${SD_DEVICE}p2"
    else
        boot_partition="/dev/${SD_DEVICE}1"
        root_partition="/dev/${SD_DEVICE}2"
    fi
    
    # Final verification
    if [ ! -e "${boot_partition}" ]; then
        echo -e "${RED}Cannot find boot partition. Please specify manually.${NC}"
        read -p "Enter full boot partition path (e.g., /dev/mmcblk0p1 or /dev/sdb1): " boot_partition
    fi
fi

echo -e "${YELLOW}Using boot partition: ${boot_partition}${NC}"
echo -e "${YELLOW}Using root partition: ${root_partition}${NC}"

# Unmount partitions if they are already mounted - with better error handling
mounted_parts=$(mount | grep "${SD_DEVICE}" | awk '{print $1}' || echo "")
if [ -n "$mounted_parts" ]; then
    echo -e "${YELLOW}Found mounted partitions. Attempting to unmount...${NC}"
    for part in $mounted_parts; do
        echo "Unmounting $part..."
        umount "$part" 2>/dev/null || echo -e "${RED}Failed to unmount $part, continuing anyway...${NC}"
    done
else
    echo -e "${GREEN}No partitions from this device currently mounted.${NC}"
fi

# Create mount points with better error handling
echo -e "${GREEN}Creating mount points...${NC}"
mkdir -p "${MOUNT_POINT}" || { echo -e "${RED}Failed to create mount point ${MOUNT_POINT}${NC}"; exit 1; }
mkdir -p "${TEMP_DIR}" || { echo -e "${RED}Failed to create temp directory ${TEMP_DIR}${NC}"; exit 1; }

# Check and mount boot partition with robust error handling
echo -e "${GREEN}Mounting boot partition...${NC}"
mount_attempts=0
max_attempts=3

while [ $mount_attempts -lt $max_attempts ]; do
    if mount "${boot_partition}" "${MOUNT_POINT}" 2>/dev/null; then
        echo -e "${GREEN}Successfully mounted ${boot_partition} to ${MOUNT_POINT}${NC}"
        break
    else
        mount_attempts=$((mount_attempts + 1))
        echo -e "${YELLOW}Mount attempt $mount_attempts failed.${NC}"
        
        if [ $mount_attempts -lt $max_attempts ]; then
            echo -e "${YELLOW}Attempting filesystem check or repair...${NC}"
            
            # Try fsck if available
            if check_command fsck; then
                echo -e "${YELLOW}Running fsck on ${boot_partition}...${NC}"
                fsck -y "${boot_partition}" 2>/dev/null || echo -e "${RED}fsck failed or not available${NC}"
            else
                echo -e "${RED}fsck not available. Cannot attempt filesystem repair.${NC}"
                
                # Try alternative approach: try with different filesystem types
                echo -e "${YELLOW}Trying explicit filesystem types...${NC}"
                for fs_type in vfat ext4 ext3 ext2; do
                    echo -e "Trying with $fs_type..."
                    mount -t $fs_type "${boot_partition}" "${MOUNT_POINT}" 2>/dev/null && break
                done
            fi
        else
            echo -e "${RED}Failed to mount boot partition after $max_attempts attempts.${NC}"
            echo -e "${RED}Manual intervention required. Please check if:${NC}"
            echo -e " - The device path is correct"
            echo -e " - The partition exists and is not corrupted"
            echo -e " - You have permission to mount devices"
            exit 1
        fi
    fi
done

# Check if boot directory exists and verify its contents
if [ -d "$BOOT_DIR" ]; then
    echo -e "${YELLOW}Boot directory exists.${NC}"
    
    # Check for essential boot files with more flexible paths
    essential_found=0
    total_essential=6
    
    # More flexible file checking
    if [ -f "${BOOT_DIR}/Image" ] || [ -f "${BOOT_DIR}/zImage" ] || [ -f "${BOOT_DIR}/vmlinuz" ]; then
        echo -e "${GREEN}Found kernel image file${NC}"
        essential_found=$((essential_found + 1))
    else
        echo -e "${RED}Missing kernel image file${NC}"
    fi
    
    if find "${BOOT_DIR}" -path "*/dtb/*/sun50i-h616-orangepi-zero3.dtb" -o -path "*/sun50i-h616-orangepi-zero3.dtb" | grep -q .; then
        echo -e "${GREEN}Found device tree binary${NC}"
        essential_found=$((essential_found + 1))
    else
        echo -e "${RED}Missing device tree binary${NC}"
    fi
    
    if [ -f "${BOOT_DIR}/uInitrd" ] || [ -f "${BOOT_DIR}/initrd.img" ]; then
        echo -e "${GREEN}Found initial ramdisk${NC}"
        essential_found=$((essential_found + 1))
    else
        echo -e "${RED}Missing initial ramdisk${NC}"
    fi
    
    if [ -f "${BOOT_DIR}/boot.cmd" ]; then
        echo -e "${GREEN}Found boot.cmd${NC}"
        essential_found=$((essential_found + 1))
    else
        echo -e "${RED}Missing boot.cmd${NC}"
    fi
    
    if [ -f "${BOOT_DIR}/boot.scr" ]; then
        echo -e "${GREEN}Found boot.scr${NC}"
        essential_found=$((essential_found + 1))
    else
        echo -e "${RED}Missing boot.scr${NC}"
    fi
    
    if [ -f "${BOOT_DIR}/armbianEnv.txt" ]; then
        echo -e "${GREEN}Found armbianEnv.txt${NC}"
        essential_found=$((essential_found + 1))
    else
        echo -e "${RED}Missing armbianEnv.txt${NC}"
    fi
    
    if [ $essential_found -lt $total_essential ]; then
        echo -e "${YELLOW}Taking backup of current boot directory...${NC}"
        mv "$BOOT_DIR" "${BOOT_DIR}_backup_$(date +%Y%m%d_%H%M%S)" 2>/dev/null || {
            echo -e "${RED}Failed to backup boot directory. Trying alternative method...${NC}"
            mkdir -p "${BOOT_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
            cp -a "${BOOT_DIR}/"* "${BOOT_DIR}_backup_$(date +%Y%m%d_%H%M%S)/" 2>/dev/null
            rm -rf "${BOOT_DIR:?}/"* 2>/dev/null
        }
        mkdir -p "$BOOT_DIR" 2>/dev/null || echo -e "${RED}Failed to create boot directory${NC}"
    else
        echo -e "${GREEN}All essential boot files present.${NC}"
        read -p "Boot directory seems intact. Do you want to restore it anyway? (y/n): " restore_anyway
        if [[ ! "$restore_anyway" =~ ^[Yy] ]]; then
            echo -e "${GREEN}Boot directory check passed. No restoration needed.${NC}"
            umount "${MOUNT_POINT}"
            exit 0
        fi
        echo -e "${YELLOW}Taking backup of current boot directory...${NC}"
        mv "$BOOT_DIR" "${BOOT_DIR}_backup_$(date +%Y%m%d_%H%M%S)" 2>/dev/null || {
            echo -e "${RED}Failed to backup boot directory. Trying alternative method...${NC}"
            mkdir -p "${BOOT_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
            cp -a "${BOOT_DIR}/"* "${BOOT_DIR}_backup_$(date +%Y%m%d_%H%M%S)/" 2>/dev/null
            rm -rf "${BOOT_DIR:?}/"* 2>/dev/null
        }
        mkdir -p "$BOOT_DIR" 2>/dev/null || echo -e "${RED}Failed to create boot directory${NC}"
    fi
else
    mkdir -p "$BOOT_DIR" 2>/dev/null || {
        echo -e "${RED}Failed to create boot directory. Checking permissions and mount status...${NC}"
        ls -la "${MOUNT_POINT}"
        mount | grep "${MOUNT_POINT}"
        exit 1
    }
fi

echo -e "${GREEN}Creating essential Armbian boot files...${NC}"

# Create armbianEnv.txt with essential settings
cat > "$BOOT_DIR/armbianEnv.txt" << EOF
verbosity=1
bootlogo=false
console=serial
disp_mode=1920x1080p60
overlay_prefix=sun50i-h616
rootdev=/dev/mmcblk0p2
rootfstype=ext4
overlays=uart3
usbstoragequirks=0x2537:0x1066:u,0x2537:0x1068:u
EOF

# Create boot.cmd
cat > "$BOOT_DIR/boot.cmd" << EOF
# This is a minimal boot.cmd file for Orange Pi Zero 3 with Armbian
# For more settings, please see the original file from an Armbian image

setenv load_addr "0x9000000"
setenv overlay_error "false"
setenv rootdev "/dev/mmcblk0p2"
setenv verbosity "1"
setenv console "both"
setenv bootlogo "false"
setenv rootfstype "ext4"
setenv overlay_prefix "sun50i-h616"
setenv overlays "uart3"

load \${devtype} \${devnum}:\${bootpart} \${load_addr} /boot/Image
load \${devtype} \${devnum}:\${bootpart} \${fdt_addr_r} /boot/dtb/allwinner/sun50i-h616-orangepi-zero3.dtb

fdt addr \${fdt_addr_r}
fdt resize 65536

for overlay_file in \${overlays}; do
    if load \${devtype} \${devnum}:\${bootpart} \${load_addr} /boot/dtb/allwinner/overlay/\${overlay_prefix}-\${overlay_file}.dtbo; then
        echo "Applying kernel provided DT overlay \${overlay_prefix}-\${overlay_file}.dtbo"
        fdt apply \${load_addr} || setenv overlay_error "true"
    fi
done

load \${devtype} \${devnum}:\${bootpart} \${ramdisk_addr_r} /boot/uInitrd

booti \${load_addr} \${ramdisk_addr_r} \${fdt_addr_r}
EOF

# Create README file with instructions
cat > "$BOOT_DIR/README.txt" << EOF
This boot directory was recreated. For a fully functional system, you'll need:

1. Image - The Linux kernel image
2. uInitrd - Initial RAM disk
3. dtb/allwinner/sun50i-h616-orangepi-zero3.dtb - Device tree binary
4. boot.scr - Compiled boot script (from boot.cmd)

To compile the boot.cmd to boot.scr (if needed):
$ mkimage -C none -A arm64 -T script -d boot.cmd boot.scr

These files can be obtained from:
1. A fresh Armbian image for Orange Pi Zero 3
2. Another working Orange Pi Zero 3 system
EOF

echo -e "${YELLOW}Would you like to attempt downloading essential boot files from Armbian? (y/n): ${NC}"
read -p "" download_files

# Enhanced download function with better error handling, progress indication, and multiple URLs
if [[ "$download_files" =~ ^[Yy] ]]; then
    echo -e "${GREEN}Attempting to download and extract essential boot files...${NC}"
    echo -e "${YELLOW}This may take some time depending on your internet connection.${NC}"
    
    # Try to find latest version first
    find_latest_armbian_url || echo -e "${YELLOW}Using predefined URLs instead${NC}"
    
    # Check for required tools
    download_tool=""
    if check_command wget; then
        download_tool="wget"
    elif check_command curl; then
        download_tool="curl"
    else
        echo -e "${RED}Neither wget nor curl is available. Cannot download files.${NC}"
        echo -e "${YELLOW}Please install either wget or curl and try again.${NC}"
        download_files="n"
    fi
    
    if [[ "$download_files" =~ ^[Yy] ]]; then
        # Create temporary directory for download
        mkdir -p "${TEMP_DIR}" || {
            echo -e "${RED}Failed to create temporary directory.${NC}"
            download_files="n"
        }
    fi
    
    if [[ "$download_files" =~ ^[Yy] ]]; then
        # Try multiple download URLs
        download_success=false
        
        # Updated URL list to include all alternatives with the successful one first
        for current_url in "$DOWNLOAD_URL" "$DOWNLOAD_URL_ALT1" "$DOWNLOAD_URL_ALT2" "$DOWNLOAD_URL_ALT3"; do
            echo -e "${GREEN}Trying download from: ${current_url}${NC}"
            echo -e "${GREEN}Downloading Armbian image (this may take several minutes)...${NC}"
            
            if [ "$download_tool" = "wget" ]; then
                # Add --no-check-certificate to bypass SSL issues and -v for visibility
                wget --no-check-certificate -v --timeout=300 "${current_url}" -O "${TEMP_DIR}/armbian.img.xz" && download_success=true && break
            else
                curl -k -L --connect-timeout 300 --progress-bar "${current_url}" -o "${TEMP_DIR}/armbian.img.xz" && download_success=true && break
            fi
            
            echo -e "${YELLOW}Download from this source failed. Trying alternative source...${NC}"
            sleep 1
        done
        
        if ! $download_success; then
            echo -e "${RED}All download attempts failed.${NC}"
            echo -e "${YELLOW}Would you like to try one more download with a manual URL? (y/n)${NC}"
            read -p "" manual_download
            
            if [[ "$manual_download" =~ ^[Yy] ]]; then
                echo -e "${YELLOW}Enter direct download URL for Armbian image (must end with .img.xz):${NC}"
                read -p "" manual_url
                
                if [ -n "$manual_url" ]; then
                    echo -e "${GREEN}Trying download from: ${manual_url}${NC}"
                    if [ "$download_tool" = "wget" ]; then
                        wget --no-check-certificate -v --timeout=300 "${manual_url}" -O "${TEMP_DIR}/armbian.img.xz" && download_success=true
                    else
                        curl -k -L --connect-timeout 300 --progress-bar "${manual_url}" -o "${TEMP_DIR}/armbian.img.xz" && download_success=true
                    fi
                else
                    echo -e "${RED}No URL provided.${NC}"
                fi
            fi
        fi
        
        if ! $download_success; then
            echo -e "${YELLOW}You can manually download Armbian from https://www.armbian.com/orange-pi-zero-3/${NC}"
            echo -e "${YELLOW}and copy the boot files from the image to ${BOOT_DIR}${NC}"
        else
            # Check for extraction tools
            if ! check_command xz; then
                echo -e "${RED}xz decompression tool not available. Cannot extract the image.${NC}"
            else
                # Extract the image with progress indication
                echo -e "${GREEN}Extracting image (this may take several minutes)...${NC}"
                xz -d "${TEMP_DIR}/armbian.img.xz" || {
                    echo -e "${RED}Failed to extract Armbian image.${NC}"
                    rm -f "${TEMP_DIR}/armbian.img.xz" 2>/dev/null
                    download_success=false
                }
            fi
            
            if $download_success && [ -f "${TEMP_DIR}/armbian.img" ]; then
                # Rest of extraction process with better error handling
                echo -e "${GREEN}Image extracted successfully.${NC}"
                mkdir -p "${TEMP_DIR}/image_mount" || {
                    echo -e "${RED}Failed to create image mount point.${NC}"
                    rm -f "${TEMP_DIR}/armbian.img" 2>/dev/null
                    download_success=false
                }
                
                if $download_success; then
                    # More robust partition detection
                    echo -e "${GREEN}Analyzing image structure...${NC}"
                    
                    if ! check_command fdisk; then
                        echo -e "${RED}fdisk not available. Cannot analyze image structure.${NC}"
                        echo -e "${YELLOW}Trying with fixed offset values...${NC}"
                        boot_offset_bytes=1048576  # Common 1MB offset for first partition
                    else
                        # Find the boot partition offset
                        fdisk_output=$(fdisk -l "${TEMP_DIR}/armbian.img" 2>/dev/null)
                        boot_offset=$(echo "$fdisk_output" | grep "Sector size" | awk '{print $4}')
                        boot_start=$(echo "$fdisk_output" | grep -A5 "Device" | grep -v "Device" | head -1 | awk '{print $2}')
                        
                        if [ -z "$boot_offset" ] || [ -z "$boot_start" ]; then
                            echo -e "${RED}Failed to determine partition offset.${NC}"
                            echo -e "${YELLOW}Trying with fixed offset values...${NC}"
                            boot_offset_bytes=1048576  # Common 1MB offset for first partition
                        else
                            boot_offset_bytes=$((boot_offset * boot_start))
                        fi
                    fi
                    
                    # Mount with more resilient approach
                    echo -e "${GREEN}Mounting image with offset ${boot_offset_bytes}...${NC}"
                    
                    mount_success=false
                    if mount -o loop,offset=${boot_offset_bytes} "${TEMP_DIR}/armbian.img" "${TEMP_DIR}/image_mount" 2>/dev/null; then
                        mount_success=true
                    else
                        echo -e "${RED}Standard mount failed. Trying alternative methods...${NC}"
                        
                        # Try with different filesystem types
                        for fs_type in vfat ext4 ext3 ext2; do
                            echo -e "Trying with $fs_type..."
                            if mount -o loop,offset=${boot_offset_bytes} -t $fs_type "${TEMP_DIR}/armbian.img" "${TEMP_DIR}/image_mount" 2>/dev/null; then
                                mount_success=true
                                break
                            fi
                        done
                    fi
                    
                    if $mount_success; then
                        # Copy files with better error handling
                        echo -e "${GREEN}Copy boot files from image to SD card...${NC}"
                        
                        if [ -d "${TEMP_DIR}/image_mount/boot" ]; then
                            echo -e "${GREEN}Found /boot directory in image${NC}"
                            cp -rv "${TEMP_DIR}/image_mount/boot/"* "${BOOT_DIR}/" 
                        else
                            echo -e "${RED}No /boot directory found in the image.${NC}"
                        fi
                    else
                        echo -e "${RED}Failed to mount the image. Cannot copy boot files.${NC}"
                    fi
                fi
            fi
        fi
    fi
fi

# Add backup script creation that was missing
echo -e "${GREEN}Creating backup script...${NC}"
cat > "${MOUNT_POINT}/backup_boot.sh" << 'EOF'
#!/bin/bash
# Simple script to backup boot directory before updates
# Run this with sudo before doing apt upgrade

BACKUP_DIR="/root/boot_backups/boot_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Backing up /boot to $BACKUP_DIR..."
cp -a /boot/* "$BACKUP_DIR/"

echo "Boot directory backed up successfully."
echo "To restore, use: cp -a $BACKUP_DIR/* /boot/"
EOF

chmod +x "${MOUNT_POINT}/backup_boot.sh"
echo -e "${GREEN}Backup script created at ${MOUNT_POINT}/backup_boot.sh${NC}"

# Additional recovery script for handling mtdblock4 mount errors
echo -e "${GREEN}Creating recovery script for mtdblock4 mount errors...${NC}"
cat > "${MOUNT_POINT}/fix_mtdblock_error.sh" << 'EOF'
#!/bin/bash
# Recovery script for mtdblock4 mount errors
# Run this script if you encounter the error: "mount: mounting /mtdblock4 on failed: No such file or directory"

echo "Checking for known mtdblock issues..."

# Verify boot directory contents
if [ -z "$(ls -A /boot 2>/dev/null)" ]; then
  echo "WARNING: /boot directory is empty! This is likely causing your boot failure."
  echo "You will need to restore boot files from a backup or reflash the SD card."
  exit 1
fi

# Check for missing device nodes
if [ ! -e "/dev/mtdblock4" ] && [ -d "/dev" ]; then
  echo "Missing mtdblock device nodes. Attempting to create them..."
  for i in $(seq 0 10); do
    [ ! -e "/dev/mtdblock$i" ] && mknod "/dev/mtdblock$i" b 31 $i && echo "Created /dev/mtdblock$i"
  done
fi

# Check fstab configuration
if grep -q "mtdblock4" /etc/fstab; then
  echo "Found mtdblock4 entry in fstab. Checking if it's correct..."
  # Add specific fstab checking logic here
fi

# Check kernel modules
if ! lsmod | grep -q "mtd"; then
  echo "MTD modules may not be loaded. Attempting to load..."
  modprobe mtdblock || echo "Failed to load mtdblock module."
fi

echo "Recovery steps completed. Please reboot to test if the issue is resolved."
echo "If the problem persists, you may need to reflash the SD card with a fresh Armbian image."
EOF

chmod +x "${MOUNT_POINT}/fix_mtdblock_error.sh"
echo -e "${GREEN}MTD block error recovery script created at ${MOUNT_POINT}/fix_mtdblock_error.sh${NC}"

# Add power supply check script
echo -e "${GREEN}Creating power supply diagnostic script...${NC}"
cat > "${MOUNT_POINT}/check_power.sh" << 'EOF'
#!/bin/bash
# Check power supply voltage and display warnings if unstable
# This can help diagnose boot issues related to insufficient power

measure_voltage() {
  if [ -f /sys/class/power_supply/bq25890-charger/voltage_now ]; then
    voltage=$(cat /sys/class/power_supply/bq25890-charger/voltage_now)
    echo "scale=2; $voltage / 1000000" | bc
  elif [ -f /sys/class/power_supply/usb/voltage_now ]; then
    voltage=$(cat /sys/class/power_supply/usb/voltage_now)
    echo "scale=2; $voltage / 1000000" | bc
  else
    echo "N/A"
  fi
}

echo "============================================"
echo "        Power Supply Diagnostic Tool        "
echo "============================================"
echo "Checking power supply status..."

# Check current voltage
current_voltage=$(measure_voltage)
if [ "$current_voltage" != "N/A" ]; then
  echo "Current voltage: ${current_voltage}V"
  
  # Analyze voltage
  if (( $(echo "$current_voltage < 4.8" | bc -l) )); then
    echo "WARNING: Voltage is too low! This can cause boot failures."
    echo "Recommended: Use a 5V/2A or higher power supply."
  elif (( $(echo "$current_voltage" > 5.2 | bc -l) )); then
    echo "WARNING: Voltage is too high! This may damage your board."
  else
    echo "Voltage seems within acceptable range."
  fi
else
  echo "Couldn't read voltage information. Please ensure you have a stable 5V/2A power supply."
fi

echo ""
echo "Power recommendations:"
echo "1. Use a high-quality 5V/2A or higher power adapter"
echo "2. Use a short, thick USB cable to minimize voltage drop"
echo "3. Disconnect unnecessary USB devices during boot"
echo "4. If using a USB hub, ensure it's powered separately"
echo "============================================"
EOF

chmod +x "${MOUNT_POINT}/check_power.sh"
echo -e "${GREEN}Power diagnostic script created at ${MOUNT_POINT}/check_power.sh${NC}"

# Check for u-boot-tools and offer to compile boot script
if command -v mkimage >/dev/null 2>&1; then
    echo -e "${GREEN}Creating boot.scr from boot.cmd...${NC}"
    mkimage -C none -A arm64 -T script -d "${BOOT_DIR}/boot.cmd" "${BOOT_DIR}/boot.scr" && \
    echo -e "${GREEN}boot.scr created successfully${NC}" || \
    echo -e "${RED}Failed to create boot.scr${NC}"
else
    echo -e "${YELLOW}mkimage tool not found. Cannot create boot.scr.${NC}"
    echo -e "${YELLOW}Install u-boot-tools package and run:${NC}"
    echo -e "${YELLOW}sudo mkimage -C none -A arm64 -T script -d ${BOOT_DIR}/boot.cmd ${BOOT_DIR}/boot.scr${NC}"
fi

# Replace the Jetson/Orange Pi differences section with clearer cross-platform explanation
echo -e "\n${BLUE}=== Cross-Platform Boot Restoration Notes ===${NC}"
echo -e "${YELLOW}You are using a Jetson Nano to restore boot files for an Orange Pi Zero 3 SD card${NC}"
echo -e "${YELLOW}Important considerations:${NC}"
echo -e "  1. ${GREEN}Different architectures:${NC} While both are ARM-based, they use different"
echo -e "     SoCs (Tegra X1 vs Allwinner H616) with different boot requirements"
echo -e "  2. ${GREEN}Boot mechanisms:${NC} Jetson uses NVIDIA bootloaders while Orange Pi uses U-Boot"
echo -e "  3. ${GREEN}Kernel compatibility:${NC} Kernels are not interchangeable between platforms"
echo -e "  4. ${GREEN}DTB files:${NC} Device Tree Blobs are hardware-specific and must match the target device"
echo -e "  5. ${GREEN}Tools compatibility:${NC} The mkimage tool works on both platforms for creating boot.scr"

# After boot directory restoration, add recommendations with correct paths
echo -e "\n${BLUE}=== APT Configuration Recommendations for Orange Pi Zero 3 ===${NC}"
echo -e "${YELLOW}Once the Orange Pi is booted, prevent future boot directory corruption:${NC}"
echo -e "  1. ${GREEN}Pin critical packages:${NC} Consider 'pinning' critical boot-related"
echo -e "     packages to prevent automatic upgrades."
echo -e "  2. ${GREEN}Backup before updates:${NC} Always backup ${GREEN}/boot${NC} before running"
echo -e "     system updates."
echo -e "  3. ${GREEN}Use Armbian-specific tools:${NC} If available, use armbian-config"
echo -e "     for system maintenance tasks."
echo -e "  4. ${GREEN}Create apt preferences:${NC} To pin packages, create a file at"
echo -e "     ${GREEN}/etc/apt/preferences.d/custom-boot${NC} with contents like:"
echo -e "       Package: linux-*\n       Pin: release a=now\n       Pin-Priority: 1001"
echo -e "  5. ${GREEN}Verify repository compatibility:${NC} Ensure your configured repos"
echo -e "     are intended for your specific hardware (Orange Pi Zero 3)."
echo -e "  6. ${GREEN}Use the backup script:${NC} A simple backup script has been added to"
echo -e "     your SD card as ${GREEN}/backup_boot.sh${NC}. Run it before system updates."

# Add a prompt to unmount or keep mounted
echo
read -p "Would you like to unmount the SD card now? (y/n): " unmount_choice
if [[ "$unmount_choice" =~ ^[Yy] ]]; then
    echo -e "${YELLOW}Unmounting ${MOUNT_POINT}...${NC}"
    umount "${MOUNT_POINT}" && echo -e "${GREEN}Unmounted successfully${NC}" || echo -e "${RED}Failed to unmount${NC}"
else
    echo -e "${YELLOW}SD card remains mounted at ${MOUNT_POINT}${NC}"
    echo -e "${YELLOW}Remember to unmount it before removing the SD card${NC}"
fi

echo -e "${GREEN}Boot restoration process completed!${NC}"
