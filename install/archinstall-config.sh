#!/bin/bash
# Builds the archinstall configs for install.sh. Sourced; needs lib.sh.
#
# Written against archinstall 4.5 (Arch ISO, autumn 2026). archinstall only
# installs the base system into the already mounted /mnt (pre_mounted_config):
# partitions, LUKS, Limine, Plymouth and the CachyOS kernel are ours
# (disk.sh, target-setup.sh), so its JSON stays small and stable.
#
# In:  REPO_DIR, HOSTNAME_NEW, TIMEZONE, USERNAME, USER_PASS
# Out: $1/user_configuration.json, $1/user_credentials.json (mode 600)

write_archinstall_config() {
    local dir="$1" pkgs_json hash
    mkdir -p "$dir"

    pkgs_json="$(pkglist "$REPO_DIR/packages/base/arch.txt" | jq -R . | jq -s .)"

    # System locale en_US.UTF-8 and US console keymap: the LUKS prompt in
    # Plymouth must accept a Latin passphrase (decisions §1: English UI).
    # Bootloader: none here (--skip-boot) — Limine is set up by target-setup.sh.
    # Swap: zram is configured by target-setup.sh (own size formula).
    jq -n \
        --arg hostname "$HOSTNAME_NEW" \
        --arg timezone "$TIMEZONE" \
        --argjson packages "$pkgs_json" \
        '{
            "archinstall-language": "English",
            "script": "guided",
            "disk_config": {
                "config_type": "pre_mounted_config",
                "mountpoint": "/mnt"
            },
            "hostname": $hostname,
            "kernels": ["linux-lts"],
            "locale_config": {
                "kb_layout": "us",
                "sys_lang": "en_US",
                "sys_enc": "UTF-8"
            },
            "mirror_config": {
                "optional_repositories": ["multilib"]
            },
            "network_config": { "type": "nm" },
            "ntp": true,
            "packages": $packages,
            "pacman_config": { "parallel_downloads": 5, "color": true },
            "swap": { "enabled": false },
            "timezone": $timezone,
            "services": [],
            "custom_commands": []
        }' > "$dir/user_configuration.json"

    # Password hash (SHA-512 crypt) instead of plaintext: plaintext "!password"
    # is deprecated in archinstall 4.x. The password goes to openssl via
    # stdin, never via argv. Root gets no password (locked); the user has sudo.
    hash="$(printf '%s\n' "$USER_PASS" | openssl passwd -6 -stdin)"
    ( umask 077
      jq -n --arg user "$USERNAME" --arg hash "$hash" \
        '{ "users": [ { "username": $user, "enc_password": $hash,
                        "sudo": true, "groups": [] } ] }' \
        > "$dir/user_credentials.json" )
}
