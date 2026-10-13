#!/bin/bash
# Repository checks — the same in GitHub Actions and locally:
#   bash test/ci-check.sh
# Needs: bash, shellcheck, jq, openssl, python3; chezmoi for the template
# checks (in CI it is required, locally they are skipped without it).
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
ok()   { printf 'ok    %s\n' "$*"; }
bad()  { printf 'FAIL  %s\n' "$*"; fail=1; }
skip() { printf 'skip  %s\n' "$*"; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export GOLDEN_LOG="$tmp/golden.log"

echo "== Shell scripts (bash -n + shellcheck)"
mapfile -t scripts < <({
    echo install.sh
    ls install/*.sh test/*.sh
    grep -rlE '^#!/(usr/)?bin/(env )?bash' dot_local/bin
} | sort -u)
for f in "${scripts[@]}"; do
    if bash -n "$f" && shellcheck -x -P SCRIPTDIR -s bash "$f"; then ok "$f"; else bad "$f"; fi
done

echo "== archinstall config"
if (
    # shellcheck source=install/lib.sh
    source install/lib.sh
    # shellcheck source=install/archinstall-config.sh
    source install/archinstall-config.sh
    REPO_DIR="$PWD" HOSTNAME_NEW=ci TIMEZONE=UTC USERNAME=ci USER_PASS=ci
    write_archinstall_config "$tmp/ai"
) && jq -e '.disk_config.config_type == "pre_mounted_config"
            and (.packages | length > 0)
            and .kernels == ["linux-lts"]' "$tmp/ai/user_configuration.json" >/dev/null \
  && jq -e '.users[0].enc_password | startswith("$6$")' "$tmp/ai/user_credentials.json" >/dev/null
then ok "user_configuration.json / user_credentials.json"; else bad "archinstall config"; fi

echo "== Package lists"
for f in packages/*.txt packages/*/*.txt; do
    names="$(sed 's/#.*//' "$f" | tr -s ' \t' '\n' | sed '/^$/d')"
    if bad_names="$(grep -vE '^[a-zA-Z0-9@._+-]+$' <<< "$names")" && [ -n "$bad_names" ]; then
        bad "$f: invalid names: $bad_names"
    elif dups="$(sort <<< "$names" | uniq -d)" && [ -n "$dups" ]; then
        bad "$f: duplicates: $dups"
    else
        ok "$f"
    fi
done
for f in packages/optional/*.txt; do
    grep -q '^# label: ' "$f" || bad "$f: no '# label: ...' line"
done

echo "== Removed items (decisions.md §9) are not back in the code"
removed='sddm|podman|vscodium|neovim|kanshi|tzupdate|pacsea|pamac|waypaper|cups-pdf|gnome-firmware|kvantum|blueman|nm-connection-editor|grim|slurp|swappy|direnv|cargo-watch|proton-cachyos|kicad|intellij|cryptomator|localsend|kdeconnect'
if hits="$(grep -rniwE "$removed" install.sh install packages system data run_* .chezmoi* dot_local)"; then
    bad "found: $hits"
else
    ok "none found"
fi

echo "== chezmoi templates"
if command -v chezmoi >/dev/null 2>&1; then
    cfg="$tmp/chezmoi.toml"
    printf '%s\n' '[data]' '  displayName = "CI"' '  optional = ["obs", "anki"]' \
        '  ryzenadj = "54000 65000 54000 95"' > "$cfg"
    for t in run_*.tmpl; do
        if chezmoi --source "$PWD" --config "$cfg" execute-template < "$t" > "$tmp/out.sh" \
            && bash -n "$tmp/out.sh" && shellcheck -s bash "$tmp/out.sh"; then
            ok "$t"
        else
            bad "$t"
        fi
    done
    mkdir -p "$tmp/home/.config/golden"
    printf '%s\n' 'displayName = "CI"' 'optional = ["obs"]' 'ryzenadj = ""' \
        > "$tmp/home/.config/golden/answers.toml"
    if HOME="$tmp/home" chezmoi --source "$PWD" --config "$cfg" execute-template --init \
            < .chezmoi.toml.tmpl > "$tmp/cz.toml" \
        && python3 -c 'import sys, tomllib; d = tomllib.load(open(sys.argv[1], "rb"))["data"]; assert d["optional"] == ["obs"], d' "$tmp/cz.toml"; then
        ok ".chezmoi.toml.tmpl"
    else
        bad ".chezmoi.toml.tmpl"
    fi
elif [ -n "${CI:-}" ]; then
    bad "chezmoi is not installed"
else
    skip "chezmoi not installed (runs in CI)"
fi

echo
if [ "$fail" -ne 0 ]; then echo "Some checks FAILED"; exit 1; fi
echo "All checks passed"
