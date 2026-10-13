#!/bin/bash
# shellcheck disable=SC2034  # output variables are read by install.sh
# Disk layout for install.sh (decisions §4). Sourced; needs lib.sh.
#
# In:  DISK, USE_LUKS (true|false), LUKS_PASS, IS_LAPTOP (true|false)
# Out: EFI_DEV, ROOT_PART, ROOT_DEV (mapper or partition), LUKS_UUID,
#      FS_UUID, SWAP_OFFSET (laptop only)
#
#   p1  EFI  2 GiB  FAT32  → /boot   (UKIs for two kernels + snapshot entries)
#   p2  rest        LUKS2 → btrfs
#
# Subvolumes (top level):
#   @            /                       snapshots: snapper "root"
#   @home        /home                   snapshots: snapper "home" (daily)
#   @log         /var/log                outside snapshots
#   @pkg         /var/cache/pacman/pkg   outside snapshots
#   @.snapshots  /.snapshots
#   @docker      /var/lib/docker         outside snapshots
#   @swap        /swap                   laptop only: swap file for hibernation
# Nested: /home/.snapshots (snapper "home"); ~/.cache and
# ~/.local/share/Steam are created later by target-setup.sh.

BTRFS_OPTS="noatime,compress=zstd,discard=async"
MAPPER_NAME="root"

# Close leftovers of a previous failed attempt so the script can be rerun.
disk_cleanup() {
    swapoff -a 2>/dev/null || true
    if mountpoint -q /mnt; then
        umount -R /mnt || die "Could not unmount /mnt — close shells using it and rerun."
    fi
    if [ -e "/dev/mapper/$MAPPER_NAME" ]; then
        cryptsetup close "$MAPPER_NAME" || die "Could not close /dev/mapper/$MAPPER_NAME."
    fi
}

# nvme0n1 → nvme0n1p1, sda → sda1: read the partition number from sysfs
# instead of guessing the name (works without udev too).
partition_path() {  # partition_path DISK NUMBER
    local d dev
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        for d in /sys/class/block/"$(basename "$1")"/*/partition; do
            if [ ! -r "$d" ] || [ "$(cat "$d")" != "$2" ]; then continue; fi
            dev="/dev/$(basename "$(dirname "$d")")"
            [ -b "$dev" ] && { printf '%s' "$dev"; return 0; }
        done
        udevadm settle 2>/dev/null || true
        sleep 1
    done
    return 1
}

disk_partition() {
    step "Partitioning $DISK"
    disk_cleanup
    wipefs -af "$DISK" >>"$GOLDEN_LOG" 2>&1
    sgdisk --zap-all "$DISK" >>"$GOLDEN_LOG" 2>&1
    local root_type=8300
    $USE_LUKS && root_type=8309
    sgdisk -n1:0:+2G -t1:ef00 -c1:EFI \
           -n2:0:0   -t2:"$root_type" -c2:root "$DISK" >>"$GOLDEN_LOG" 2>&1 \
        || die "sgdisk failed (see $GOLDEN_LOG)."
    partprobe "$DISK" 2>/dev/null || true
    udevadm settle

    EFI_DEV="$(partition_path "$DISK" 1)" || die "EFI partition did not appear."
    ROOT_PART="$(partition_path "$DISK" 2)" || die "Root partition did not appear."
    wipefs -af "$EFI_DEV" "$ROOT_PART" >>"$GOLDEN_LOG" 2>&1
    mkfs.fat -F32 -n EFI "$EFI_DEV" >>"$GOLDEN_LOG" 2>&1 || die "mkfs.fat failed."
}

disk_encrypt() {
    LUKS_UUID=""
    if ! $USE_LUKS; then
        ROOT_DEV="$ROOT_PART"
        return 0
    fi
    step "Encrypting $ROOT_PART (LUKS2)"
    # Passphrase via stdin, never in argv (visible in the process list).
    printf '%s' "$LUKS_PASS" | cryptsetup luksFormat --type luks2 --batch-mode \
        --label GOLDEN_LUKS --key-file - "$ROOT_PART" >>"$GOLDEN_LOG" 2>&1 \
        || die "luksFormat failed (see $GOLDEN_LOG)."
    # --allow-discards --persistent: TRIM passes through LUKS (discard=async
    # in btrfs), stored in the LUKS2 header — no kernel parameter needed.
    printf '%s' "$LUKS_PASS" | cryptsetup open --allow-discards --persistent \
        --key-file - "$ROOT_PART" "$MAPPER_NAME" >>"$GOLDEN_LOG" 2>&1 \
        || die "cryptsetup open failed."
    ROOT_DEV="/dev/mapper/$MAPPER_NAME"
    LUKS_UUID="$(cryptsetup luksUUID "$ROOT_PART")"
}

disk_btrfs() {
    step "Creating btrfs and subvolumes"
    mkfs.btrfs -f -L golden "$ROOT_DEV" >>"$GOLDEN_LOG" 2>&1 || die "mkfs.btrfs failed."
    FS_UUID="$(blkid -s UUID -o value "$ROOT_DEV")"

    local top=/mnt/.golden-top sv
    local subvols=(@ @home @log @pkg @.snapshots @docker)
    $IS_LAPTOP && subvols+=(@swap)
    mkdir -p "$top"
    mount "$ROOT_DEV" "$top"
    for sv in "${subvols[@]}"; do
        btrfs subvolume create "$top/$sv" >>"$GOLDEN_LOG"
    done
    umount "$top"
    rmdir "$top"

    mount -o "$BTRFS_OPTS,subvol=@" "$ROOT_DEV" /mnt
    mkdir -p /mnt/{home,var/log,var/cache/pacman/pkg,.snapshots,var/lib/docker,boot}
    mount -o "$BTRFS_OPTS,subvol=@home"       "$ROOT_DEV" /mnt/home
    mount -o "$BTRFS_OPTS,subvol=@log"        "$ROOT_DEV" /mnt/var/log
    mount -o "$BTRFS_OPTS,subvol=@pkg"        "$ROOT_DEV" /mnt/var/cache/pacman/pkg
    mount -o "$BTRFS_OPTS,subvol=@.snapshots" "$ROOT_DEV" /mnt/.snapshots
    mount -o "$BTRFS_OPTS,subvol=@docker"     "$ROOT_DEV" /mnt/var/lib/docker
    if $IS_LAPTOP; then
        mkdir -p /mnt/swap
        mount -o "noatime,subvol=@swap" "$ROOT_DEV" /mnt/swap
    fi
    mount -o umask=0077 "$EFI_DEV" /mnt/boot

    # Snapper "home" keeps its snapshots in a nested subvolume (standard layout).
    btrfs subvolume create /mnt/home/.snapshots >>"$GOLDEN_LOG"
}

# Laptop: swap file = RAM size, for hibernation (decisions §4). zram stays
# the primary swap; the file has lower priority (set in fstab by target-setup).
disk_swapfile() {
    SWAP_OFFSET=""
    $IS_LAPTOP || return 0
    step "Creating swap file for hibernation"
    local ram_mb
    ram_mb="$(free -m | awk '/^Mem:/{print $2}')"
    btrfs filesystem mkswapfile --size "${ram_mb}M" --uuid clear /mnt/swap/swapfile \
        >>"$GOLDEN_LOG" 2>&1 || die "mkswapfile failed."
    SWAP_OFFSET="$(btrfs inspect-internal map-swapfile -r /mnt/swap/swapfile)"
    [ -n "$SWAP_OFFSET" ] || die "Could not read the swap file offset."
}

disk_setup() {
    disk_partition
    disk_encrypt
    disk_btrfs
    disk_swapfile
    info "EFI: $EFI_DEV  root: $ROOT_PART  fs: $FS_UUID"
}
