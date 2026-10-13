# golden-setup

Reproducible Arch + Niri + Noctalia setup for my machines (and a couple of
friends').

## Install

Boot the Arch Linux ISO in **UEFI** mode, connect to the internet
(`iwctl` for Wi-Fi), then:

```
bash <(curl -fsSL https://raw.githubusercontent.com/SatoNistOne/system_setap/main/install.sh)
```

It asks everything first (login, passwords, disk, time zone, optional
apps), then installs on its own. After reboot: disk password → log in on the
console → run

```
chezmoi init --apply SatoNistOne/system_setap
```

and reboot once more — from then on it logs straight into Niri.

Status: phase 1 and the start of phase 2 are written, not yet tested in a VM.
Checks: `bash test/ci-check.sh` (also runs in GitHub Actions on every push).

## Layout

- `install.sh`, `install/` — phase 1 (live ISO)
- `packages/` — package lists: `base/` (installer), `core.txt`, `optional/`, `hw/`, `flatpak.txt`
- `system/` — files under `/` (installed by `run_onchange_*` scripts)
- `dot_*`, `run_*` — chezmoi (phase 2)
- `docs/decisions.md` — all decisions (source of truth)
- `docs/todo.md` — next steps, `docs/tests.md` — checks on a live system
- `docs/guide.md` — command cheat sheet, `docs/raw.md` — old code (not the source of truth)

Plymouth theme: based on [Omarchy](https://github.com/basecamp/omarchy) (MIT,
see `system/usr/share/plymouth/themes/golden/LICENSE.omarchy`).
