#!/bin/bash
# Shared helpers for install.sh (live ISO) and target-setup.sh (chroot).
# Sourced, not executed. UI text is English (decisions §1).

GOLDEN_LOG="${GOLDEN_LOG:-/tmp/golden-install.log}"

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*" | tee -a "$GOLDEN_LOG"; }
info() { printf '    %s\n' "$*" | tee -a "$GOLDEN_LOG"; }
warn() { printf '\033[1;33m!!  %s\033[0m\n' "$*" | tee -a "$GOLDEN_LOG" >&2; }
die()  { printf '\033[1;31mxx  %s\033[0m\n' "$*" | tee -a "$GOLDEN_LOG" >&2; exit 1; }

# Package names from list files: '#' starts a comment, blank lines skipped,
# several names per line allowed.
pkglist() {
    sed 's/#.*//' "$@" | tr -s ' \t' '\n' | sed '/^$/d'
}

# First "# label: ..." line of an optional list file.
pkglabel() {
    sed -n 's/^# label:[[:space:]]*//p' "$1" | head -n1
}

# --- gum wrappers (live ISO only) -------------------------------------------
# Every prompt goes through these, so the look stays consistent and a
# cancelled prompt (Esc / Ctrl+C) aborts the installer instead of returning
# an empty answer.

ask() {     # ask "Prompt" [default] [placeholder]
    local out
    out="$(gum input --prompt "$1: " --value "${2:-}" --placeholder "${3:-}")" || die "Cancelled."
    printf '%s' "$out"
}

ask_secret() {  # ask_secret "Prompt" → asks twice until both match and non-empty
    local a b
    while true; do
        a="$(gum input --password --prompt "$1: ")" || die "Cancelled."
        [ -n "$a" ] || { warn "Must not be empty."; continue; }
        b="$(gum input --password --prompt "Repeat: ")" || die "Cancelled."
        [ "$a" = "$b" ] && break
        warn "Do not match, try again."
    done
    printf '%s' "$a"
}

confirm() { # confirm "Question" [default: yes|no]
    if [ "${2:-yes}" = no ]; then
        gum confirm --default=false "$1"
    else
        gum confirm "$1"
    fi
}
