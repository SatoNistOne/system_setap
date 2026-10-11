# raw — сырой код для сборки репозитория

> Не источник решений. Решения — в `decisions.md`; здесь код из старого плана (местами устарел и противоречит решениям) и готовые файлы, которые переедут в chezmoi-репозиторий. При сборке правда за `decisions.md`.

## Содержание
1. Готовые файлы: `user.js`, `golden-guide.fish`, `golden-practice.fish`
2. Старый план с кодом (project-decided.md, 2026-10)

---

## 1. Готовые файлы

### `user.js` (Firefox)
```js
// Собрано из реального профиля пользователя (about:support → modifiedPreferences),
// 2026-08-17. Только смысловые настройки — служебные/сессионные поля (timestamps,
// счётчики БД, crash-reporter пути) намеренно не включены.

// --- Приватность / трекинг ---
user_pref("browser.contentblocking.category", "custom");
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.globalprivacycontrol.enabled", true);
user_pref("privacy.clearOnShutdown_v2.formdata", true);

// --- Сеть: отключение prefetch/speculative-соединений ---
user_pref("network.dns.disablePrefetch", true);
user_pref("network.prefetch-next", false);
user_pref("network.http.speculative-parallel-limit", 0);

// --- DNS — системный (изменено 2026-10) ---
// DoH внутри Firefox выключен: DNS идёт через systemd-resolved с DoT на Quad9 —
// шифрование то же, но один источник правды для всех приложений. Встроенный
// DoH шёл в обход FlClash (доменные правила) и /etc/hosts.
// 5 = TRR выключен явно (не "по умолчанию" — Firefox не включит его сам
// через rollout). Старые doh-rollout.* не нужны — audit-находка №13.
user_pref("network.trr.mode", 5);

// --- WebRTC: полностью убрать локальные IP из ICE-кандидатов ---
// (proxy_only_if_behind_proxy не защищал — прокси системный через FlClash,
// не браузерный, Firefox его не видел)
user_pref("media.peerconnection.ice.no_host", true);

// --- Аппаратное ускорение видео (использовать системный VAAPI) ---
user_pref("gfx.webrender.all", true);
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("media.hardware-video-decoding.force-enabled", true);
// НЕ ставить layers.acceleration.force-enabled — устаревший флаг,
// задокументированные глюки на Nvidia после suspend/resume

// --- Лёгкие твики (не ломают сайты/капчи) ---
user_pref("privacy.trackingprotection.socialtracking.enabled", true);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("dom.security.https_only_mode", true);
user_pref("beacon.enabled", false);
user_pref("extensions.pocket.enabled", false);

// --- UI-поведение ---
user_pref("browser.toolbars.bookmarks.visibility", "always");
user_pref("browser.startup.page", 3); // восстанавливать предыдущую сессию
```

### `golden-guide.fish`
```fish
function golden-guide --description "Шпаргалка по командам системы"
    set -l f ~/.local/share/golden/guide.md
    if not test -f $f
        echo "Нет $f — выполни chezmoi apply"
        return 1
    end
    if command -q glow
        glow -p $f
    else
        bat $f
    end
end
```

### `golden-practice.fish`
```fish
function golden-practice --description "Песочница для упражнений из golden-guide"
    set -l root ~/golden-practice
    set -l p $root/project

    if test -e $root
        read -l -P "$root уже есть. Пересоздать? [y/N] " ans
        test "$ans" = y; or return 0
        command rm -rf $root
    end

    mkdir -p $p/src $p/notes $p/logs $p/target/debug $p/.hidden

    printf '%s\n' \
        'fn main() {' \
        '    // TODO: разобрать аргументы командной строки' \
        '    let name = "world";' \
        '    println!("hello, {name}");' \
        '}' > $p/src/main.rs

    printf '%s\n' \
        '// TODO: покрыть тестами' \
        'pub fn add(a: i32, b: i32) -> i32 {' \
        '    a + b' \
        '}' > $p/src/lib.rs

    printf '%s\n' \
        '# Список дел' \
        '' \
        '- [ ] TODO: дописать README' \
        '- [ ] разобраться с логами' \
        '- [x] создать проект' > $p/notes/todo.md

    printf '%s\n' \
        '{' \
        '  "name": "practice",' \
        '  "servers": [' \
        '    { "name": "alpha", "port": 8080 },' \
        '    { "name": "beta",  "port": 3000 },' \
        '    { "name": "gamma", "port": 9000 }' \
        '  ]' \
        '}' > $p/config.json

    printf '%s\n' 'target/' > $p/.gitignore
    printf '%s\n' 'TODO: этот файл игнорируется git — fd и rg его не видят' > $p/target/debug/junk.txt
    printf '%s\n' 'скрытый файл: найди его через fd -H' > $p/.hidden/secret.txt

    for i in (seq 200)
        set -l lvl INFO
        if test (math $i % 17) -eq 0
            set lvl ERROR
        else if test (math $i % 5) -eq 0
            set lvl WARN
        end
        printf '2026-10-07 12:%02d:%02d %s request id=%d\n' (math "floor($i / 60)") (math $i % 60) $lvl $i
    end > $p/logs/app.log

    # ~2 МБ мусора — для упражнений с du/ncdu и fd -S
    head -c 2000000 /dev/urandom > $p/target/debug/big.bin

    git -C $p init -q
    git -C $p add .
    git -C $p -c user.name=practice -c user.email=practice@local commit -qm "init (TODO: этот текст попадёт в .git/)"

    echo "Готово: $root — начни с: cd $p; and golden-guide"
end
```

---

## 2. Старый план с кодом

# Core-план: Arch + Niri + Noctalia — сжатая версия

Источник: `system-plan-v3.md` (полная версия с обучающими пояснениями и
troubleshooting-рубрикой остаётся отдельно, как архив/справочник).
Этот файл — рабочая версия для дообсуждения и создания скрипта:
только принятые решения и конфиги, которые уже готовы к использованию.

---

## 1. Принятые решения

| Категория | Выбор | Причина |
|---|---|---|
| Дистрибутив | Arch Linux | Минимализм, AUR, обучение Linux |
| Compositor | Niri | Scrollable tiling, Wayland-native |
| Дисплейный менеджер | SDDM (тема catppuccin-sddm-theme-git) | Wayland-поддержка |
| Загрузчик | Limine | Легче GRUB. Обоснование "boot-into-snapshot" ВОЗВРАЩЕНО (2026-10) — `limine-snapper-sync` закрывает это и под Limine, см. раздел "Снапшоты — загрузочное меню" ниже |
| Шелл/панель | Noctalia v5 | Бар+уведомления+Control Center+lock+idle одним нативным бинарником |
| Терминал | kitty | GPU-рендеринг, inline-изображения |
| Браузер | Firefox | Единственный, `user.js` **готов** (DNS — системный, resolved DoT; DoH в самом Firefox выключен 2026-10, WebRTC no_host, VAAPI-декодирование, лёгкие приватность-твики, tracking protection, GPC) — собран из реального профиля пользователя |
| App launcher | fuzzel | Нативный Wayland, лёгкий |
| Обои | linux-wallpaperengine, ID **намеренно пустые** | Автозапуск готов принять ID, но ничего не предустановлено — заполняет и включает сам пользователь |
| Shell | fish | Промпт нативный, без внешнего бинарника |
| Редактор | neovim **без плагинов/init.lua** | Решено 2026-08: пользователь никогда им не пользовался, полноценная конфигурация не оправдана — голый редактор для быстрых правок |
| Редактор (доп.) | VSCodium (форк VS Code без телеметрии) | Заменил VS Code — см. п.3 ниже |
| Python | uv | Заменяет pip+venv |
| Версии языков | mise + direnv | Один менеджер, автоподгрузка per-project |
| Rust | rustup | Официальный установщик |
| Контейнеры | **только Podman** (Docker убран) | Rootless по умолчанию, без root-демона в фоне — совпадает с nftables/usbguard security-first подходом |
| Снапшоты/откат | snapper + btrfs: **10 обычных + 10 важных снапшотов** (≈5 последних любых pacman-операций + ≈5 последних обновлений ядра/драйверов/базы), `FREE_LIMIT=0.2` (изменено 2026-10, было NUMBER_LIMIT=2) | Исправлено 2026-08: раньше убрано по ошибке — "откаты" в исходном запросе относились к replay-буферу и бэкапу на внешний диск, не к системным снапшотам |
| OOM killer | systemd-oomd | Встроен, не требует AUR |
| Секреты | gnome-keyring + libsecret + gcr-ssh-agent (2026-10) | Прозрачно для git/SSH; пароль SSH-ключа — один раз, дальше из связки ключей |
| LUKS | **два разных момента, не один** (были слиты в одну строку — расхождение с разделом "Разметка диска" нашлось 2026-09): (1) *на этапе archinstall* диска ещё не существует, "детект в рантайме" физически невозможен — предлагается **на всех машинах** (изменено 2026-10, раньше только ноутбукам), но всегда с явным подтверждением пользователя, не автоматически; (2) *после установки* — `HAS_LUKS` в `run_once_before_00-detect-hw.sh` реально проверяет `lsblk`/`findmnt`, это уже факт про существующий раздел, пока информационный факт для будущих условных шагов (USBGuard с 2026-10 от LUKS не зависит — ставится везде) | Универсальность, не привязано к конкретной машине |
| Аудио | easyeffects: RNNoise на **микрофоне** + мягкая общая EQ-кривая на **выходе** (не привязана к модели наушников). Исправлено 2026-10: RNNoise раньше ошибочно стоял на выходе | Решено 2026-08: без AutoEq — общий Harman-подобный профиль вместо коррекции под конкретную модель |
| Удалённый доступ | RustDesk, **P2P без релея** (было: "self-hosted" — исправлено) | Никакой инфраструктуры для поддержки |
| Синхронизация | syncthing, папка `~/Projects/syncthing` создаётся, спаривание устройств — вручную после установки | P2P, без облака |
| Dotfiles | chezmoi | Git-трекинг конфигов + механизм персонализации (**см. todo**) |
| Тема | Catppuccin Mocha | Везде единообразно |
| Шрифты | JetBrainsMono Nerd Font + noto-fonts(+cjk+extra) | Решено 2026-08: максимальное покрытие Unicode, а не минимализм |
| Фаервол | nftables (голый ruleset) | Уже есть опыт, без лишней абстракции |
| Питание | power-profiles-daemon | Один демон, без конфликта governor |
| Ядро | linux-cachyos (основное) + **штатный `linux-lts` из Arch (fallback, изменено 2026-10)** — **ядро от CachyOS, но база — ванильный Arch** (устанавливается через archinstall, репозиторий CachyOS добавляется отдельно уже поверх, не через ISO/дистрибутив CachyOS) | BORE-планировщик + sched_ext, precompiled Nvidia-open модули под конкретно эту сборку ядра. Fallback из другого источника: если репозиторий CachyOS сломается или отстанет, `linux-lts` из Arch всё равно загрузится (раньше `linux-cachyos-lts` ломался бы вместе с основным). Nvidia под LTS — `nvidia-open-lts` (⚠️ сверить имя пакета; запасной вариант — `nvidia-open-dkms` + только `linux-lts-headers`, чтобы DKMS не пересобирал модуль поверх precompiled для cachyos) |
| Мультимонитор | Kanshi | Автопереключение, но профили **не сверены с реальным железом** |
| GPU-стек | **по детекту вендора** (Nvidia/AMD/Intel), не привязано к машине — **реализовано 2026-09** через `run_once_before_00-detect-hw.sh`, до этого было только строкой в таблице без кода | Универсальность — см. п.3 "Детект железа" и раздел "Игры" |
| VAAPI | **`libva-nvidia-driver` + `lib32-libva-nvidia-driver`** (официальный repo, не AUR — исправлено повторно 2026-08: это тот же elFarto-проект, просто под другим именем упаковки; AUR не нужен, плюс появилось 32-битное покрытие для игр) | Официальный пакет, без AUR |
| Устройства | **убрано понятие "ноут vs ПК" как хардкод** — всё через `hostnamectl chassis`/детект в рантайме | Требование универсальности (репозиторий должны мочь использовать другие люди) |

## 2. Пакеты — core / optional / conditional

**Core (ставится всегда):** вся база из категории выше + figlet, figlet-fonts, imagemagick, ttfx, plymouth (экран входа/скринсейвер, 2026-10), kitty, fuzzel, fish+zoxide+fzf+bat+eza+yazi+fd+ripgrep+jq, thunar+плагины, git+delta+lazygit, neovim (без плагинов), mise/uv/rustup, podman, syncthing, rustdesk-bin, steam+gamemode+mangohud+flatpak, firefox, **spotify-launcher, vesktop-bin**, **tzupdate, cliphist**, **cups+cups-pdf+avahi+nss-mdns+system-config-printer**, **okular**, **flatseal, bazaar**, **sshm, atuin**, **pacman-contrib** (checkupdates/paccache), **trash-cli** (cleanup-downloads), **usbguard** (с 2026-10 на всех машинах)

**Optional (выбор при установке через `.chezmoidata.yaml`/prompt):** heroic-games-launcher, onlyoffice-desktopeditors, bitwarden-bin, gnome-firmware, **qbittorrent, cryptomator, thunderbird**, **flclash** (личная VPN-подписка — 2026-09), **jdk-openjdk + intellij-idea-community-edition** (личный курс, не основной язык — 2026-09), **torbrowser-launcher, postgresql, mariadb, dbeaver, obs-studio, obsidian, anki, wireshark-qt, kicad** (перенесены из core 2026-10 — тяжёлые/узкоспециальные). `pamac-aur` — **убран 2026-10**, заменён на `pacsea-bin` (см. раздел "Пакетный менеджмент — pacsea").

**Conditional (по детекту железа):** nvidia-стек/envycontrol/ryzenadj/nvtop (только при Nvidia+гибрид) — **nvidia-powerd входит в nvidia-utils, требует только `systemctl enable --now`, см. раздел "CPU/GPU power-limit unlock"**, intel-media-driver (только Intel), LUKS-специфичные шаги (только если корень зашифрован)

**Ранее флагованные как возможно лишние — оба решены:** mihomo-party-bin (заменён на FlClash), noto-fonts-cjk (оставить)

**Убрано полностью (2026-08):** gpu-screen-recorder(+gtk) / replay-буфер — не нужен пользователю

## 3. Готовые конфиги (можно переносить в run_once as-is)

**Правила сборки (2026-10) — действуют на все блоки ниже:**
- `tee`-блоки с путями в `$HOME` и `/etc` — это **содержимое файлов**, а не
  команды для run_once. При сборке они становятся файлами chezmoi по правилу
  раскладки из раздела 4 (`~/.config/X` → `dot_config/X`, `/etc/X` →
  `system/etc/X`). Исключение — то, что генерируется по железу
  (`environment.d/vaapi.conf`, `gaming.conf`), — это пишет скрипт.
- Все установки — с `--needed` (повторный прогон не ломается), в
  неинтерактивном прогоне ещё и `--noconfirm`. Системные команды — через
  `sudo`: run_once запускается от пользователя. Исправлено массово — раньше
  часть `pacman -S`/`systemctl enable`/`snapper`/`mkfs` шла без sudo и упала бы.
- Факты о железе — `~/.local/state/chezmoi-hw-facts.env` (было `~/.cache`:
  кэш чистят сторонние утилиты, а без этого файла падают все остальные шаги).

### Детект железа (run_once_before_00-detect-hw.sh) — пишется впервые, закрывает audit-находку №1/№16
До этого момента слово "conditional" в плане нигде не подкреплялось кодом —
каждый раздел ниже либо содержал голый Nvidia-код без проверки, либо просто
комментарий "только если X" без единого `if`. Этот скрипт — единственная точка
детекта, остальные run_once-файлы просто читают её результат через `source`
(не пере-детектят каждый сам, чтобы логика не расползалась между файлами).

Пишет факты в `~/.local/state/chezmoi-hw-facts.env` (не `/etc/`, не root —
скрипт запускается от лица пользователя, `~` резолвится в его домашнюю папку,
тот же класс бага, что был в pacman-хуке).

**Исправлено 2026-10 (сверка):**
- GPU определяется по PCI vendor ID (`[10de:` Nvidia, `[1002:` AMD, `[8086:`
  Intel) вместо имени. Старая регулярка `amd|ati` совпадала с
  «Corpor**ati**on» и «comp**ati**ble» — `HAS_AMD` и `IS_HYBRID_GPU` были
  true на любой машине.
- Добавлен PCI-класс `[0380]` Display controller (так видны некоторые AMD dGPU).
- Отдельно `CPU_VENDOR` — ryzenadj зависит от процессора, а не от видеокарты.
- LUKS: `findmnt -v` (без суффикса `[/@]` btrfs-сабвольюма — с ним `lsblk`
  падал, и `HAS_LUKS` был всегда false) + `lsblk -s` по предкам (ловит и
  LUKS-под-LVM).
- `ROOT_DISK` — системный диск, нужен шагу "Второй диск" (там раньше была
  незаданная переменная).

```bash
#!/bin/bash
set -euo pipefail

FACTS_FILE="$HOME/.local/state/chezmoi-hw-facts.env"
mkdir -p "$(dirname "$FACTS_FILE")"

# --- Шасси ---
CHASSIS_RAW="$(hostnamectl chassis 2>/dev/null || true)"
CHASSIS_RAW="${CHASSIS_RAW:-unknown}"
case "$CHASSIS_RAW" in
    laptop|convertible|tablet) IS_LAPTOP=true ;;
    *) IS_LAPTOP=false ;;
esac

# --- CPU ---
case "$(awk -F': ' '/^vendor_id/{print $2; exit}' /proc/cpuinfo)" in
    AuthenticAMD) CPU_VENDOR=amd ;;
    GenuineIntel) CPU_VENDOR=intel ;;
    *)            CPU_VENDOR=unknown ;;
esac

# --- GPU: только классы VGA [0300] / 3D [0302] / Display [0380], вендор по PCI ID ---
GPU_LIST="$(lspci -nn 2>/dev/null | grep -E '\[03(00|02|80)\]' || true)"
HAS_NVIDIA=false; HAS_AMD=false; HAS_INTEL=false
grep -q '\[10de:' <<< "$GPU_LIST" && HAS_NVIDIA=true
grep -q '\[1002:' <<< "$GPU_LIST" && HAS_AMD=true
grep -q '\[8086:' <<< "$GPU_LIST" && HAS_INTEL=true

# гибрид = больше одного GPU-устройства (не вендора: AMD iGPU + AMD dGPU — тоже гибрид)
GPU_COUNT="$(grep -c . <<< "$GPU_LIST" || true)"
if [ "${GPU_COUNT:-0}" -gt 1 ]; then IS_HYBRID_GPU=true; else IS_HYBRID_GPU=false; fi

# --- Корень: LUKS и системный диск ---
ROOT_SRC="$(findmnt -nvo SOURCE / 2>/dev/null || true)"
HAS_LUKS=false
ROOT_DISK=""
if [ -n "$ROOT_SRC" ]; then
    lsblk -slno TYPE "$ROOT_SRC" 2>/dev/null | grep -qx crypt && HAS_LUKS=true
    ROOT_DISK="$(lsblk -slno NAME,TYPE "$ROOT_SRC" 2>/dev/null | awk '$2=="disk"{print $1; exit}')"
fi

printf '%s\n' \
    "CHASSIS=$CHASSIS_RAW" \
    "IS_LAPTOP=$IS_LAPTOP" \
    "CPU_VENDOR=$CPU_VENDOR" \
    "HAS_NVIDIA=$HAS_NVIDIA" \
    "HAS_AMD=$HAS_AMD" \
    "HAS_INTEL=$HAS_INTEL" \
    "IS_HYBRID_GPU=$IS_HYBRID_GPU" \
    "HAS_LUKS=$HAS_LUKS" \
    "ROOT_DISK=$ROOT_DISK" > "$FACTS_FILE"

echo "Детект железа записан в $FACTS_FILE:"
cat "$FACTS_FILE"
```
`HAS_NVIDIA`/`HAS_AMD`/`HAS_INTEL` — это **GPU**, процессор — только `CPU_VENDOR`.

Использование в любом другом run_once-скрипте — просто в начале файла:
```bash
source "$HOME/.local/state/chezmoi-hw-facts.env"
if $HAS_NVIDIA; then ...; fi
```
(`true`/`false` — реальные бинарники в PATH, `if $HAS_NVIDIA; then` — рабочая
конструкция, не опечатка.)

### Безопасность, zram, гибернация, nftables, usbguard — ✅ подтверждено 2026-08
```bash
sudo pacman -S --needed zram-generator
sudo tee /etc/systemd/zram-generator.conf << 'EOF'
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
EOF

# Своп-файл под гибернацию на btrfs (объём = RAM, вычисляется в рантайме,
# НЕ хардкодить конкретное число):
sudo btrfs subvolume create /swap
sudo chattr +C /swap
# free -m, не -g: -g округлял вниз, и своп-файл выходил меньше RAM (исправлено 2026-10)
sudo btrfs filesystem mkswapfile --size "$(free -m | awk '/^Mem:/{print $2}')M" --uuid clear /swap/swapfile
sudo swapon /swap/swapfile
echo "/swap/swapfile none swap defaults,pri=-2 0 0" | sudo tee -a /etc/fstab
SWAP_UUID=$(findmnt -no UUID -T /swap)
SWAP_OFFSET=$(sudo btrfs inspect-internal map-swapfile -r /swap/swapfile | grep -oP '(?<=resume_offset=)\d+')

# Параметры ядра — исправлено 2026-10: раньше sed правил /etc/kernel/cmdline
# вслепую, а на свежей установке с Limine этого файла может не быть (set -e →
# падение). limine-mkinitcpio-hook (ставится в 02, то есть раньше этого шага)
# берёт cmdline из /etc/default/limine, /etc/kernel/cmdline — запасной вариант.
# ⚠️ Не проверено вживую — сверить после установки, какой файл реально читается.
RESUME_ARGS="resume=UUID=${SWAP_UUID} resume_offset=${SWAP_OFFSET}"
if grep -q '^KERNEL_CMDLINE\[default\]' /etc/default/limine 2>/dev/null; then
    grep -q 'resume=' /etc/default/limine || \
        sudo sed -i -E "s|^(KERNEL_CMDLINE\[default\]\+?=\"[^\"]*)\"|\1 ${RESUME_ARGS}\"|" /etc/default/limine
elif [ -f /etc/kernel/cmdline ]; then
    grep -q 'resume=' /etc/kernel/cmdline || \
        sudo sed -i "s|\$| ${RESUME_ARGS}|" /etc/kernel/cmdline
else
    echo "ОШИБКА: не найден ни KERNEL_CMDLINE в /etc/default/limine, ни /etc/kernel/cmdline." >&2
    echo "Добавь в параметры ядра вручную: ${RESUME_ARGS}" >&2
    exit 1
fi

# resume-хук — исправлено 2026-10, зависит от типа initramfs. Современный
# дефолт mkinitcpio — systemd-based (в HOOKS есть `systemd`, нет `udev`): там
# resume делает сам systemd, отдельного хука нет и он не нужен — старый sed
# искал `udev`, не находил и валил весь шаг. Вариант на busybox (HOOKS с
# `udev`) — как было: `resume` сразу после udev, идемпотентно, с жёсткой
# проверкой результата.
if grep -qE '^HOOKS=.*\bsystemd\b' /etc/mkinitcpio.conf; then
    echo "initramfs на systemd — resume-хук не нужен"
elif grep -qE '^HOOKS=.*\budev\b' /etc/mkinitcpio.conf; then
    grep -qE '^HOOKS=.*\bresume\b' /etc/mkinitcpio.conf || \
        sudo sed -i -E 's/^(HOOKS=\([^)]*\budev\b)/\1 resume/' /etc/mkinitcpio.conf
    if ! grep -qE '^HOOKS=.*\bresume\b' /etc/mkinitcpio.conf; then
        echo "ОШИБКА: resume-хук не добавился автоматически. Добавь 'resume' в HOOKS" >&2
        echo "вручную (после udev), затем перезапусти этот шаг." >&2
        exit 1
    fi
else
    echo "ОШИБКА: HOOKS в /etc/mkinitcpio.conf в неожиданном формате — проверь вручную." >&2
    exit 1
fi

sudo mkinitcpio -P

sudo tee /etc/systemd/logind.conf.d/99-battery.conf << 'EOF'
[Login]
HandleLidSwitch=suspend
CriticalBatteryAction=hibernate
CriticalBatteryActionDelaySec=30
EOF
sudo systemctl restart systemd-logind
sudo systemctl enable --now systemd-oomd

sudo pacman -S --needed nftables
sudo tee /etc/nftables.conf << 'EOF'
#!/usr/bin/nft -f
flush ruleset
table inet filter {
    set lan4 {
        type ipv4_addr; flags interval
        elements = { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 }
    }
    chain input {
        type filter hook input priority 0; policy drop;
        ct state established,related accept
        ct state invalid drop
        iif "lo" accept
        icmp type echo-request accept
        icmpv6 type { echo-request, destination-unreachable, packet-too-big, time-exceeded, parameter-problem, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } accept
                                           # исправлено 2026-10: без nd-router-advert
                                           # не работает IPv6 SLAAC (адрес не
                                           # поднимается); остальное — штатный
                                           # набор ArchWiki (PMTU и ошибки)
        ip6 saddr fe80::/10 udp dport 546 accept   # ответы DHCPv6-сервера
        # LAN-сервисы — только из приватных подсетей (изменено 2026-10): раньше
        # были открыты на любой сети, включая публичный Wi-Fi. Доступ вне дома
        # пойдёт через VPN-интерфейс — правило добавится вместе с VPN (см. todo).
        # Syncthing 22000 + обнаружение 21027, mDNS 5353
        # (KDE Connect и LocalSend убраны из проекта 2026-10 — их порты тоже)
        ip saddr @lan4 tcp dport 22000 accept
        ip saddr @lan4 udp dport { 22000, 21027, 5353 } accept
        ip6 saddr fe80::/10 tcp dport 22000 accept
        ip6 saddr fe80::/10 udp dport { 22000, 21027, 5353 } accept
        # RustDesk: входящие порты убраны (2026-10) — 21115-21119 серверные,
        # клиент их не слушает; связь пойдёт через свой hbbs/hbbr на арендованном
        # сервере (только исходящие соединения).
        # mDNS — нужен avahi/cups для обнаружения
                                           # сетевых принтеров (audit-находка №14);
                                           # multicast-ответы ненадёжно ловятся через
                                           # ct state established,related
        # Входящий SSH (22/tcp) — осознанно НЕ открыт (audit-находка №15,
        # решение подтверждено 2026-09): весь удалённый доступ — через
        # RustDesk, отдельного входа по SSH на эти машины снаружи не нужно
    }
    chain forward { type filter hook forward priority 0; policy drop; }
    chain output { type filter hook output priority 0; policy accept; }
}
EOF
sudo nft -c -f /etc/nftables.conf
sudo systemctl enable --now nftables

sudo tee /etc/systemd/resolved.conf > /dev/null << 'EOF'
[Resolve]
DNS=9.9.9.9#dns.quad9.net
FallbackDNS=1.1.1.1#cloudflare-dns.com
DNSOverTLS=yes
DNSSEC=allow-downgrade
EOF
# enable — исправлено 2026-10: раньше был только restart; если archinstall не
# включил resolved, после симлинка ниже DNS пропал бы полностью.
# DoT строгий — про captive-порталы см. README.
sudo systemctl enable --now systemd-resolved
sudo systemctl restart systemd-resolved
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# usbguard — на всех машинах (решено 2026-10; раньше условно на LUKS, но защита
# от BadUSB от шифрования диска не зависит).
# Порядок исправлен 2026-10: раньше enable шёл ДО generate-policy — с пустым
# rules.conf и дефолтным ImplicitPolicyTarget=block клавиатура и мышь
# отваливались сразу. Теперь: пакет → политика → только потом демон.
# Предупреждение перед generate-policy (audit-находка №10) сохранено.
sudo pacman -S --needed usbguard

echo "USBGuard: allow-политика будет построена из USB-устройств, подключённых ПРЯМО СЕЙЧАС."
echo "Отключи всё лишнее (чужие флешки/кабели) и оставь только клавиатуру/мышь/встроенные устройства."
read -rp "Готово? Нажми Enter, чтобы сгенерировать политику: "

sudo usbguard generate-policy | sudo tee /etc/usbguard/rules.conf > /dev/null
sudo chmod 600 /etc/usbguard/rules.conf
sudo systemctl enable --now usbguard

# Уведомления "разрешить/запретить" для нового USB. Notifier'у нужны IPC-права
# пользователя, без них он молча ничего не показывает.
# ⚠️ Флаги add-user сверить с README usbguard-notifier после установки.
sudo usbguard add-user "$USER" --devices ALL --policy list --exceptions listen
sudo systemctl restart usbguard
paru -S --needed usbguard-notifier
systemctl --user enable --now usbguard-notifier
```

### fontconfig — ✅ подтверждено 2026-08
```bash
sudo pacman -S --needed noto-fonts noto-fonts-emoji noto-fonts-cjk noto-fonts-extra
paru -S --needed ttf-jetbrainsmono-nerd
fc-cache -f -v
```
```xml
<!-- ~/.config/fontconfig/fonts.conf -->
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <alias>
    <family>sans-serif</family>
    <prefer><family>Noto Sans</family><family>Noto Color Emoji</family></prefer>
  </alias>
  <alias>
    <family>serif</family>
    <prefer><family>Noto Serif</family><family>Noto Color Emoji</family></prefer>
  </alias>
  <alias>
    <family>monospace</family>
    <prefer><family>JetBrainsMono Nerd Font</family><family>Noto Color Emoji</family></prefer>
  </alias>
</fontconfig>
```

### Игры — gamemode/scx, VAAPI, MangoHud — ✅ подтверждено 2026-08 (gamescope убран: минусы перевешивали, конкретные проблемы с курсором/Alt-Tab/чёрным экраном при выходе); GPU-ветки — 2026-09, закрывает audit-находку №1
```bash
source "$HOME/.local/state/chezmoi-hw-facts.env"

sudo pacman -S --needed scx-scheds
sudo pacman -S --needed scx-tools
sudo systemctl enable --now scx_loader.service
grep -q '^\[custom\]' /etc/gamemode.ini 2>/dev/null || sudo tee -a /etc/gamemode.ini << 'EOF'

[custom]
start=scxctl switch -s lavd
end=scxctl switch -s bpfland
EOF

mkdir -p ~/.config/environment.d/
sudo pacman -S --needed libva-utils

# --- VAAPI по вендору — исправлено 2026-10 для гибридов. Пакеты ставятся под
# все найденные GPU, но LIBVA_DRIVER_NAME (одна на сессию) на гибриде теперь
# отдаётся iGPU, а не Nvidia: иначе Firefox/mpv декодируют на dGPU, RTD3 не
# даёт ему уснуть, и батарея садится заметно быстрее. Nvidia получает
# LIBVA_DRIVER_NAME, только если она единственная GPU (десктоп).
# Разово декодировать на dGPU на гибриде:
#   LIBVA_DRIVER_NAME=nvidia NVD_BACKEND=direct <приложение>
# Эти файлы НЕ под chezmoi — генерируются по железу (см. раздел 4).

VAAPI_CONF="$HOME/.config/environment.d/vaapi.conf"

if $HAS_NVIDIA; then
    # lib32-nvidia-utils перенесён сюда из "Игры — основной стек" (раньше ставился всем)
    sudo pacman -S --needed libva-nvidia-driver lib32-libva-nvidia-driver lib32-nvidia-utils
    printf '%s\n' __GL_GSYNC_ALLOWED=1 __GL_VRR_ALLOWED=1 PROTON_ENABLE_NGX_UPDATER=1 \
        DXVK_ENABLE_NVAPI=1 PROTON_ENABLE_NVAPI=1 > ~/.config/environment.d/gaming.conf
fi

if $HAS_AMD; then
    # ⚠️ сверить при сборке: в свежих сборках Arch libva-mesa-driver/mesa-vdpau
    # могли быть поглощены пакетом mesa — тогда pacman не найдёт эти имена
    sudo pacman -S --needed libva-mesa-driver lib32-libva-mesa-driver mesa-vdpau lib32-mesa-vdpau vulkan-radeon lib32-vulkan-radeon
fi

if $HAS_INTEL; then
    sudo pacman -S --needed intel-media-driver vulkan-intel lib32-vulkan-intel
    # старые Intel iGPU (до Broadwell/Gen8) intel-media-driver не поддерживает —
    # для них нужен legacy libva-intel-driver, редкий случай, руками
fi

if $HAS_NVIDIA && ! $IS_HYBRID_GPU; then
    printf '%s\n' NVD_BACKEND=direct LIBVA_DRIVER_NAME=nvidia VDPAU_DRIVER=nvidia > "$VAAPI_CONF"
elif $HAS_AMD; then
    printf '%s\n' LIBVA_DRIVER_NAME=radeonsi VDPAU_DRIVER=radeonsi > "$VAAPI_CONF"
elif $HAS_INTEL; then
    printf '%s\n' LIBVA_DRIVER_NAME=iHD > "$VAAPI_CONF"
fi

# --- envycontrol — только реально гибридные ноуты (Intel/AMD iGPU + Nvidia dGPU) ---
if $IS_LAPTOP && $IS_HYBRID_GPU && $HAS_NVIDIA; then
    paru -S --needed envycontrol
    # Wayland-сессии (Niri) у envycontrol по умолчанию и так уходят в hybrid,
    # но фиксируем явно — детерминированность важнее краткости:
    sudo envycontrol -s hybrid --rtd3
fi

mkdir -p ~/.config/MangoHud/
tee ~/.config/MangoHud/MangoHud.conf << 'EOF'
fps
fps_limit=0
gpu_stats
gpu_temp
gpu_mem_temp
cpu_stats
cpu_temp
ram
vram
frametime
hud_no_margin
font_size=24
position=top-left
background_alpha=0.4
EOF
```

### GTK/Qt-темизация — ✅ подтверждено 2026-08; переключаемый набор из 3 схем — подтверждено 2026-09
```bash
sudo pacman -S --needed qt5ct qt6ct
paru -S --needed kvantum papirus-icon-theme papirus-folders

# три схемы устанавливаются разом — это и есть набор для "Переключателя
# тем" ниже, не просто одна активная плюс про запас:
paru -S --needed catppuccin-gtk-theme-mocha catppuccin-cursors-mocha
paru -S --needed colloid-dracula-gtk-theme-git colloid-cursors colloid-icon-theme
paru -S --needed nordic-theme   # реальный AUR-пакет (не git-clone вручную, как у Tokyo Night — из-за этого он и не выбран)

papirus-folders -C cat-mocha-blue --theme Papirus-Dark

# Активная схема по умолчанию — Dracula (решено 2026-09):
gsettings set org.gnome.desktop.interface icon-theme 'Colloid-icon-theme-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Colloid-Dracula-Dark'
gsettings set org.gnome.desktop.interface cursor-theme 'Colloid-cursors-dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface font-name 'Noto Sans 11'

mkdir -p ~/.config/environment.d/
tee ~/.config/environment.d/qt.conf << 'EOF'
QT_QPA_PLATFORMTHEME=qt6ct
QT_STYLE_OVERRIDE=kvantum
EOF
```
Точные строки-имена тем/курсоров/иконок у Colloid и Nordic пакетов **не
проверены вживую** (у Colloid обычно паттерн `Colloid-<акцент>-Dark`, но
могут быть варианты) — после установки сверить через
`gsettings get org.gnome.desktop.interface gtk-theme` и содержимое
`/usr/share/themes/`, если название выше не подойдёт один в один.

Покрывает только GTK+Qt-софт (через GSettings/dconf и qt6ct+kvantum
соответственно) — Electron/CEF/Flutter-приложения (VS Code, vesktop, Heroic,
Spotify, Cryptomator, FlClash) сюда не входят, у каждого своя
система тем, единая автоматизация под них не планируется — см. ниже,
раздел Noctalia.

### Noctalia (панель/шелл) — 2026-09, первая реализация
```bash
paru -S --needed noctalia-qs
systemctl --user enable --now noctalia
```
**Базовая тема — Dracula** (решено 2026-09, пересмотрено с нуля — было
Catppuccin Mocha, Catppuccin остаётся доступным вариантом переключения,
не убран). Схема **фиксированная, не по обоям** — обои и цветовая тема
живут независимо друг от друга, смена обоев не трогает палитру.

GTK-пакет под Dracula — **подтверждено 2026-09**: `colloid-dracula-gtk-theme-git`
(живой, с курсором/иконками в комплекте) вместо заброшенного
`dracula-gtk-theme` (с 2023 без обновлений) — см. GTK/Qt-раздел выше, где
он уже установлен вместе с Catppuccin и Nord (`nordic-theme`) как три
переключаемые схемы.

Noctalia настраивается **независимо** от GTK/Qt-стека — **подтверждено
2026-09** — каждый сам по себе выставляется на одинаковые цвета, не через
встроенную у Noctalia систему App Theming, чтобы не переписывать уже
рабочий GTK/Qt/kitty-конфиг.

**Точный путь применения — через `Settings → Appearance → Color Scheme`
внутри самой Noctalia после установки, не ручной правкой TOML-файла.**
Причина: разные источники по-разному описывают точное имя/путь
конфиг-файла для этой версии (то ли `settings.toml`, то ли отдельный
`colors`-файл) — вместо того чтобы гадать и один раз выдать нерабочий
конфиг, надёжнее один раз пройти через живой UI, который сам запишет
корректный файл. Практически:
1. Открыть Settings → Appearance → Color Scheme
2. Поискать "Dracula" среди встроенных/community-палитр
3. Если готовой палитры нет — community-репозиторий
   `LePetitPrince-4/base16-noctalia` содержит набор base16-палитр
   (base16-экосистема покрывает Dracula, Catppuccin и Nord) — скопировать
   нужный файл в `~/.config/noctalia/palettes/` и выбрать как custom

Бар/панель/OSD/lock/idle — дефолтные модули Noctalia. **Состав виджетов —
решено, 2026-10** (визуальный ориентир — эстетика Omarchy/тема Vantablack,
снята с реального ноута пользователя: Omarchy 4.0.4, монохромная чёрно-белая
палитра). Подробности — ниже, раздел "Noctalia — финальный конфиг бара/темы/лаунчера".

### Переключатель тем — этап плана, не реализовано (2026-09)
Цель: одна команда переключает **разом** kitty + GTK/Qt + иконки/курсор +
Noctalia на выбранную схему — не переустанавливая и не переписывая конфиги
вручную каждый раз. Ключевое требование: **не хардкодить список схем** —
скрипт должен сам обнаруживать, что реально установлено на данный момент
(новую GTK-тему скачал — она сама появляется как вариант переключения,
без правки самого скрипта).

**Переключаемый набор — подтверждено 2026-09: Catppuccin + Dracula +
Nord** (три схемы, уже устанавливаются вместе в GTK/Qt-разделе выше).
Дальше можно расширять тем же способом — добавить ещё схему означает
просто найти для неё реальный AUR/pacman-пакет (не git-clone вручную,
как оказалось у Tokyo Night — из-за этого её не взяли) и добавить в тот же
`paru -S` в GTK/Qt-разделе, сам переключатель не потребует правки.

Черновой подход (детали и реализация — отдельным шагом, не сейчас):
- kitty: `kitty +kitten themes --dump-list` (или аналог) уже умеет
  перечислять все доступные темы сам — просто фильтруем по тем, что
  реально хотим предлагать
- GTK/Qt: сканировать `/usr/share/themes/` — там лежат все установленные
  темы, и есть по имени сопоставить с нужной
- Noctalia: сканировать `~/.config/noctalia/palettes/` + то, что показывает
  сама Settings — как именно дёрнуть переключение не через UI, а из
  скрипта, ещё предстоит выяснить (не факт, что у Noctalia есть CLI для
  этого, а не только GUI)
- Итоговая команда — fish-функция (`theme-switch <имя>` или подобное),
  без хардкод-списка, только динамическое обнаружение

### PipeWire — фикс щелчков звука — ✅ подтверждено 2026-08; перенесено в пользовательский конфиг 2026-10
Файл chezmoi `dot_config/pipewire/pipewire.conf.d/99-clock-rate.conf` —
вместо `/etc/pipewire/...`: точечно для пользователя, без системного файла и sudo.
```
context.properties = {
    default.clock.rate          = 48000
    default.clock.allowed-rates = [ 48000 ]
    default.clock.quantum       = 1024
    default.clock.min-quantum   = 512
    default.clock.max-quantum   = 2048
}
```
После `chezmoi apply`: `systemctl --user restart pipewire pipewire-pulse wireplumber`.

### fish + CLI-инструменты — ✅ подтверждено 2026-08
```bash
sudo pacman -S --needed fish zoxide fzf fastfetch
paru -S --needed fish-autopair
sudo pacman -S --needed bat eza yazi fd ripgrep jq

sudo chsh -s /usr/bin/fish "$USER"   # sudo — без него интерактивный запрос пароля ломает run_once
```

Конфиги ниже — **файлы в chezmoi-репозитории**, не `tee` из скрипта (решено
2026-10, см. раздел 4). Раньше mise/direnv/sccache дописывались в
`config.fish` через `echo >>` из других блоков: при повторном прогоне строки
дублировались, а `chezmoi apply` затёр бы такие правки. Теперь всё в одном
файле. Плюс исправлено: atuin ставился, но нигде не инициализировался.

`dot_config/fish/config.fish`:
```fish
# --- окружение: и для интерактивных шеллов, и для скриптов ---
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/gcr/ssh"   # gcr-ssh-agent
set -gx DOCKER_HOST "unix://$XDG_RUNTIME_DIR/podman/podman.sock"   # чтобы lazydocker видел Podman
set -gx RUSTC_WRAPPER sccache

if status is-interactive
    set -g fish_greeting ""

    mise activate fish | source
    direnv hook fish | source
    zoxide init fish --cmd cd | source   # zoxide теперь и есть cd
    fzf --fish | source                  # Ctrl+T — файлы, Alt+C — переход в папку
    atuin init fish | source             # после fzf — забирает себе Ctrl+R
    fish_autopair_init                   # ⚠️ сверить: AUR-пакет может подключаться сам через vendor_conf.d, и такой функции нет
    fastfetch

    alias ls='eza --icons --group-directories-first'
    alias ll='eza -la --icons --group-directories-first --git'
    alias la='eza -a --icons'
    alias lt='eza --tree --icons --level=2'
    alias cat='bat --style=numbers'
    # grep/find НЕ подменяются (2026-10): у rg и fd другой синтаксис —
    # `rg`/`fd` вызываются под своими именами, шпаргалка — `golden-guide`
    alias lg='lazygit'
    alias ld='lazydocker'
    alias code='codium --ozone-platform=wayland --enable-features=WaylandWindowDecorations'
end
```

`dot_config/fish/functions/fish_prompt.fish`:
```fish
function fish_prompt
    set -l last_status $status
    set -l cwd (set_color cyan)(prompt_pwd)(set_color normal)
    set -l git_branch ""
    if git rev-parse --is-inside-work-tree &>/dev/null
        set git_branch (set_color yellow)" ("(git branch --show-current 2>/dev/null)")"(set_color normal)
    end
    set -l status_color (set_color green)
    if test $last_status -ne 0
        set status_color (set_color red)
    end
    echo -n "$cwd$git_branch $status_color❯ "(set_color normal)
end
```

### chezmoi — применение готового репозитория (не авторская сборка) — ✅ подтверждено 2026-08
```bash
sudo pacman -S --needed chezmoi
chezmoi init <URL_вашего_репозитория>
chezmoi apply
```
Оригинал описывал обратный процесс (`chezmoi add` + создание репозитория с
нуля) — это workflow для первичной сборки дотфайлов, не для `run_once`.
Здесь — только применение уже готового репозитория на целевой машине.

### fuzzel — ✅ подтверждено 2026-08
```ini
# ~/.config/fuzzel/fuzzel.ini
[main]
font=JetBrainsMono Nerd Font:size=12
terminal=kitty
width=35
lines=10
tabs=4
horizontal-pad=12
vertical-pad=8
inner-pad=6
image-size-ratio=0.4

[colors]
background=1e1e2eff
text=cdd6f4ff
match=89b4faff
selection=313244ff
selection-text=cdd6f4ff
border=6c7086ff

[border]
width=1
radius=6

[dmenu]
exit-immediately-if-empty=yes
```

### kitty — ✅ подтверждено 2026-08; тема — 2026-09, закрывает audit-находку №16
```bash
mkdir -p ~/.config/kitty/
# Начиная с kitty 0.26.0 все темы Catppuccin уже встроены — отдельно качать
# с GitHub не нужно вообще (раньше тянули с ветки main без пиннинга на
# коммит — невоспроизводимая сборка). Официальный путь через сам kitty:
kitty +kitten themes --reload-in=all "Catppuccin-Mocha"
tee ~/.config/kitty/kitty.conf << 'EOF'
include current-theme.conf
font_family      JetBrainsMono Nerd Font
bold_font        auto
italic_font      auto
bold_italic_font auto
font_size        12.0
background_opacity 0.92
dynamic_background_opacity yes
scrollback_lines 10000
enable_audio_bell no
visual_bell_duration 0.0
window_alert_on_bell no
tab_bar_style powerline
tab_powerline_style slanted
cursor_blink_interval 0
mouse_hide_wait 3.0
confirm_os_window_close 0
update_check_interval 0
open_url_with default
EOF
```

### Git — ✅ подтверждено 2026-08 (identity убрана — живёт только в 99-secrets-interactive; pre-commit убран отсюда — ставится через uv)
```bash
sudo pacman -S --needed git git-delta lazygit
git config --global core.pager "delta"
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
git config --global delta.line-numbers true
git config --global delta.side-by-side true
git config --global merge.conflictstyle diff3
git config --global diff.colorMoved default
git config --global pull.rebase true
git config --global rebase.autoStash true
git config --global init.defaultBranch main

paru -S --needed git-credential-libsecret
git config --global credential.helper /usr/lib/git-core/git-credential-libsecret
```

### mise / uv / rustup — ✅ подтверждено 2026-08 (mise должен идти строго после блока fish — зависимость по порядку); все три через пакеты вместо `curl|sh` — 2026-09, закрывает audit-находку №8
```bash
# mise — AUR (официального пакета в repo нет, но mise-bin активно поддерживается),
# ОБЯЗАТЕЛЬНО после run_once fish-блока (4.1), дописывает config.fish:
paru -S --needed mise-bin
sudo pacman -S --needed direnv
# Хуки mise/direnv — уже в dot_config/fish/config.fish (блок fish).
# Глобальный конфиг mise — файл chezmoi dot_config/mise/config.toml:
#   [tools]
#   node = "lts"
# Python из mise убран 2026-10: им управляет uv, а README прямо запрещает
# ставить mise-плагины python/rust поверх (иначе неясно, какой активен).
mise install

# uv — официальный пакет в extra, не AUR (примеры команд uv add/run/sync — в README, не в скрипте):
sudo pacman -S --needed uv
uv tool install pre-commit
uv tool install ruff
uv tool install mypy

# rustup — официальный пакет в extra. Ставит прокси-бинарники (cargo/rustc/...)
# прямо в /usr/bin, которые сами диспетчеризуют на активный toolchain в
# ~/.rustup — в отличие от curl-инсталлятора, `source ~/.cargo/env` тут
# не нужен, PATH уже настроен пакетом:
sudo pacman -S --needed rustup
rustup default stable
rustup component add rust-analyzer clippy rustfmt llvm-tools
cargo install cargo-watch cargo-audit cargo-expand cargo-zigbuild flamegraph sccache
# RUSTC_WRAPPER=sccache — в dot_config/fish/config.fish
sudo pacman -S --needed mold clang perf   # perf — для flamegraph; linux-tools на Arch не устанавливается как пакет (исправлено 2026-10)

mkdir -p ~/.cargo/
tee ~/.cargo/config.toml << 'EOF'
[target.x86_64-unknown-linux-gnu]
linker = "clang"
rustflags = ["-C", "link-arg=-fuse-ld=mold"]

[profile.dev]
opt-level = 0

[profile.release]
opt-level = 3
lto = true
codegen-units = 1
EOF
```

### Сеть и Bluetooth — ✅ подтверждено 2026-08
```bash
sudo pacman -S --needed nm-connection-editor
sudo pacman -S --needed bluez bluez-utils blueman
sudo systemctl enable --now bluetooth
```

### Питание — ✅ подтверждено 2026-08 (ryzenadj — conditional на chassis==laptop; TLP решён — не ставим)
```bash
sudo pacman -S --needed power-profiles-daemon
sudo systemctl enable --now power-profiles-daemon
sudo pacman -S --needed lm_sensors
sudo sensors-detect --auto

# Порог заряда батареи — БЕЗ TLP (конфликтует с power-profiles-daemon на
# уровне пакетов на Arch, а не просто в рантайме — pacman не даст поставить
# оба). Только нативный sysfs, если железо поддерживает.
#
# Значение в sysfs сбрасывается на каждой холодной загрузке (EC/прошивка не
# всегда его хранит) — та же природа проблемы, что была у ryzenadj
# (audit-находка №5): разовая команда в install-скрипте отрабатывает один
# раз и молча теряет силу после следующего ребута. Оборачиваем в systemd
# oneshot, тем же паттерном, что уже сделан для ryzenadj.
#
# Проверка на поддержку — прямо внутри unit-файла, не в install-скрипте:
# так фикс не зависит от того, на каком именно железе ставился репозиторий —
# сервис сам решает при каждом запуске, применять ли что-то, вместо того
# чтобы install-скрипт один раз решил это за него.
sudo tee /etc/systemd/system/battery-threshold.service << 'EOF'
[Unit]
Description=Set battery charge threshold (80%) if supported by hardware
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'for f in /sys/class/power_supply/BAT*/charge_control_end_threshold; do [ -f "$$f" ] && echo 80 > "$$f"; done; exit 0'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable --now battery-threshold.service
# BAT* вместо хардкода BAT0 (2026-10: у части ноутбуков батарея — BAT1);
# `$$` — экранирование `$` для systemd, в sh попадает обычный `$f`.
# на десктопе батареи просто нет — сервис включится, но его ExecStart
# ничего не сделает и завершится успешно (exit 0), это ожидаемо, не ошибка
```

### CPU/GPU power-limit unlock — ✅ подтверждено 2026-09 на ноуте Colorfire (Ryzen 9 7845HX + RTX 4070 Laptop), conditional на chassis==laptop + вендор CPU/GPU
Реальный кейс: без этого CPU залипал на ~544MHz под нагрузкой на зарядке, GPU был
зажат в 24W. Проверено эмпирически через `btop`/`nvidia-smi` под реальной
нагрузкой (игра) — после фикса CPU держит 3.8GHz@55W (72-77°C, запас до
`tctl-temp=95` есть), GPU отдаёт 105W@73°C под 99% загрузкой.

**Важно: числа STAPM/fast/slow/tctl ниже — специфичны для 7845HX. Это НЕ
универсальные константы** — см. открытый вопрос ниже про перенос на другое
железо.

**Найдена и закрыта ещё одна проблема (2026-09): раньше `ryzenadj` применял
одни и те же агрессивные лимиты ВСЕГДА, не глядя на AC/батарею** — заводская
прошивка сама снижает лимиты CPU на батарее, а статичный `ryzenadj` этот
механизм полностью перебивал. На батарее под нагрузкой CPU мог жрать те же
54-65W, что и на розетке — быстрая разрядка ровно тогда, когда этого меньше
всего ждёшь. GPU-сторону (`nvidia-powerd`) это не касается — Dynamic Boost
сам по себе согласуется с SBIOS в реальном времени и не даёт буст на
батарее (это видно по строке в логе "...requested to disable Dynamic Boost
DC controller" — это про DC, то есть батарею), мы там ничего статично не
перебивали.

```bash
source "$HOME/.local/state/chezmoi-hw-facts.env"

# --- CPU: ryzenadj (AUR), только ноутбук + процессор AMD. Исправлено 2026-10:
# раньше условие было по AMD *GPU* — на Intel-ноуте с AMD dGPU ставился зря,
# а на Ryzen в dGPU-only (MUX) режиме iGPU не виден и ryzenadj не ставился ---
if $IS_LAPTOP && [ "$CPU_VENDOR" = amd ]; then
    paru -S --needed ryzenadj
    # опционально, для надёжности вместо fallback на /dev/mem (см. audit-находку —
    # на первом тесте ryzenadj сам сообщил "no compatible ryzen_smu kernel module
    # found, fallback to /dev/mem" — работает, но грязнее):
    # paru -S ryzen_smu-dkms-git

    # Единый скрипт вместо дублирования команды в трёх местах (boot/sleep/udev) —
    # сам проверяет текущее состояние AC и выбирает нужный профиль.
    # ВАЖНО: AC-профиль (54000/65000/54000) — подтверждён эмпирически (см. выше).
    # Battery-профиль (15000/25000/15000) — НЕ проверен, это консервативная
    # отправная точка, а не готовое решение — см. открытый вопрос про то, что
    # требует твоего участия.
    sudo tee /usr/local/bin/ryzenadj-apply.sh << 'EOF'
#!/bin/bash
AC_ONLINE=1
for supply in /sys/class/power_supply/*/; do
    if [ -f "${supply}type" ] && grep -q "Mains" "${supply}type" 2>/dev/null; then
        AC_ONLINE=$(cat "${supply}online" 2>/dev/null || echo 1)
        break
    fi
done

if [ "$AC_ONLINE" = "1" ]; then
    /usr/bin/ryzenadj --stapm-limit=54000 --fast-limit=65000 --slow-limit=54000 --tctl-temp=95
else
    /usr/bin/ryzenadj --stapm-limit=15000 --fast-limit=25000 --slow-limit=15000 --tctl-temp=95
fi
EOF
    sudo chmod +x /usr/local/bin/ryzenadj-apply.sh

    sudo tee /etc/systemd/system/ryzenadj-apply.service << 'EOF'
[Unit]
Description=Apply RyzenAdj power limits based on current AC/battery state
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/ryzenadj-apply.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    # переприменяем на sleep/resume (значения слетают не только на ребуте):
    sudo tee /usr/lib/systemd/system-sleep/ryzenadj-resume.sh << 'EOF'
#!/bin/sh
case "$1" in
    post) /usr/local/bin/ryzenadj-apply.sh ;;
esac
EOF
    sudo chmod +x /usr/lib/systemd/system-sleep/ryzenadj-resume.sh

    # udev-правило — реагирует СРАЗУ на физическое подключение/отключение
    # зарядки, не дожидаясь ребута или sleep-цикла. RUN+= с restart (не
    # start!) — юнит с RemainAfterExit=yes иначе не перезапустится повторно,
    # так как systemd считает его уже "active". --no-block (2026-10) — udev не
# должен ждать завершения юнита, иначе событие может отвалиться по таймауту:
    sudo tee /etc/udev/rules.d/99-ryzenadj-power.rules << 'EOF'
SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", RUN+="/usr/bin/systemctl --no-block restart ryzenadj-apply.service"
SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="0", RUN+="/usr/bin/systemctl --no-block restart ryzenadj-apply.service"
EOF
    sudo udevadm control --reload-rules

    sudo systemctl enable --now ryzenadj-apply.service
fi

# --- GPU: nvidia-powerd (Dynamic Boost), уже входит в пакет nvidia-utils —
# отдельно ставить не нужно, только включить, и только если реально Nvidia ---
if $HAS_NVIDIA; then
    sudo systemctl enable --now nvidia-powerd
    # ожидаемо (не баг): journalctl -u nvidia-powerd может показать
    # "ERROR! Client (presumably SBIOS) has requested to disable Dynamic Boost DC
    # controller" — это про боевой режим от батареи (DC), безобидно на AC-питании.
fi
```

Значения `--stapm-limit`/`--fast-limit`/`--slow-limit`/`--tctl-temp` внутри
блока по-прежнему жёстко зашиты под 7845HX — сам факт "это Ryzen на ноуте"
детектится рантаймом, а конкретные ватты — нет (сам детект чисел без
измерений на месте недостоверен, см. ниже). На другой машине этот блок
корректно определит, что применять ryzenadj/nvidia-powerd вообще нужно, но
конкретные цифры нужно подбирать заново по процедуре из открытого вопроса.


**Открытый вопрос — перенос конфига на другое железо (слабее Ryzen + старее Nvidia, тот же стек ПО):**
Не подтверждено, нужна отдельная эмпирическая проверка на месте — не переносить
числа вслепую. Конкретно:
- **`ryzenadj`-числа не универсальны.** STAPM/fast/slow — это доля от
  официального cTDP конкретного чипа (у 7845HX это 45-75W по спеке AMD), у
  более слабого Ryzen (даже другого HX/H-класса) официальный диапазон
  cTDP почти наверняка ниже — подстановка тех же 54000/65000 может как
  оказаться избыточной (не даст эффекта, чип и так способен на меньшее), так и
  агрессивной относительно его штатного охлаждения. `tctl-temp=95` тоже
  завязан на Tjmax конкретного кремния — для другого чипа может быть другое
  значение по спеке. Нужно повторить процедуру подбора (шаги: старт с
  official cTDP-диапазона → `stress-ng` + мониторинг `sensors`/`ryzenadj -i`
  5-10 минут → подъём с шагом ~5W) заново на месте, не копировать.
- **`ryzenadj` как инструмент — должен работать** на любом мобильном Zen2-Zen4
  Ryzen (это не привязано к конкретной модели, реверс-инжиниринг SMU
  достаточно общий для семейства), но конкретно сообщение про
  `ryzen_smu`-модуль/fallback на `/dev/mem` может отличаться в зависимости от
  того, что доступно на конкретном ядре/сборке.
- **`nvidia-powerd`/Dynamic Boost зависит от поколения GPU и, отдельно, от
  реализации ACPI/SBIOS конкретного производителя ноутбука**, а не только от
  того, что это в принципе Nvidia. Более старая карта (например, Turing/Pascal
  поколения, а не Ampere/Ada) может вообще не поддерживать Dynamic Boost —
  `nvidia-powerd` в таком случае либо не даст эффекта, либо честно откажет.
  Даже если поколение подходящее — как показал этот кейс, конкретный вендор
  прошивки (SBIOS) может частично не поддерживать протокол (см. сообщение
  "presumably SBIOS" выше) — на другом ноутбуке ошибка может быть другой, и
  не факт безобидной. Проверка — та же процедура: `systemctl status
  nvidia-powerd` → `journalctl -u nvidia-powerd` → нагрузочный тест с
  `nvidia-smi -q -d POWER`/`btop`, сравнить реальную ватность до/после.
- Если это другая машина — этот блок в любом случае должен остаться
  conditional (chassis==laptop + AMD+Nvidia детект), не core: на десктопе или
  на Intel/AMD-GPU системе он не нужен и не должен применяться.

### Хранилище секретов (gnome-keyring + PAM + gcr-ssh-agent) — ✅ подтверждено 2026-08, агент заменён 2026-10
```bash
sudo pacman -S --needed gnome-keyring libsecret gcr-4

grep -q pam_gnome_keyring /etc/pam.d/sddm || sudo bash -c "cat >> /etc/pam.d/sddm << 'EOF'
auth       optional     pam_gnome_keyring.so
session    optional     pam_gnome_keyring.so auto_start
EOF"
grep -q pam_gnome_keyring /etc/pam.d/login || sudo bash -c "cat >> /etc/pam.d/login << 'EOF'
auth       optional     pam_gnome_keyring.so
session    optional     pam_gnome_keyring.so auto_start
EOF"

# SSH-агент — gcr-ssh-agent из gcr-4 вместо самописного юнита (2026-10).
# Пароль ключа спрашивается один раз, с галочкой "сохранить" он ложится в
# связку ключей gnome-keyring — она хранится только локально на машине и
# открывается паролем входа через PAM выше. Дальше ключ разблокируется сам.
systemctl --user enable --now gcr-ssh-agent.socket
# SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/gcr/ssh — в dot_config/fish/config.fish
```
⚠️ Если на какой-то машине будет автологин без пароля входа, PAM не получит
пароль и связка ключей не откроется сама — см. todo, раздел про экран входа.

### Удалённый доступ и синхронизация — ✅ подтверждено 2026-08 (KDE Connect и LocalSend убраны из проекта 2026-10)
```bash
paru -S --needed rustdesk-bin
sudo pacman -S --needed syncthing
systemctl --user enable --now syncthing
mkdir -p ~/Projects/syncthing
# Папка создаётся локально, без единого добавленного устройства/пира —
# спаривание с конкретными устройствами делается вручную после установки
# (Device ID генерируется заново на каждой машине, заранее неизвестен,
# доверие двустороннее — не автоматизируется)
```

### Контейнеры — только Podman — ✅ подтверждено 2026-08 (Docker убран); квота — перенесена сюда 2026-09
```bash
sudo pacman -S --needed podman podman-compose
sudo pacman -S --needed slirp4netns aardvark-dns
sudo chmod u+s /usr/bin/newuidmap /usr/bin/newgidmap

# Лимит на размер данных Podman — раньше жил в разделе "Разметка диска" вместе
# с archinstall-этапом (до первой загрузки, без гарантированного $HOME
# реального пользователя — тот же класс бага, что нашли в pacman-хуке, где
# "~" резолвился в /root). @containers монтируется через fstab, то есть путь
# уже существует к моменту ЛЮБОГО run_once — команду можно и нужно выполнять
# здесь, в обычном пользовательском контексте, где "~" резолвится верно
# (audit-находка №3):
sudo btrfs quota enable /
sudo btrfs qgroup limit 100G ~/.local/share/containers/storage

# lazydocker подключается по Docker-совместимому API/сокету, а не по имени
# бинарника "podman" — без этого шага он просто не увидит контейнеры молча.
# Podman отдаёт такой сокет сам, нужно только включить (DOCKER_HOST уже
# прописан в fish-блоке 4.1):
systemctl --user enable --now podman.socket
```

### Файловый менеджер и просмотр медиа — ✅ подтверждено 2026-08
```bash
sudo pacman -S --needed thunar thunar-volman thunar-archive-plugin tumbler gvfs
sudo pacman -S --needed imv mpv
```
(PDF раньше сюда не входил осознанно, но заменено решением на Okular — см. package-tier список)

### MIME-ассоциации по умолчанию — 2026-09, не привязано к Niri (общий XDG-механизм)
```bash
mkdir -p ~/.config
tee ~/.config/mimeapps.list << 'EOF'
[Default Applications]
text/plain=codium.desktop
text/markdown=codium.desktop
application/pdf=org.kde.okular.desktop
image/png=imv.desktop
image/jpeg=imv.desktop
image/gif=imv.desktop
image/webp=imv.desktop
video/mp4=mpv.desktop
video/x-matroska=mpv.desktop
video/webm=mpv.desktop
EOF
```
Имена `.desktop`-файлов стандартные для этих пакетов, но стоит свериться
после установки (`xdg-mime query filetype <файл>` покажет тип, содержимое
`/usr/share/applications/` — точные id, если что-то не подхватится).

### Recoll — ✅ подтверждено 2026-08 (индексируется только ~/Projects)
```bash
sudo pacman -S --needed recoll
mkdir -p ~/.recoll
tee ~/.recoll/recoll.conf << 'EOF'
topdirs = ~/Projects
EOF
recollindex
mkdir -p ~/.config/systemd/user
tee ~/.config/systemd/user/recoll-index.service << 'EOF'
[Unit]
Description=Recoll reindex

[Service]
ExecStart=/usr/bin/recollindex
EOF
tee ~/.config/systemd/user/recoll-index.timer << 'EOF'
[Unit]
Description=Daily recoll reindex

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now recoll-index.timer
```

### Мониторинг — ✅ подтверждено 2026-08 (SMART-алерты зависят от ещё не разобранного 7.3c); nvtop вынесен в GPU-условный блок — 2026-09
```bash
sudo pacman -S --needed btop smartmontools ncdu
paru -S --needed bandwhich vnstat
sudo systemctl enable --now vnstat

source "$HOME/.local/state/chezmoi-hw-facts.env"
# nvtop сам умеет несколько бэкендов (Nvidia/AMD/Intel), но раньше план
# классифицировал его как "conditional (только при Nvidia+гибрид)" в таблице
# пакетов, а код ставил безусловно всем — рассинхрон. Возвращено к решению
# из таблицы: ставим только если реально есть Nvidia.
if $HAS_NVIDIA; then
    paru -S --needed nvtop
fi
```
`ncdu` — интерактивный анализ занятого места на диске. `bandwhich` — трафик по процессам и удалённым хостам одновременно, реалтайм. `vnstat` — фоновый демон, копит историю трафика по часам/дням/месяцам, переживает перезагрузки.

### Буфер обмена и скриншоты — ✅ подтверждено 2026-08 (cliphist/udiskie автозапуск живёт в niri config.kdl — не забыть при написании)
```bash
sudo pacman -S --needed wl-clipboard grim slurp swappy
paru -S --needed cliphist udiskie
```

### fwupd — ✅ подтверждено 2026-08
```bash
sudo pacman -S --needed fwupd
```

### Reflector (автообновление зеркал pacman) — ✅ подтверждено 2026-08; универсальность + запуск на каждой загрузке — 2026-09, закрывает audit-находки №11 и №19
```bash
sudo pacman -S --needed reflector
sudo tee /etc/xdg/reflector/reflector.conf << 'EOF'
--protocol https
--latest 10
--sort rate
--save /etc/pacman.d/mirrorlist
EOF

sudo mkdir -p /etc/systemd/system/reflector.timer.d
sudo tee /etc/systemd/system/reflector.timer.d/override.conf << 'EOF'
[Timer]
Persistent=true
EOF

# reflector.service (не только .timer) — запускать и на каждой загрузке,
# не только по еженедельному расписанию. Пакетный юнит уже требует
# network-online.target, но override гарантирует это явно, а не полагается
# на дефолт пакета молча совпасть с ожиданием:
sudo mkdir -p /etc/systemd/system/reflector.service.d
sudo tee /etc/systemd/system/reflector.service.d/override.conf << 'EOF'
[Unit]
After=network-online.target
Wants=network-online.target
EOF

sudo systemctl enable --now reflector.timer
sudo systemctl enable reflector.service
```
Убран хардкод `--country Russia,Germany,Netherlands` — без явного списка стран
`reflector` просто ранжирует все зеркала по скорости отклика (`--sort rate`),
универсально для любой страны, ценой чуть более долгого перебора при первом
запуске (обычно 10 секунд — пара минут, зависит от отзывчивости сети). Не
блокирует логин — `reflector.service` не входит в цепочку graphical-session,
просто досчитывает список зеркал в фоне после поднятия сети. Без сети юнит
с `Wants=network-online.target` просто не запустится, а не зависнет
таймаутом.

### plocate + пост-установочные проверки — ✅ подтверждено 2026-08
```bash
sudo pacman -S --needed plocate

vainfo
resolvectl status | grep "DNS over TLS"
sudo systemctl status systemd-oomd
gnome-keyring-daemon --version
secret-tool search --all 2>&1 | head -5
systemctl --user list-units --state=failed
sudo updatedb
```
Диагностический чеклист, не конфигурация — прогнать после установки, чтобы
убедиться, что VA-API/DoT/oomd/keyring/юзер-сервисы реально работают.

### snapper — 5 последних операций + 5 последних "опасных" обновлений — изменено 2026-10
```bash
sudo pacman -S --needed snapper snap-pac
# root-конфиг archinstall создаёт сам (snapshot type: Snapper) — создаём,
# только если его нет (раньше была ручная проверка глазами):
sudo snapper list-configs | grep -q '^root ' || sudo snapper -c root create-config /

# /home — конфиг ВРЕМЕННО убран (2026-10) до решения: snap-pac снапшотит
# только root (pacman /home не трогает), так что "пара до/после" для /home
# даёт ноль снапшотов, а дефолтный конфиг включал почасовой таймлайн —
# противоречие решению. См. todo.

# /etc/snapper/configs/root — только пара до/после апдейта, без таймлайна:
sudo sed -i 's/^TIMELINE_CREATE=.*/TIMELINE_CREATE="no"/' /etc/snapper/configs/root
sudo sed -i 's/^NUMBER_LIMIT=.*/NUMBER_LIMIT="10"/' /etc/snapper/configs/root
sudo sed -i 's/^NUMBER_LIMIT_IMPORTANT=.*/NUMBER_LIMIT_IMPORTANT="10"/' /etc/snapper/configs/root
# Страховка по месту: если свободно меньше 20% — старые снапшоты удаляются
# раньше лимита (чтобы снапшоты никогда не забили диск):
sudo sed -i 's/^FREE_LIMIT=.*/FREE_LIMIT="0.2"/' /etc/snapper/configs/root

# "Важные" снапшоты — только транзакции, затрагивающие пакеты, после которых
# система реально может не загрузиться. Они хранятся отдельным лимитом и не
# вытесняются обычными установками софта.
# ⚠️ Формат snap-pac.ini сверить с man snap-pac после установки.
sudo tee /etc/snap-pac.ini << 'EOF'
[root]
important_packages = ["linux-cachyos", "linux-lts", "linux-cachyos-nvidia-open", "nvidia-open-lts", "nvidia-utils", "mesa", "systemd", "glibc", "limine", "mkinitcpio"]
EOF
# NUMBER_LIMIT применяет именно этот таймер — сам snap-pac старое не чистит:
sudo systemctl enable --now snapper-cleanup.timer
```
`snap-pac` создаёт пару до/после на **каждую** pacman-транзакцию — не только
на `-Syu`, но и на каждую установку или удаление пакета. Поэтому один общий
лимит "9 пар" съедался бы за день активной установки софта, и точка до
последнего большого обновления исчезала бы. Отсюда два лимита:
- обычные (10 = ~5 пар) — откат последних установок/удалений;
- важные (10 = ~5 пар) — откат последних обновлений ядра, драйверов и базы,
  которые не вытесняются обычной установкой софта.

Вес: снапшот при создании почти ничего не весит и дальше удерживает только
заменённые файлы. Типичная пара — 0.5–3 ГБ, всё вместе — порядка 10–25 ГБ в
худшем случае; `FREE_LIMIT` не даёт им забить диск.

### Процедура безопасного обновления — ✅ подтверждено 2026-08
```bash
# Перед обновлением — проверить Arch News: https://archlinux.org/news/
# snap-pac уже создал снапшот "до" автоматически:
paru -Syu

# Если что-то сломалось — исправлено 2026-10: `snapper rollback` при раскладке
# archinstall (явный subvol=@ в fstab/cmdline) по сути не работает: он меняет
# default-subvolume, а явный subvol=@ его перебивает. Путь под Limine:
#   1. в меню Limine выбрать снапшот "до" обновления и загрузиться
#   2. убедиться, что всё работает
#   3. sudo limine-snapper-restore   # ⚠️ имя/поведение сверить после установки
#   4. reboot

# Заморозить Nvidia при нестабильной версии — /etc/pacman.conf:
# IgnorePkg = linux-cachyos-nvidia-open nvidia-open-lts nvidia-utils lib32-nvidia-utils
```

### Ежемесячное обслуживание — ✅ подтверждено 2026-08 (убрана мёртвая строка Lazy/Mason — Neovim без плагинов)
```bash
paru -Qtdq | paru -Rns -   # если вывод не пустой
for disk in /dev/sd? /dev/nvme?n1; do
    [ -e "$disk" ] || continue
    sudo smartctl -a "$disk"
done
sudo snapper list
journalctl -p err --since "1 month ago"
chezmoi git pull && chezmoi apply
chezmoi git add -A && chezmoi git commit -m "Monthly sync $(date +%Y%m%d)" && chezmoi git push
rustup update
mise self-update && mise upgrade
sudo paccache -rk2
fwupdmgr refresh
fwupdmgr get-updates
# fwupdmgr update — применять руками после просмотра, не автоматически
```

### Алерты — место на диске и SMART — ✅ подтверждено 2026-08
```bash
mkdir -p ~/.local/bin
tee ~/.local/bin/system-health-check.sh << 'EOF'
#!/bin/bash
df -h --output=pcent,target -x tmpfs -x devtmpfs | tail -n +2 | while read -r pcent target; do
    pct=${pcent%\%}
    if [ "$pct" -ge 85 ]; then
        notify-send -u critical "Диск заполнен" "$target: $pcent использовано"
    fi
done

for disk in /dev/sd? /dev/nvme?n1; do
    [ -e "$disk" ] || continue
    health=$(sudo smartctl -H "$disk" 2>/dev/null | grep -i "overall-health\|SMART Health Status")
    if [ -n "$health" ] && ! echo "$health" | grep -qi "PASSED\|OK"; then
        notify-send -u critical "Проблема с диском $disk" "$health"
    fi
done
EOF
chmod +x ~/.local/bin/system-health-check.sh

echo "$USER ALL=(root) NOPASSWD: /usr/bin/smartctl -H /dev/sd?, /usr/bin/smartctl -H /dev/nvme?n1" | \
    sudo tee /etc/sudoers.d/smartctl-health
sudo chmod 440 /etc/sudoers.d/smartctl-health

mkdir -p ~/.config/systemd/user
tee ~/.config/systemd/user/system-health-check.service << 'EOF'
[Unit]
Description=Disk space and SMART health check

[Service]
Type=oneshot
ExecStart=%h/.local/bin/system-health-check.sh
EOF
tee ~/.config/systemd/user/system-health-check.timer << 'EOF'
[Unit]
Description=Daily disk space and SMART health check

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now system-health-check.timer
```

### VS Code — ✅ подтверждено 2026-08, заменено на VSCodium (community-форк без телеметрии; при проблемах с вашими личными расширениями на первом же патче — откат на visual-studio-code-bin)
```bash
paru -S --needed vscodium-bin
```
Wayland-запуск (иначе рендерится через XWayland с потерей плавности) —
алиас добавляется в блок fish (4.1):
```fish
alias code='codium --ozone-platform=wayland --enable-features=WaylandWindowDecorations'
```
window-rule для floating-режима — в README (напоминание для niri config.kdl).
Список расширений (rust-analyzer/ruff/gitlens/catppuccin-vsc и т.д.) убран
отсюда — не был реально подтверждён, часть расширений синкается через
аккаунт пользователя. Описания — в README, решать отдельно.

### vesktop — launch-обёртка с VAAPI-флагами — ✅ подтверждено 2026-08
```bash
mkdir -p ~/.local/share/applications
tee ~/.local/share/applications/vesktop-vaapi.desktop << 'EOF'
[Desktop Entry]
Name=Vesktop
Exec=vesktop --ozone-platform-hint=auto --enable-features=AcceleratedVideoDecodeLinuxZeroCopyGL,AcceleratedVideoDecodeLinuxGL,VaapiIgnoreDriverChecks,VaapiOnNvidiaGPUs,AcceleratedVideoEncoder,WebRTCPipeWireCapturer
Type=Application
Icon=vesktop
Categories=Network;
EOF
```
Проверка после установки — `vesktop://gpu` внутри приложения (аналог
`chrome://gpu`), убедиться, что видеодекодер/энкодер реально в статусе
"Hardware accelerated", а не просто что флаги приняты без ошибок.

**Известная проблема — вторично, чинить после установки, не блокирует core.**
Screen-share в Discord/Vesktop падает/обрывается на Niri, особенно на
Nvidia — не баг конкретно нашего плана, задокументированная проблема самого
Niri+PipeWire. Порядок попыток при возврате к этому:
1. Проверить/поставить `xdg-desktop-portal-gnome`, явно прописать
   `org.freedesktop.impl.portal.ScreenCast=gnome` в
   `/usr/share/xdg-desktop-portal/niri-portals.conf` — самая частая причина
   любого скриншеринга на Niri в принципе
2. NVIDIA-специфичный глюк синхронизации PipeWire — debug-флаг в
   `config.kdl`: `debug { wait-for-frame-completion-in-pipewire; }`
3. Отключить `2026-03-linux-vulkan-capture` в Vesktop (Settings → Experiments)
   — известный баг именно нового способа захвата в самом Discord-клиенте
4. "Dynamic Cast Target" (окно меняется по фокусу) требует явных биндов в
   `config.kdl` (`set-dynamic-cast-window`/`set-dynamic-cast-monitor`/
   `clear-dynamic-cast-target`) — без них поток стартует пустым, это не баг

### Игры — основной стек — ✅ подтверждено 2026-08 (gamescope исключён по решению)
```bash
sudo pacman -S --needed steam gamemode lib32-gamemode
sudo pacman -S --needed mangohud lib32-mangohud
sudo pacman -S --needed lib32-mesa lib32-vulkan-icd-loader   # lib32-nvidia-utils — только в Nvidia-ветке раздела "Игры — gamemode/scx, VAAPI"
sudo pacman -S --needed flatpak
# proton-cachyos-slr — AUR, готовые бинарники с GitHub Releases,
# без компиляции и без стороннего pacman (в отличие от -native):
paru -S --needed proton-cachyos-slr
paru -S --needed flatseal bazaar
gamemoded -t   # проверка, что демон доступен
```
Уведомления Steam (список друзей "зашёл в игру" и т.д.) — не обычные
системные toast'ы, а собственное XWayland-окно Steam с заголовком
`notificationtoasts_<N>_desktop`, которое всплывает поверх чего угодно
именно поэтому. На Hyprland это окно принципиально нельзя подвинуть
(подтверждено самим автором Hyprland), а вот на Niri — можно и это уже
официально задокументировано в вики самого проекта:
```
# Позиция ИЗМЕНЕНА 2026-10 (было bottom-right) — решено сбоку экрана:
# window-rule {
#     match app-id="steam" title=r#"^notificationtoasts_\d+_desktop$"#
#     default-floating-position x=16 y=0 relative-to="right"
# }
# Готовый блок для config.kdl — см. раздел "Niri — window/layer-rules" ниже.
```

### Разметка диска — subvolume-схема — ✅ подтверждено 2026-08
```
Disk configuration → best-effort default → выбор диска (динамически,
не хардкод nvme0n1) → btrfs → subvolumes: yes → compression: zstd →
snapshot type: Snapper

LUKS — предлагается на всех машинах, десктопе тоже (изменено 2026-10:
накладные расходы на NVMe с AES-NI — единицы процентов). На этом этапе диска
ещё нет, поэтому это предложение, а не рантайм-детект существующего раздела (тот появляется только
после установки — см. `HAS_LUKS` в "Детект железа" и таблицу решений в п.1).
Всегда с явным подтверждением пользователя, не автоматически

Subvolume-схема (дефолт archinstall + одно дополнение):
  @            → /
  @home        → /home
  @log         → /var/log              (вне снапшотов)
  @pkg         → /var/cache/pacman/pkg (вне снапшотов)
  @.snapshots  → /.snapshots
  @containers  → ~/.local/share/containers/storage (вне снапшотов) —
                 данные Podman (rootless); Docker убран, второй путь
                 монтирования больше не нужен
  /swap        → вложенный subvolume под гибернацию (создаётся отдельно в
                 разделе "Безопасность/гибернация" через `btrfs subvolume
                 create /swap`, не archinstall'ом) — автоматически вне
                 снапшотов @ как вложенный subvolume, отдельно в таблице не
                 фигурировал раньше (audit-находка №17), хотя код его
                 создавал с самого начала

Все монтируются с: noatime, compress=zstd, discard=async
```
`discard=async` выбран вместо `fstrim.timer` — постоянный фоновый TRIM для
NVMe без ожидания недельного цикла, современная рекомендация ArchWiki.

```bash
# @tmp — проверка в рантайме, отдельно на каждой машине:
# Исправлено 2026-10: (1) $ROOT_UUID раньше не задавался; (2) `btrfs subvolume
# create /@tmp` на смонтированном корне создаёт ВЛОЖЕННЫЙ @/@tmp, а fstab
# ссылается на subvol=@tmp верхнего уровня — монтирование бы его не нашло;
# (3) у нового сабвольюма права 755, а /tmp нужны 1777.
# На Arch /tmp по умолчанию и так tmpfs (tmp.mount) — ветка else редкая.
if findmnt -no FSTYPE /tmp 2>/dev/null | grep -qx tmpfs; then
    echo "/tmp уже tmpfs (в RAM) — отдельный subvolume не нужен"
else
    ROOT_SRC=$(findmnt -nvo SOURCE /)
    ROOT_UUID=$(findmnt -no UUID /)
    TOP=$(mktemp -d)
    sudo mount -o subvolid=5 "$ROOT_SRC" "$TOP"
    sudo btrfs subvolume create "$TOP/@tmp"
    sudo chmod 1777 "$TOP/@tmp"
    sudo umount "$TOP"; rmdir "$TOP"
    echo "UUID=${ROOT_UUID} /tmp btrfs subvol=@tmp,noatime,compress=zstd,discard=async 0 0" | sudo tee -a /etc/fstab
fi
```

Квота на `@containers` (100GB) — перенесена в раздел "Контейнеры — только
Podman" (см. ниже): там путь гарантированно уже смонтирован через fstab, и
скрипт выполняется в обычном пользовательском контексте, а не на этапе
archinstall — исправлена audit-находка №3 (риск резолва `~` в `/root`).

### Организация файлов — ✅ подтверждено 2026-08
```bash
sudo pacman -S --needed xdg-user-dirs rmlint
xdg-user-dirs-update
mkdir -p ~/Projects
echo 'XDG_PROJECTS_DIR="$HOME/Projects"' >> ~/.config/user-dirs.dirs

mkdir -p ~/.local/bin
tee ~/.local/bin/cleanup-downloads.sh << 'EOF'
#!/bin/bash
for item in ~/Downloads/*; do
    [ -e "$item" ] || continue
    if [ -f "$item" ]; then
        find "$item" -maxdepth 0 -mtime +30 -exec trash {} \;
    elif [ -d "$item" ]; then
        if [ -z "$(find "$item" -type f -mtime -30 -print -quit)" ]; then
            trash "$item"
        fi
    fi
done
EOF
chmod +x ~/.local/bin/cleanup-downloads.sh

mkdir -p ~/.config/systemd/user
tee ~/.config/systemd/user/cleanup-downloads.service << 'EOF'
[Unit]
Description=Move old downloads to trash

[Service]
Type=oneshot
ExecStart=%h/.local/bin/cleanup-downloads.sh
EOF
tee ~/.config/systemd/user/cleanup-downloads.timer << 'EOF'
[Unit]
Description=Weekly downloads cleanup

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF
systemctl --user daemon-reload
systemctl --user enable --now cleanup-downloads.timer
```
`rmlint` — поиск дубликатов файлов/папок, только ручной запуск при
необходимости (генерирует скрипт на проверку, ничего не удаляет сам).

### Дополнение софта: OCR, GUI-разметка диска, Java, Node.js — ✅ подтверждено 2026-08
```bash
paru -S --needed normcap
sudo pacman -S --needed tesseract tesseract-data-eng tesseract-data-rus

sudo pacman -S --needed gparted   # GUI для ручной разметки/изменения разделов

paru -S --needed wvkbd   # виртуальная клавиатура на аварийный случай (нет доступа к физической)
# Бинд в config.kdl (напоминание в README):
# SUPER+Alt+K { spawn "wvkbd-mobintl"; }

# Node LTS — через dot_config/mise/config.toml + `mise install` (блок mise/uv/rustup)
```

### Синхронизация списка пакетов между устройствами — ✅ подтверждено 2026-08
```bash
sudo mkdir -p /etc/pacman.d/hooks
sudo tee /etc/pacman.d/hooks/99-sync-packages.hook << 'EOF'
[Trigger]
Operation = Install
Operation = Remove
Type = Package
Target = *

[Action]
Description = Обновление списка пакетов для синхронизации...
When = PostTransaction
Exec = /usr/local/bin/dump-packages.sh
EOF

# Хук работает от root — раньше из-за этого папка (если её ещё не было) и
# файл списка создавались с владельцем root. Исправлено 2026-10: владелец
# выставляется явно. $HOME/$USER раскрываются в момент генерации скрипта
# (heredoc без кавычек) — намеренно. `uname -n` вместо `hostname`: бинарник
# hostname (inetutils) в базовой установке Arch отсутствует.
sudo tee /usr/local/bin/dump-packages.sh << EOF
#!/bin/bash
OUT_DIR="$HOME/Projects/syncthing"
OUT_FILE="\$OUT_DIR/packages-\$(uname -n).txt"
install -d -o "$USER" -g "$(id -gn)" "\$OUT_DIR"
pacman -Qqe > "\$OUT_FILE"
chown "$USER:$(id -gn)" "\$OUT_FILE"
EOF
sudo chmod +x /usr/local/bin/dump-packages.sh

mkdir -p ~/.local/bin
tee ~/.local/bin/check-missing-packages.sh << 'EOF'
#!/bin/bash
# Сверяет список пакетов текущей машины со списками остальных, найденных в
# синтинг-папке. Два направления, оба — только уведомление, ничего не ставит
# и не удаляет само:
#   - "не хватает" — стоит на другой машине, нет здесь → возможно, стоит
#     поставить и тут
#   - "лишнее" — стоит здесь, но нет на другой машине → либо осознанно
#     машинно-специфичный софт, либо снесли там и забыли снести тут —
#     решает сам пользователь, скрипт не угадывает намерение
for f in ~/Projects/syncthing/packages-*.txt; do
    [ "$f" = ~/Projects/syncthing/packages-"$(uname -n)".txt ] && continue
    OTHER_HOST=$(basename "$f" .txt | sed 's/^packages-//')

    comm -23 <(sort "$f") <(pacman -Qqe | sort) > /tmp/missing-packages.txt
    if [ -s /tmp/missing-packages.txt ]; then
        notify-send "Пакеты есть на $OTHER_HOST, нет здесь" "$(wc -l < /tmp/missing-packages.txt) шт. — /tmp/missing-packages.txt"
    fi

    comm -13 <(sort "$f") <(pacman -Qqe | sort) > /tmp/extra-packages.txt
    if [ -s /tmp/extra-packages.txt ]; then
        notify-send "Пакеты есть здесь, нет на $OTHER_HOST" "$(wc -l < /tmp/extra-packages.txt) шт. — /tmp/extra-packages.txt (возможно, снесено там)"
    fi
done
EOF
chmod +x ~/.local/bin/check-missing-packages.sh

mkdir -p ~/.config/systemd/user
tee ~/.config/systemd/user/check-missing-packages.timer << 'EOF'
[Unit]
Description=Weekly check for packages present on other machines

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF
tee ~/.config/systemd/user/check-missing-packages.service << 'EOF'
[Unit]
Description=Check for packages present on other machines

[Service]
Type=oneshot
ExecStart=%h/.local/bin/check-missing-packages.sh
EOF
systemctl --user daemon-reload
systemctl --user enable --now check-missing-packages.timer
```
Только уведомление, не автоустановка — та же логика подтверждения, что и
у LUKS/второго диска/новых USB-устройств. Установка вручную:
`paru -S --needed $(cat /tmp/missing-packages.txt)`.

### Второй диск (ПК) — ✅ подтверждено 2026-08 (отдельный btrfs-том, свой snapper)
```bash
# Исправлено 2026-10: $TARGET_DISK раньше нигде не задавался → grep -v "^$"
# ничего не отфильтровывал, и СИСТЕМНЫЙ диск попадал в список "вторых" с
# предложением форматирования. Плюс zram0 тоже имеет TYPE=disk — явно
# исключаем zram/loop и съёмные (RM=1, флешки).
source "$HOME/.local/state/chezmoi-hw-facts.env"   # ROOT_DISK
if [ -z "$ROOT_DISK" ]; then
    echo "ВНИМАНИЕ: системный диск не определён — шаг второго диска пропущен, проверь вручную." >&2
    exit 0
fi
OTHER_DISKS=$(lsblk -dno NAME,TYPE,RM | awk -v root="$ROOT_DISK" '$2=="disk" && $3=="0" && $1!=root && $1 !~ /^(zram|loop)/ {print $1}')

if [ -z "$OTHER_DISKS" ]; then
    echo "Второй диск не найден — пропускаем этот шаг"
    exit 0
fi

for disk in $OTHER_DISKS; do
    EXISTING_FS=$(lsblk -no FSTYPE "/dev/$disk" | grep -v '^$')

    if [ -n "$EXISTING_FS" ]; then
        echo "Обнаружен второй диск /dev/$disk ($(lsblk -dno SIZE /dev/$disk)) — НА НЁМ УЖЕ ЕСТЬ ДАННЫЕ ($EXISTING_FS)"
        read -p "Форматирование УДАЛИТ все данные безвозвратно. Введите 'подтверждаю' для форматирования, или Enter чтобы оставить как есть: " ANSWER
        [ "$ANSWER" = "подтверждаю" ] || { echo "Диск /dev/$disk не тронут"; continue; }
    else
        echo "Обнаружен второй диск /dev/$disk ($(lsblk -dno SIZE /dev/$disk)) — выглядит пустым"
        read -p "Отформатировать под Storage или оставить как есть? [форматировать/оставить] (оставить): " ANSWER
        ANSWER=${ANSWER:-оставить}
        [ "$ANSWER" = "форматировать" ] || { echo "Диск /dev/$disk не тронут"; continue; }
    fi

    # -f обязателен, если на диске уже есть ФС (пользователь это подтвердил выше)
    sudo mkfs.btrfs -f -L storage "/dev/$disk"
    STORAGE_UUID=$(blkid -s UUID -o value "/dev/$disk")

    sudo mkdir -p /mnt/storage
    echo "UUID=${STORAGE_UUID} /mnt/storage btrfs defaults,noatime,compress=zstd,discard=async,nofail 0 0" | sudo tee -a /etc/fstab
    sudo mount /mnt/storage

    # Собственный snapper-конфиг, та же политика, что и у root:
    sudo snapper -c storage create-config /mnt/storage
    sudo sed -i 's/^TIMELINE_CREATE=.*/TIMELINE_CREATE="no"/' /etc/snapper/configs/storage
    sudo sed -i 's/^NUMBER_LIMIT=.*/NUMBER_LIMIT="2"/' /etc/snapper/configs/storage
    sudo sed -i 's/^NUMBER_LIMIT_IMPORTANT=.*/NUMBER_LIMIT_IMPORTANT="2"/' /etc/snapper/configs/storage
done
```
`LABEL=storage` — отображается как "storage" в `lsblk`/файловых менеджерах.
UUID в fstab — надёжнее label для самого монтирования. Snapper-конфиг
`storage` независим от `root` — откат одного не трогает другой. На ноуте
(один диск) шаг просто пропускается автоматически.

### EasyEffects — шумодав на микрофоне + общая EQ-кривая на выходе — исправлено 2026-10
```bash
paru -S --needed easyeffects
```
Раньше RNNoise стоял на **выходе** — это голосовая модель шумоподавления, на
музыке и играх она бы "гейтила" звук. Теперь разделено:
- **Вход (микрофон):** RNNoise — для голосовых (Vesktop, звонки)
- **Выход (наушники):** только EQ — мягкий Harman-подобный профиль, не под
  конкретную модель: Low-Shelf 60 Hz +2.5 dB, Peak 200 Hz −1 dB, Peak 3 kHz
  +2 dB, High-Shelf 10 kHz +1.5 dB

Пресеты **не пишутся руками**: самописный JSON не совпадал с реальным
форматом (там ключи вида `rnnoise#0`, `equalizer#0` и `plugins_order`) и
молча не загрузился бы. Процедура: один раз собрать оба пресета в GUI →
экспортировать → положить в chezmoi (`.../input/mic.json`,
`.../output/eq.json`) → в EasyEffects включить автозагрузку пресетов для
устройств. ⚠️ В новых версиях EasyEffects пресеты могли переехать из
`~/.config/easyeffects/` в `~/.local/share/easyeffects/` — путь сверить после
установки.

### btrfs scrub — ✅ подтверждено 2026-08 (balance сознательно НЕ по расписанию, см. README)
```bash
sudo systemctl enable --now btrfs-scrub@-.timer
```
Только проверка целостности (read-only, находит битые данные), ежемесячно
по штатному юниту из `btrfs-progs`. Balance — вручную по симптому, не по
таймеру (устаревшая практика для SSD/NVMe при обычной нагрузке).

### Thunar-закладки — ✅ подтверждено 2026-08
```bash
mkdir -p ~/.config/gtk-3.0
tee ~/.config/gtk-3.0/bookmarks << EOF
file://$HOME/Projects Projects
EOF
if mountpoint -q /mnt/storage 2>/dev/null; then
    echo "file:///mnt/storage Storage" >> ~/.config/gtk-3.0/bookmarks
fi
```
`/mnt/storage` — только если реально смонтирован (условно, ноут без
второго диска пропускает строку автоматически).

### Дополнение софта — ✅ подтверждено 2026-08
```bash
paru -S --needed sshm-tui         # TUI SSH-менеджер (port forwarding, ProxyJump), пишет прямо в ~/.ssh/config
paru -S --needed atuin             # умная история команд, БЕЗ синка (atuin login не выполняется)
# --- core ---
sudo pacman -S --needed gcc gdb cmake make  # C++ (clang уже есть — компилирует C++ тоже)
paru -S --needed tealdeer                # tldr на Rust
paru -S --needed lazydocker
paru -S --needed xh
sudo pacman -S --needed procs
sudo pacman -S --needed watchexec             # официальный пакет; было `pacman -S watchexec-bin` — это AUR-имя, pacman бы его не нашёл
paru -S --needed waypaper
sudo pacman -S --needed sd
sudo pacman -S --needed glow
paru -S --needed bruno-bin               # git-нативный API-клиент, без аккаунта

# --- optional (выбор через .chezmoidata.yaml; перенесено из core 2026-10) ---
# paru -S torbrowser-launcher   # официальная обёртка, песочница
# pacman -S postgresql mariadb  # MariaDB = MySQL-совместимая, настоящего Oracle MySQL нет в репах Arch
# paru -S dbeaver               # GUI под Postgres — закрывает роль pgAdmin
# pacman -S obs-studio          # стоковый, без доп. настройки
# paru -S obsidian
# paru -S anki
# pacman -S wireshark-qt        # + sudo usermod -aG wireshark $USER, иначе захват только от root
# pacman -S kicad
# pacman -S --asdeps kicad-library kicad-library-3d
# Exiled Exchange 2 — прайсчек для PoE2, читает только буфер обмена (не память
# процесса, низкий риск бана), стабильная нативная Linux-сборка (AppImage):
# скачивается вручную с https://kvan7.github.io/Exiled-Exchange-2/download
# (не через pacman/AUR — официально только с этого сайта или GitHub Releases)
#
# Niri не поддерживает XDG GlobalShortcuts-портал (только открытый PR) —
# глобальные хоткеи/оверлей/буфер обмена решаются запуском через уже
# установленный xwayland-satellite, не через Niri-бинды:
mkdir -p ~/.local/bin
tee ~/.local/bin/exiled-exchange-2.sh << 'EOF'
#!/bin/bash
env XDG_SESSION_TYPE=x11 ~/Applications/Exiled-Exchange-2.AppImage --ozone-platform=x11
EOF
chmod +x ~/.local/bin/exiled-exchange-2.sh
```
`mise` — только
под языки помимо Python/Rust (те уже закрыты uv/rustup). Расширение
`llvm-vs-code-extensions.vscode-clangd` под C++ — в README (список
расширений VSCodium).

### Noctalia — финальный конфиг бара/темы/лаунчера — ✅ решено 2026-10
Визуальный ориентир — тема Vantablack из Omarchy 4.0.4 (снята с реального
ноута пользователя: `pacman -Q omarchy` → `omarchy 4.0.4-1`, `omarchy-theme-current`
→ `Vantablack`). Монохромная палитра, без цветных акцентов, `cornerRadius: 0`
в самом Omarchy — стиль переносится в Noctalia как есть.

```toml
# ~/.config/noctalia/bar.toml
[bar.default]
position = "top"
radius = 0
capsule = false
background_opacity = 1.0
start  = ["launcher", "workspaces"]
center = ["caffeine", "clock", "keyboard_layout", "weather", "system-update"]
end    = ["tray", "claude-usage", "notifications", "bluetooth", "network", "brightness", "battery", "control-center"]

[widget.clock]
format = "{:%A %H:%M:%S}"

[widget.keyboard_layout]
display = "short"

[widget.weather]
show_condition = true
show_temperature = true

[widget.network]
show_label = false
vpn_status = "replace"

[widget.bluetooth]
show_label = false

[widget.brightness]
show_label = true

[widget.battery]
device = "auto"
display_mode = "glyph"
label_content = "percent"

[widget.system-update]
type = "scripted"
script = "~/.config/noctalia/scripts/system_update.lua"

[widget.claude-usage]
type = "scripted"
script = "~/.config/noctalia/scripts/claude_usage.lua"
```
`sysmon` (нагрузка/температура CPU на баре) — рассматривался и убран
полностью, не нужен. `nightlight`-виджет на баре — не нужен, пользователь
привык, что ночной свет всегда включён (форс-режим ниже, без тумблера).

```toml
# ~/.config/noctalia/theme.toml
[theme]
mode = "dark"
source = "custom"
custom_palette = "Vantablack"

[nightlight]
enabled = true
force = true
```

```json
// ~/.config/noctalia/palettes/Vantablack.json
{
  "dark": {
    "mPrimary": "#ffffff",
    "mOnPrimary": "#000000",
    "mSecondary": "#8d8d8d",
    "mOnSecondary": "#000000",
    "mTertiary": "#7a7a7a",
    "mOnTertiary": "#000000",
    "mError": "#a4a4a4",
    "mOnError": "#000000",
    "mSurface": "#000000",
    "mOnSurface": "#ffffff",
    "mSurfaceVariant": "#1a1a1a",
    "mOnSurfaceVariant": "#ececec",
    "mOutline": "#505050",
    "mShadow": "#000000",
    "mHover": "#1a1a1a",
    "mOnHover": "#ffffff"
  }
}
```
`light`-вариант не нужен — пользователь всегда на тёмной, Noctalia сама
использует `dark` для обоих режимов при отсутствии `light`.

```toml
# ~/.config/noctalia/launcher.toml
[shell.launcher.providers.session]
prefix = "session"
global = true

[shell.launcher.dmenu.entry.cfg]
prefix  = "cfg"
glyph   = "settings"
global  = false
command = "printf '~/.config/niri/config.kdl\n~/.config/fish/config.fish\n~/.config/fish/functions/fish_prompt.fish\n~/.config/noctalia/bar.toml\n~/.config/noctalia/theme.toml\n~/.config/noctalia/launcher.toml\n~/.config/noctalia/palettes/Vantablack.json\n~/.config/mimeapps.list\n'"
exec    = "chezmoi edit {selection}"
```
`global = true` на session-провайдере — `shutdown`/`reboot`/`lock` работают
прямо из общего поиска лаунчера без префикса `/session`. `/cfg` открывает
быстрый доступ к конфигам из списка выше, через `chezmoi edit` (правит
source в chezmoi-репозитории, не голый target-путь).

### Noctalia — scripted bar-виджеты (Luau) — ✅ решено 2026-10
Оба — через механизм "scripted widget" (`type = "scripted"` в bar.toml выше),
не полноценные plugin.toml-плагины — легче, без установки в каталог плагинов.

```lua
-- ~/.config/noctalia/scripts/system_update.lua
-- Список того, что считается "важным" — редактируется прямо здесь, Lua-паттерны:
local CRITICAL = {
  "^linux%-cachyos",   -- ядро
  "^niri$",
  "^noctalia",         -- сам шелл
  "nvidia",
  "^mesa$",
  "^systemd$",
}

local function isCritical(pkg)
  for _, pat in ipairs(CRITICAL) do
    if string.match(pkg, pat) then return true end
  end
  return false
end

local function refresh()
  noctalia.runAsync("checkupdates 2>/dev/null", function(res)
    local total, critical = 0, 0
    for line in string.gmatch(res.stdout or "", "[^\n]+") do
      local pkg = string.match(line, "^(%S+)")
      if pkg then
        total = total + 1
        if isCritical(pkg) then critical = critical + 1 end
      end
    end

    if critical > 0 then
      barWidget.setGlyph("alert-triangle")
      barWidget.setText(tostring(critical))
    elseif total > 0 then
      barWidget.setGlyph("download")
      barWidget.setText(tostring(total))
    else
      barWidget.setGlyph("check")
      barWidget.setText("")
    end
    barWidget.setTooltip(total .. " всего в очереди, " .. critical .. " важных")
  end)
end

function update()
  -- по примерам из документации интервал задаётся внутри update()
  noctalia.setUpdateInterval(1800000) -- раз в 30 минут, чаще незачем — сетевой запрос
  refresh()
end

function onClick()
  -- только показать список, ничего не обновляет — апдейт только руками.
  -- sh -c явно: read -p есть только в bash, а терминал может запускать fish
  noctalia.runInTerminal([[sh -c 'checkupdates; echo; printf "Enter to close... "; read _']])
end
```

```lua
-- ~/.config/noctalia/scripts/claude_usage.lua
-- Токен читается и используется целиком внутри одного шелл-вызова. Заголовки
-- передаются curl через stdin (-H @-), printf — встроенная команда шелла,
-- так что токен не попадает ни в ps aux, ни на диск (раньше — временный файл,
-- изменено 2026-10). ⚠️ Эндпоинт неофициальный — может поменяться без
-- предупреждения, тогда виджет покажет "!".
local CMD = [[
tok=$(jq -r '.claudeAiOauth.accessToken // empty' ~/.claude/.credentials.json 2>/dev/null)
if [ -z "$tok" ]; then exit 1; fi
printf 'Authorization: Bearer %s\nanthropic-beta: oauth-2025-04-20\nAccept: application/json\n' "$tok" \
  | curl -s -m 10 -H @- https://api.anthropic.com/api/oauth/usage
]]

local function pct(v)
  if v == nil then return nil end
  if v <= 1 then return v * 100 end
  return v
end

local function refresh()
  noctalia.runAsync(CMD, function(res)
    if res.exitCode ~= 0 or not res.stdout or res.stdout == "" then
      barWidget.setGlyph("sparkles")
      barWidget.setText("")
      barWidget.setTooltip("Claude: нет токена или сеть недоступна")
      return
    end

    local data = noctalia.json.decode(res.stdout)
    if not data or data.error then
      barWidget.setGlyph("sparkles")
      barWidget.setText("!")
      barWidget.setTooltip("Claude: " .. tostring(data and data.error and data.error.message or "битый ответ API"))
      return
    end

    local session = data.five_hour
    local weekly  = data.seven_day or data.seven_day_oauth_apps
    local sessionPct = session and pct(session.utilization)
    local weeklyPct  = weekly and pct(weekly.utilization)
    local shown = sessionPct or weeklyPct or 0

    barWidget.setGlyph("sparkles")
    barWidget.setText(string.format("%.0f%%", shown))

    local lines = {}
    if sessionPct then table.insert(lines, string.format("Session (5h): %.0f%%", sessionPct)) end
    if weeklyPct  then table.insert(lines, string.format("Weekly (7d): %.0f%%", weeklyPct)) end
    barWidget.setTooltip(table.concat(lines, "\n"))
  end)
end

function update()
  noctalia.setUpdateInterval(300000) -- 5 минут — личный лимит, чаще дёргать незачем
  refresh()
end
```
Зависимости под оба скрипта: `jq` (под claude_usage.lua) — **уже есть в
core** (`fish+zoxide+fzf+bat+eza+yazi+fd+ripgrep+jq`), добавлять не нужно;
`checkupdates` (под system_update.lua) — из `pacman-contrib`, которого
**в плане нет вообще** (проверено grep'ом по исходному core-plan.md) —
**добавить `pacman-contrib` в core-пакеты**.

**Статус проверки Luau-API (2026-10, по документации Noctalia v5):**
подтверждено — `type = "scripted"` + `script`, `barWidget.setText/setGlyph/
setTooltip`, `noctalia.setUpdateInterval`, `noctalia.runAsync(cmd, cb)` (в
`result` есть `exitCode`/`stdout`/`stderr`; подстановки `$(...)` работают
только в строковой форме — она и используется), `noctalia.runInTerminal`,
`noctalia.json.decode`. Исправлено по итогам сверки: `setUpdateInterval`
перенесён внутрь `update()` (как в примерах документации), а `read -p`
заменён на переносимый `sh -c` (раньше сработал бы только в bash).
**Не проверено вживую**: имена Tabler-иконок (`alert-triangle`, `download`,
`check`, `sparkles`) и то, что первый `update()` вызывается сразу при
загрузке виджета — сверить после установки.

### Niri — config.kdl, window/layer-rules — ✅ решено 2026-10 (единственная готовая секция из полного config.kdl, остальное пользователь пишет сам/вместе отдельным заходом)
```kdl
// БАЗОВАЯ ПОЛИТИКА — тайлить всё. Исключения ниже по файлу,
// порядок правил имеет значение (общее сверху, частное — ниже).
window-rule {
    open-floating false
}

// Firefox — Picture-in-Picture (совпадает с дефолтом niri, но раз наш
// config.kdl полностью заменяет дефолтный файл — пишем явно)
window-rule {
    match app-id="firefox$" title="^Picture-in-Picture$"
    open-floating true
}

// Steam — уведомления (друзья в сети/в игре + системные) сбоку экрана
window-rule {
    match app-id="steam" title=r#"^notificationtoasts_\d+_desktop$"#
    default-floating-position x=16 y=0 relative-to="right"
}
// Остальные окна Steam (библиотека, оверлей) правилами пока не описаны —
// по опыту реальных Niri-конфигов туда часто добавляют что-то ещё,
// донастроим по факту первого реального запуска.

// MPV — VRR для видео, не только под игры
window-rule {
    match app-id="^mpv$"
    variable-refresh-rate true
}

// Noctalia — окно настроек плавает, не тайлится
window-rule {
    match app-id="dev.noctalia.Noctalia.Settings"
    open-floating true
    default-column-width { fixed 1080; }
    default-window-height { fixed 920; }
}

// Noctalia — скругление углов НАМЕРЕННО 0, не 20 (официальная рекомендация
// Noctalia даёт 20px, но у нас плоская Vantablack-эстетика — 20px спорил бы
// визуально с radius=0 на баре)
window-rule {
    geometry-corner-radius 0
    clip-to-geometry true
}

// Noctalia overview — плоский минималистичный стиль, без блюра обоев
layer-rule {
    match namespace="^noctalia-(bar-main|notification|dock|panel)$"
    background-effect {
        xray false
    }
}
```
Явно отклонено и решено НЕ добавлять: правило под Zoom, `block-out-from`
для приватных окон (KeepassXC и т.п.) при скринкасте.

Отложено, не забыто:
- **Exiled Exchange 2** (xwayland-satellite) — нет готового community-правила
  под именно этот случай, делать через `niri msg pick-window` на живой системе
- **Noctalia desktop-виджеты** (`match app-id="quickshell", open-floating true`)
  — только если решим выносить виджеты на рабочий стол отдельно от бара

### Security-хардненинг — ✅ решено 2026-10 (сравнение с Secureblue/Kicksecure/CachyOS)
```bash
sudo tee /etc/sysctl.d/99-hardening.conf << 'EOF'
kernel.yama.ptrace_scope = 1
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1
EOF
sudo sysctl --system
```
**Сознательно НЕ включено**: `user.max_user_namespaces=0` (из набора
Kicksecure/security-misc) — ломает песочницу Flatpak (bubblewrap) и,
вероятно, часть механизмов Steam/Proton.

```bash
sudo tee /etc/modprobe.d/blacklist-hardening.conf << 'EOF'
install dccp /bin/false
install sctp /bin/false
install rds /bin/false
install tipc /bin/false
install cramfs /bin/false
install freevxfs /bin/false
install jffs2 /bin/false
install hfs /bin/false
install hfsplus /bin/false
EOF
```
Легаси сетевые протоколы и файловые системы — не используются, исторически
источник LPE-уязвимостей из-за слабого аудита кода. `udf`/`squashfs`
намеренно не тронуты — могут быть нужны (ISO/Flatpak/AppImage).

```bash
# faillock — на современном pambase pam_faillock уже встроен в system-auth
# по умолчанию (auth preauth/authfail/authsucc). Проверяем вместо того чтобы
# редактировать PAM-файлы вслепую:
if grep -q pam_faillock.so /etc/pam.d/system-auth; then
    echo "pam_faillock уже в system-auth штатно — faillock.conf ниже достаточно."
else
    echo "ВНИМАНИЕ: pam_faillock не найден в system-auth на этой системе." >&2
    echo "Нужна ручная проверка — pambase мог измениться. Не делаю авто-вставку в PAM вслепую." >&2
fi

sudo tee /etc/security/faillock.conf << 'EOF'
deny = 3
unlock_time = 600
EOF
```
Временная блокировка на 10 минут после 3 неудачных попыток входа, БЕЗ сноса
данных/LUKS-ключей, авторазблокировка по таймауту.

**Рассмотрены и осознанно НЕ взяты**: AppArmor (нужно тестировать профили в
complain mode, риск что-то сломать), hardened_malloc (риск производительности
на игровой машине), DNS-over-TLS (уже был готов — см. ниже), Chaotic-AUR (та
же степень доверия, что голый AUR, только без собственного PKGBUILD-ревью —
экономия времени признана не стоящей того).

**DNS-over-TLS** — уже был в плане (см. раздел "Безопасность, zram,
гибернация..." выше, `DNS=quad9`/`DNSOverTLS=yes`/`DNSSEC=allow-downgrade`),
при сравнении с security-дистрибутивами НЕ менялся, ничего добавлять не
понадобилось.

**Secure Boot** — рассмотрен подробно (иерархия PK/KEK/db, `sbctl`, хранение
приватных ключей на LUKS-зашифрованном `/usr/share/secureboot/keys/`, риски
утечки — опасен не только при физдоступе, но и при компрометации
root-сессии/бэкапов). **Осознанно ОТЛОЖЕН** на более поздний этап внедрения,
после того как базовая установка будет реально собрана и обкатана — не часть
текущей волны хардненинга.

### Снапшоты — загрузочное меню (Limine) — ✅ решено 2026-10
Лимиты snapper — см. выше. Добавлено — boot-into-snapshot
прямо из меню Limine (аналог `grub-btrfs`, но под Limine; CachyOS и Omarchy
используют тот же инструмент по умолчанию):
```bash
paru -S --needed limine-snapper-sync limine-mkinitcpio-hook
# limine-mkinitcpio-hook обязателен — без него initramfs не умеет
# монтировать btrfs-снапшот как полноценный root при загрузке

grep -q '^MAX_SNAPSHOT_ENTRIES=' /etc/default/limine 2>/dev/null \
    && sudo sed -i 's/^MAX_SNAPSHOT_ENTRIES=.*/MAX_SNAPSHOT_ENTRIES=10/' /etc/default/limine \
    || echo 'MAX_SNAPSHOT_ENTRIES=10' | sudo tee -a /etc/default/limine > /dev/null
# 10 последних снапшотов в меню (изменено 2026-10 вместе с лимитами snapper);
# grep-проверка — чтобы повторный прогон не дублировал строку

sudo mkinitcpio -P
sudo limine-snapper-sync
sudo systemctl enable --now limine-snapper-sync.service
```
Требование: `/boot`/ESP на FAT32 — стандартный UEFI ESP, отдельно готовить
не нужно.

### Скринсейвер и экран загрузки с именем пользователя (в стиле Omarchy) — решено 2026-10, не проверено вживую
Что именно было у Omarchy (проверено по их репозиторию, лицензия MIT):
- **Анимация "пиксельного" сбора/разбора названия** — это их **скринсейвер**:
  терминал на весь экран, в котором `ttfx` (их Rust-порт TerminalTextEffects,
  тоже MIT) случайным эффектом анимирует ASCII-баннер из
  `~/.config/omarchy/branding/screensaver.txt`. У знакомого с ником — тот же
  механизм, просто баннер заменён на его ник.
- **Экран ввода пароля диска (Plymouth)** у них статичный: логотип-картинка +
  поле пароля + прогресс-бар, без анимации.

Наша версия: баннер генерируется из имени, которое человек ввёл в
`install.sh` (поле GECOS, иначе логин), → тот же баннер крутится в
скринсейвере и тем же рисунком (как PNG) стоит на экране пароля диска.

**Генерация баннера** (в `run_onchange_after_04-desktop-niri-noctalia.sh`):
```bash
NAME="$(getent passwd "$USER" | cut -d: -f5 | cut -d, -f1)"
[ -n "$NAME" ] || NAME="$USER"
# figlet-шрифты только латинские: имя не латиницей → баннер из логина
LC_ALL=C grep -q '[^ -~]' <<< "$NAME" && NAME="$USER"
mkdir -p ~/.local/share/golden
figlet -w 300 -f "ANSI Shadow" "$NAME" > ~/.local/share/golden/banner.txt
```
Шрифт ⚠️ подобрать вживую: "ANSI Shadow" (пакет `figlet-fonts`, AUR) ближе
всего к блочному стилю логотипа Omarchy; запасной — `toilet -f future`.

**ttfx:** `cargo install --locked --git https://github.com/omacom-io/ttfx`
(⚠️ проверить, нет ли пакета `ttfx` в AUR — тогда через paru).

**Скринсейвер** — `dot_local/bin/executable_golden-screensaver` (запуск
окна) и `executable_golden-screensaver-loop` (анимация), логика перенесена
с `omarchy-screensaver`/`omarchy-launch-screensaver` под kitty и Niri:
```bash
#!/bin/bash
# golden-screensaver: одно окно kitty на весь экран
[ -f "$HOME/.local/share/golden/banner.txt" ] || exit 0
pgrep -f '[g]olden.screensaver' >/dev/null && exit 0
exec kitty --class=golden.screensaver --override font_size=18 \
    --override window_padding_width=0 -e "$HOME/.local/bin/golden-screensaver-loop"
```
```bash
#!/bin/bash
# golden-screensaver-loop: эффекты по кругу, выход по любой клавише
BANNER="$HOME/.local/share/golden/banner.txt"
printf '\033]11;rgb:00/00/00\007'   # чёрный фон
trap 'kill $pid 2>/dev/null; exit 0' INT TERM HUP
# окно сначала 80x24 и лишь потом получает размер экрана — иначе ttfx
# нарисует в углу (тот же обход, что у Omarchy)
for _ in $(seq 100); do [ "$(stty size)" != "24 80" ] && break; sleep 0.02; done
while true; do
    ttfx -i "$BANNER" --frame-rate 120 --canvas-width 0 --canvas-height 0 \
        --reuse-canvas --anchor-canvas c --anchor-text c \
        --random-effect --no-eol --no-restore-cursor &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        if read -rsn1 -t 1; then kill "$pid"; exit 0; fi
    done
done
```
Niri — правило окна: `match app-id="^golden\\.screensaver$"` → `open-fullscreen true`.
Запуск по бездействию: ⚠️ проверить, умеет ли idle-модуль Noctalia запускать
свою команду; если нет — `swayidle -w timeout 150 golden-screensaver`, а
блокировку оставить Noctalia (позже по времени). Выход — по клавише;
движение мыши терминал не видит (у Omarchy так же, плюс выход при потере фокуса).

**Экран пароля диска (Plymouth):** тема Omarchy (`default/plymouth`: скрипт +
картинки) копируется в `system/usr/share/plymouth/themes/golden/` вместе с
их LICENSE (условие MIT — сохранить уведомление). Меняется только
`logo.png` — его рендерит тот же скрипт из баннера:
```bash
magick -background none -fill white -font "JetBrains-Mono" -pointsize 14 \
    label:@"$HOME/.local/share/golden/banner.txt" /tmp/golden-logo.png
sudo install -Dm644 /tmp/golden-logo.png /usr/share/plymouth/themes/golden/logo.png
sudo plymouth-set-default-theme golden
```
Плюс хук `plymouth` в mkinitcpio и `quiet splash` в cmdline. ⚠️ При
systemd-initramfs хук ставится после `systemd`, а LUKS-хук должен быть
`sd-encrypt` — сверить порядок и пересобрать initramfs. Фон темы
(`Window.SetBackground...Color`) — привести к общей палитре, когда дойдём до темы.

### Шпаргалка и песочница для команд — решено 2026-10
`dot_local/share/golden/guide.md` — справочник частых команд с упражнениями;
`dot_config/fish/functions/golden-guide.fish` — открыть его (`glow -p`);
`dot_config/fish/functions/golden-practice.fish` — создать
песочницу `~/golden-practice` с тестовыми файлами и git-репозиторием, где
упражнения можно безопасно выполнять. Файл лежит отдельно и в репозитории,
его можно скачать и читать без установленной системы.

### Firefox — автоподкладка user.js — решено 2026-10
Профиль Firefox создаётся только при первом запуске, а путь к нему случайный
(`xxxxxxxx.default-release`), поэтому статичный dot-файл туда не положить.
Решение — пользовательский path-юнит: как только Firefox создаёт или меняет
профиль, сервис кладёт в каждый профиль симлинк на `user.js` из chezmoi.
Новые профили подхватываются сами. Следим за обоими путями: новые версии
Firefox могут создавать профили по XDG в `~/.config/mozilla/firefox/`.

`user.js` хранится в chezmoi как `dot_config/firefox-golden/user.js`.

`dot_config/systemd/user/firefox-userjs.path`:
```
[Unit]
Description=Следить за профилями Firefox

[Path]
PathChanged=%h/.mozilla/firefox/profiles.ini
PathChanged=%h/.config/mozilla/firefox/profiles.ini

[Install]
WantedBy=default.target
```

`dot_config/systemd/user/firefox-userjs.service`:
```
[Unit]
Description=Подложить user.js во все профили Firefox

[Service]
Type=oneshot
ExecStart=%h/.local/bin/firefox-userjs.sh
```

`dot_local/bin/executable_firefox-userjs.sh`:
```bash
#!/bin/bash
# Для каждого профиля из profiles.ini — симлинк на общий user.js.
# Path= бывает относительным (IsRelative=1) — тогда он от папки profiles.ini.
SRC="$HOME/.config/firefox-golden/user.js"
[ -f "$SRC" ] || exit 0
for base in "$HOME/.mozilla/firefox" "$HOME/.config/mozilla/firefox"; do
    ini="$base/profiles.ini"
    [ -f "$ini" ] || continue
    grep '^Path=' "$ini" | cut -d= -f2- | while read -r p; do
        case "$p" in /*) dir="$p" ;; *) dir="$base/$p" ;; esac
        [ -d "$dir" ] && ln -sfn "$SRC" "$dir/user.js"
    done
done
```
Включение: `systemctl --user enable --now firefox-userjs.path`, плюс разовый
`systemctl --user start firefox-userjs.service` на случай, если профиль уже
есть. Симлинк, а не копия: правка `user.js` в chezmoi сразу действует во всех
профилях со следующего запуска Firefox.

### Пакетный менеджмент — pacsea + paru — ✅ решено 2026-10
Сравнивались: `pamac-aur` (GUI, не нужен — пользователь хочет консоль),
`pacseek` (Go, зрелее, но жёстко линкуется с `libalpm` — ломался на рост
версии до v16 + требует `landlock`, риск конкретно на rolling-release),
`pacsea` (Rust, активный security-скан ClamAV/Trivy/ShellCheck/Semgrep, были
единичные баги установки, признано приемлемым).

**Решение: `pacsea-bin`** (оба инструмента — paru и pacsea — на Rust):
```bash
paru -S --needed pacsea-bin
```
Настройка AUR-хелпера (`paru`, не `yay`) и сканеров (для старта —
ShellCheck+ClamAV, без внешних API) — через встроенный экран "Optional Deps"
внутри pacsea, не через ручной конфиг-файл.

## 4. Архитектура скрипта (решено, не реализовано) — раскладка уточнена 2026-10

### Как устроена установка — две фазы
1. **`install.sh` (с live-ISO):** сам спрашивает всё, что нужно от человека,
   а archinstall работает под капотом без прямого участия пользователя
   (готовый JSON-конфиг + файл учётных данных; ⚠️ флаги `--config`,
   `--creds`, `--silent` сверить с актуальной версией archinstall).
   Вопросы: имя пользователя (логин), отображаемое имя (необязательно, по
   умолчанию = логин), пароль пользователя, пароль шифрования диска (LUKS),
   имя машины. Отображаемое имя записывается в системную учётную запись
   (поле GECOS) — оттуда его потом берёт экран разблокировки. Больше ничего:
   до первой загрузки нет пользовательской сессии, а половине шагов нужен
   `systemctl --user`.
2. **Первый вход в систему (TTY или графика):** одна команда
   `sudo pacman -S --needed chezmoi git && chezmoi init --apply <URL>` —
   chezmoi сам раскладывает dotfiles и по порядку прогоняет все
   `run_*`-скрипты. Это и есть "единый скрипт установки": фаза 2 целиком
   внутри chezmoi, отдельный оркестратор не нужен.

Та же механика дальше обновляет систему: `chezmoi update` = git pull + apply.

### Правило раскладки — что куда
| Что | Где в репо | Кто применяет |
|---|---|---|
| Статичные конфиги в `$HOME` | `dot_config/...`, `dot_cargo/...`, `dot_local/bin/executable_*.sh` | chezmoi напрямую |
| Пользовательские systemd-юниты | `dot_config/systemd/user/...` | chezmoi + `systemctl --user enable` в run_once |
| Системные файлы (`/etc/...`, `/usr/local/bin/...`) | `system/...` (в `.chezmoiignore`) | `run_onchange_*`-скрипт через `sudo install -Dm644` |
| Генерируемое по железу (`environment.d/vaapi.conf`, `gaming.conf`) | нигде — пишет скрипт | run_once |
| Состояние другого инструмента (kitty `current-theme.conf` — его меняет переключатель тем) | нигде | сам инструмент |

**Почему `run_onchange` для системных файлов:** в скрипт вставляется хэш
файлов-источников (`{{ include "system/etc/nftables.conf" | sha256sum }}` в
комментарии). Поправил `nftables.conf` в репо — при следующем `chezmoi apply`
скрипт сам перезапустится и переложит файл. `run_once` применил бы его ровно
один раз за жизнь системы.

**Почему не `tee` из скриптов, как было:** chezmoi тогда не знает об этих
файлах — `chezmoi diff`/`edit` их не видят, правки на одной машине не
доезжают до второй, а `echo >>` при повторном прогоне дублирует строки.

```
~/.local/share/chezmoi/
├── .chezmoidata.yaml        # identity + Syncthing-папки (со skip) + optional-пакеты
├── .chezmoiignore           # system/, README.md
├── dot_config/              # fish, kitty, fuzzel, git, MangoHud, noctalia, niri, pipewire,
│                            # mise, environment.d/qt.conf, systemd/user, mimeapps.list,
│                            # fontconfig, easyeffects, gtk-3.0
├── dot_cargo/config.toml
├── dot_recoll/recoll.conf
├── dot_local/bin/           # system-health-check, cleanup-downloads, check-missing-packages, exiled-exchange-2
├── system/                  # etc/nftables.conf, etc/systemd/..., etc/sysctl.d/..., usr/local/bin/...
├── run_once_before_00-detect-hw.sh
├── run_once_after_01-pacman-core.sh
├── run_once_after_02-aur-paru.sh
├── run_onchange_after_03-security.sh.tmpl              # + хэши system/-файлов, которые он кладёт
├── run_onchange_after_04-desktop-niri-noctalia.sh.tmpl
├── run_once_after_05-dev-stack.sh
├── run_once_after_06-gaming.sh
├── run_once_after_07-services.sh                      # syncthing/rustdesk, без личных данных
└── run_once_after_99-secrets-interactive.sh           # git/ssh identity, read -s, со skip
```
Git: `git config --global ...` из блока Git → статичный `dot_config/git/config`;
личные name/email — в отдельном `~/.config/git/identity`, который пишет 99-й
скрипт, а `dot_config/git/config` подключает его через `[include]` — identity
не попадает в репозиторий.

Справочные материалы (диагностика, памятка на случай нерабочей загрузки,
niri-напоминания, Steam/uv-примеры) — в отдельном `README.md`, не здесь.
`niri/config.kdl` (2.7) и Kanshi-профили в оригинал не переносятся.
Изначально пользователь писал их сам с нуля; **с 2026-10 — комбинированный
формат** (идеи и решения пользователя, структура и справка по возможностям
конфига — Claude). Готова секция window/layer-rules (см. выше).

### Куда ложатся решения 2026-10 (привязка к дереву выше)
- `run_once_after_01-pacman-core.sh`: `pacman-contrib` (checkupdates для
  виджета обновлений, paccache) и `trash-cli` — ✅ внесены в core-список
- `run_once_after_02-aur-paru.sh`: `pacsea-bin`, а также
  `limine-snapper-sync` и `limine-mkinitcpio-hook`
- `run_once_after_03-security.sh`: sysctl-хардненинг, modprobe-blacklist,
  проверка pam_faillock + `faillock.conf`
- Шаг snapper/Limine (`/etc/default/limine`, `mkinitcpio -P`,
  `limine-snapper-sync`, enable сервиса) — в `03` или отдельным скриптом,
  **не решено**
- Dotfiles под chezmoi (НЕ `run_once`): `dot_config/noctalia/{bar,theme,
  launcher}.toml`, `dot_config/noctalia/palettes/Vantablack.json`,
  `dot_config/noctalia/scripts/{system_update,claude_usage}.lua`
- Niri window/layer-rules — часть будущего `dot_config/niri/config.kdl`
- Secure Boot — вне дерева, отложен
