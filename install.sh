#!/bin/bash
# Golden setup — phase 1 installer. Run from the Arch Linux live ISO (UEFI):
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/SatoNistOne/system_setap/main/install.sh)
#
# Asks everything up front (decisions §1), then works without questions:
# partitions + LUKS + btrfs (install/disk.sh) → archinstall in pre-mounted
# mode (install/archinstall-config.sh) → golden base inside the chroot
# (install/target-setup.sh). After reboot: log in on the console and run
#   chezmoi init --apply SatoNistOne/system_setap
set -euo pipefail

REPO_SLUG="${GOLDEN_REPO:-SatoNistOne/system_setap}"
REPO_BRANCH="${GOLDEN_BRANCH:-main}"

# --- Bootstrap: when started via curl there is no repo next to us ------------
SELF_DIR=""
if SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"; then :; fi
if [ ! -f "$SELF_DIR/install/lib.sh" ]; then
    dest=/tmp/golden-setup
    echo "Downloading $REPO_SLUG ($REPO_BRANCH)..."
    rm -rf "$dest"; mkdir -p "$dest"
    curl -fsSL "https://github.com/$REPO_SLUG/archive/refs/heads/$REPO_BRANCH.tar.gz" \
        | tar -xz -C "$dest" --strip-components=1
    exec bash "$dest/install.sh" "$@"
fi
REPO_DIR="$SELF_DIR"
# shellcheck source=install/lib.sh
source "$REPO_DIR/install/lib.sh"
# shellcheck source=install/disk.sh
source "$REPO_DIR/install/disk.sh"
# shellcheck source=install/archinstall-config.sh
source "$REPO_DIR/install/archinstall-config.sh"

trap 'warn "Install failed. Log: $GOLDEN_LOG"' ERR
: > "$GOLDEN_LOG"

# --- Preconditions ----------------------------------------------------------
[ "$(id -u)" = 0 ] || die "Run as root (the live ISO shell is root)."
# This script ERASES a disk: never run it on an installed system.
[ -d /run/archiso ] || die "Run this only from the Arch Linux live ISO."
[ "$(uname -m)" = x86_64 ] || die "x86_64 only."
[ -d /sys/firmware/efi/efivars ] || die "Boot the ISO in UEFI mode (Limine + UKI need UEFI)."
curl -fsS --max-time 10 -o /dev/null https://archlinux.org \
    || die "No internet. Wi-Fi: iwctl station wlan0 connect <SSID>"

step "Preparing the live environment"
# gum (prompts), jq (JSON), archinstall ≥ 4 (config format we target).
pacman -Sy --needed --noconfirm gum jq archinstall >>"$GOLDEN_LOG" 2>&1 \
    || die "pacman failed (see $GOLDEN_LOG)."
ai_ver="$(archinstall --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)*' | head -n1)"
[ "${ai_ver%%.*}" -ge 4 ] 2>/dev/null || die "archinstall $ai_ver is too old (need 4.x)."
info "archinstall $ai_ver"

eval "$(bash "$REPO_DIR/dot_local/bin/executable_golden-detect-hw")"
info "Laptop: $IS_LAPTOP  CPU: $CPU_VENDOR  Nvidia: $HAS_NVIDIA  hybrid: $IS_HYBRID_GPU  VM: $IS_VM"

# --- Questions --------------------------------------------------------------
gum style --border rounded --padding "0 2" --margin "1 0" \
    "Golden setup" "Arch + Niri + Noctalia" "" "All questions first — then it installs on its own."

while true; do
    USERNAME="$(ask "Login" "" "lowercase, e.g. alex")"
    [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] && [ "$USERNAME" != root ] && break
    warn "Lowercase letters, digits, - and _; must not start with a digit."
done

while true; do
    DISPLAY_NAME="$(ask "Display name (optional, shown on the boot screen)" "" "e.g. Alex")"
    [[ "$DISPLAY_NAME" != *[:,=\"\\]* ]] && break
    warn "Characters : , = \" \\ are not allowed."
done

USER_PASS="$(ask_secret "Password for $USERNAME")"

if confirm "Encrypt the system disk (LUKS)? Recommended."; then
    USE_LUKS=true
    LUKS_PASS="$(ask_secret "Disk encryption password (typed at every boot)")"
else
    USE_LUKS=false
    LUKS_PASS=""
fi

while true; do
    HOSTNAME_NEW="$(ask "Machine name" "" "e.g. laptop")"
    [[ "$HOSTNAME_NEW" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]] && break
    warn "Lowercase letters, digits and -, up to 63 characters."
done

tz_guess="$(curl -fsS --max-time 3 https://ipapi.co/timezone 2>/dev/null || true)"
TIMEZONE="$(timedatectl list-timezones | gum filter --height 12 --value "$tz_guess" \
    --header "Time zone (type to search, Enter to pick)")" || die "Cancelled."
[ -n "$TIMEZONE" ] || die "No time zone selected."

# Target disk: whole disks only; no USB sticks, zram, loop or the ISO itself.
iso_disk=""
iso_src="$(findmnt -nvo SOURCE /run/archiso/bootmnt 2>/dev/null || true)"
[ -n "$iso_src" ] && iso_disk="$(lsblk -npso NAME,TYPE "$iso_src" | awk '$2=="disk"{print $1; exit}')"
mapfile -t disks < <(lsblk -dnpo NAME,TYPE,RM,RO,SIZE,MODEL \
    | awk -v iso="$iso_disk" '$2=="disk" && $3==0 && $4==0 && $1!=iso && $1 !~ /zram|loop/ \
        { name=$1; size=$5; $1=$2=$3=$4=$5=""; sub(/^ +/, ""); printf "%-16s %8s  %s\n", name, size, $0 }')
[ "${#disks[@]}" -gt 0 ] || die "No suitable disk found."
choice="$(printf '%s\n' "${disks[@]}" | gum choose --header "System disk — it will be ERASED")" \
    || die "Cancelled."
DISK="${choice%% *}"

# Optional packages (decisions §9) — every packages/optional/*.txt is one item.
declare -A opt_by_label=()
labels=()
for f in "$REPO_DIR"/packages/optional/*.txt; do
    l="$(pkglabel "$f")"; [ -n "$l" ] || l="$(basename "$f" .txt)"
    opt_by_label["$l"]="$(basename "$f" .txt)"
    labels+=("$l")
done
OPTIONAL=()
if picked="$(printf '%s\n' "${labels[@]}" | gum choose --no-limit \
        --header "Optional apps (Space to select, Enter to confirm; none is fine)")"; then
    while IFS= read -r l; do
        [ -n "$l" ] && OPTIONAL+=("${opt_by_label[$l]}")
    done <<< "$picked"
fi

# ryzenadj (decisions §5): known CPU → from the table; other Ryzen laptop → ask.
RYZENADJ=""
if $IS_LAPTOP && [ "$CPU_VENDOR" = amd ]; then
    RYZENADJ="$(awk -F'\t' -v cpu="$CPU_MODEL" '!/^#/ && NF==5 && index(cpu, $1) \
        { print $2, $3, $4, $5; exit }' "$REPO_DIR/data/ryzenadj.tsv")"
    if [ -z "$RYZENADJ" ]; then
        while true; do
            RYZENADJ="$(ask "ryzenadj limits for $CPU_MODEL: stapm fast slow tctl (mW mW mW °C), empty = skip" \
                "" "e.g. 54000 65000 54000 95")"
            [ -z "$RYZENADJ" ] || [[ "$RYZENADJ" =~ ^[0-9]+\ [0-9]+\ [0-9]+\ [0-9]+$ ]] && break
            warn "Four numbers separated by spaces, or empty."
        done
    fi
fi

# --- Summary + the one destructive confirmation -----------------------------
gum style --border rounded --padding "0 2" --margin "1 0" \
    "Login:        $USERNAME" \
    "Display name: ${DISPLAY_NAME:-—}" \
    "Machine:      $HOSTNAME_NEW" \
    "Time zone:    $TIMEZONE" \
    "Disk:         $choice" \
    "Encryption:   $($USE_LUKS && echo LUKS2 || echo none)" \
    "Swap file:    $($IS_LAPTOP && echo "yes (hibernation)" || echo no)" \
    "Optional:     ${OPTIONAL[*]:-—}" \
    "ryzenadj:     ${RYZENADJ:-—}"

if [ -n "$(lsblk -nlo FSTYPE,PARTTYPE "$DISK" | tr -d '[:space:]')" ]; then
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS "$DISK"
    typed="$(ask "$DISK has data. Type its name ($(basename "$DISK")) to ERASE it")"
    [ "$typed" = "$(basename "$DISK")" ] || die "Not confirmed — nothing was changed."
else
    confirm "Erase $DISK and install?" no || die "Not confirmed — nothing was changed."
fi

# --- From here on: no more questions ----------------------------------------
disk_setup

step "Installing the base system (archinstall)"
AI_DIR=/root/golden-archinstall
write_archinstall_config "$AI_DIR"
if ! archinstall --config "$AI_DIR/user_configuration.json" \
        --creds "$AI_DIR/user_credentials.json" --silent --skip-boot 2>&1 | tee -a "$GOLDEN_LOG"; then
    rm -f "$AI_DIR/user_credentials.json"
    die "archinstall failed (see $GOLDEN_LOG and /var/log/archinstall/)."
fi
rm -f "$AI_DIR/user_credentials.json"
if [ ! -f /mnt/etc/arch-release ] || ! grep -q "^$USERNAME:" /mnt/etc/passwd; then
    die "archinstall did not finish (see $GOLDEN_LOG and /var/log/archinstall/)."
fi

step "Golden base (inside the new system)"
TARGET_REPO=/mnt/root/golden-install
rm -rf "$TARGET_REPO"; mkdir -p "$TARGET_REPO"
cp -r "$REPO_DIR"/{install,packages,system,data} "$TARGET_REPO/"
{
    for v in USERNAME DISPLAY_NAME USE_LUKS LUKS_UUID FS_UUID SWAP_OFFSET \
             IS_LAPTOP HAS_NVIDIA IS_HYBRID_GPU; do
        printf '%s=%q\n' "$v" "${!v}"
    done
} > "$TARGET_REPO/install/install.env"
if ! arch-chroot /mnt bash /root/golden-install/install/target-setup.sh 2>&1 | tee -a "$GOLDEN_LOG"; then
    die "Base setup in the chroot failed (see /mnt/var/log/golden-install.log)."
fi

# UEFI boot entry — from the live system, where efivars are writable.
step "UEFI boot entry"
# Lines look like "Boot0003* Golden<TAB>HD(...)" — drop old Golden entries first.
efibootmgr | awk '$1 ~ /^Boot[0-9A-F]{4}/ && $2=="Golden" { n=substr($1, 5, 4); print n }' \
    | while read -r num; do efibootmgr -q -b "$num" -B; done
efibootmgr -q --create --disk "$DISK" --part 1 --label Golden \
    --loader '\EFI\limine\BOOTX64.EFI' --unicode \
    || warn "efibootmgr failed — the firmware can still boot \\EFI\\BOOT\\BOOTX64.EFI."

# Answers for phase 2 (chezmoi reads them via .chezmoi.toml.tmpl).
step "Saving answers for phase 2"
uid_gid="$(awk -F: -v u="$USERNAME" '$1==u{print $3":"$4}' /mnt/etc/passwd)"
answers="/mnt/home/$USERNAME/.config/golden/answers.toml"
install -d -o "${uid_gid%:*}" -g "${uid_gid#*:}" "$(dirname "$(dirname "$answers")")" "$(dirname "$answers")"
{
    echo "# Answers from install.sh — read by chezmoi (.chezmoi.toml.tmpl)."
    printf 'displayName = "%s"\n' "$DISPLAY_NAME"
    printf 'optional = ['
    sep=""; for o in "${OPTIONAL[@]}"; do printf '%s"%s"' "$sep" "$o"; sep=", "; done
    printf ']\n'
    printf 'ryzenadj = "%s"\n' "$RYZENADJ"
} > "$answers"
chown "$uid_gid" "$answers"

rm -rf "$TARGET_REPO" "$AI_DIR"
cp "$GOLDEN_LOG" /mnt/var/log/golden-install-live.log

step "Done"
sync
umount -R /mnt || warn "Could not unmount /mnt — reboot anyway, nothing is lost."
if $USE_LUKS; then cryptsetup close root || true; fi
gum style --border rounded --padding "0 2" --margin "1 0" \
    "Installed. Remove the USB stick and reboot." "" \
    "After the disk password, log in as $USERNAME on the console and run:" \
    "  chezmoi init --apply $REPO_SLUG"
if confirm "Reboot now?"; then reboot; fi
