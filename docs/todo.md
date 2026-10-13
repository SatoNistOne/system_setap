# Golden setup — что осталось

Решения — `decisions.md`, проверки на живой системе — `tests.md`.
Здесь — только то, что ещё предстоит сделать или решить.

## Где мы сейчас

Все решения пересмотрены и зафиксированы (ревизия 2026-10-11/12). Сессия по
Niri завершена (2026-10-12): конфиг в `dot_config/niri/`. Сессия по
установщику (2026-10-12): готовы фаза 1 (`install.sh` + `install/`) и начало
фазы 2 (chezmoi: конфиг из ответов установщика, детект железа, системные
файлы базы, пакеты, greetd). Всё проверено shellcheck / `bash -n`; JSON
archinstall — парсером archinstall 4.5; шаблоны chezmoi — рендером на
`text/template` с заглушками функций. Вживую (QEMU) ещё ничего не запускалось.
Остальной код ещё живёт в `raw.md` и местами расходится с решениями — при
сборке правда за `decisions.md`.

## Следующие шаги — по порядку

0. ~~**Документы — в GitHub-репозиторий**~~ — готово.
1. ~~**Сессия по Niri**~~ — готово, `decisions.md` §6а.
2. **Собрать chezmoi-репозиторий** по `decisions.md`. Готово:
   - ~~`install.sh` + JSON archinstall~~ (`install/archinstall-config.sh`);
   - ~~разметка: GPT, LUKS2, btrfs, сабвольюмы, своп-файл~~ (`install/disk.sh`);
   - ~~база в chroot: `[cachyos]`, `linux-cachyos` + Nvidia, initramfs
     systemd + sd-encrypt + Plymouth, Limine + UKI, snapper + snap-pac +
     limine-snapper-sync, zram, вложенные тома~~ (`install/target-setup.sh`);
   - ~~Plymouth-тема Omarchy с баннером из имени~~ (`system/usr/share/plymouth/themes/golden/`);
   - ~~детект железа~~ (`dot_local/bin/executable_golden-detect-hw`, общий
     для live-ISO и системы);
   - ~~списки пакетов файлами~~ (`packages/`), таблица ryzenadj (`data/`);
   - ~~chezmoi: `.chezmoiignore`, `.chezmoi.toml.tmpl` (из `answers.toml`),
     `run_before_00-detect-hw`, `run_onchange_after_05-system-base`,
     `_10-packages` (paru + review AUR), `_20-greetd` (автологин)~~.

   Осталось — перенести из `raw.md` и привести к решениям, дописать новое:
   - скрипты, на которые ссылается `cfg/binds.kdl`: `golden-menu` (и
     разделы `system`, `capture`), `golden-keybinds` (список из
     `binds.kdl` в fuzzel, Enter — выполнить; он же пункт меню),
     `golden-clipboard` (cliphist в fuzzel); в «Захвате» пункт
     «Область → Satty»: вызвать `screenshot` Niri, дождаться события
     `ScreenshotCaptured` из `niri msg --json event-stream`, открыть файл
     в Satty;
   - пользовательские службы systemd от `graphical-session.target`:
     cliphist, живые обои, EasyEffects, usbguard-notifier (Syncthing — своя);
   - шаблон темы для Niri → `~/.config/niri/theme.kdl`;
   - пустая связка ключей (gnome-keyring), gcr-ssh-agent;
   - nftables (input + forward для Docker) и `port-open` / `port-close`;
   - `golden-dns`, `golden-disks`, `golden-update`, `golden-doctor`,
     миграции;
   - меню `menu.jsonc` + отрисовка через fuzzel, кнопка-логотип в баре;
   - система тем: палитры Omarchy + шаблоны + переключатель (+ фон
     Plymouth и цвета `limine.conf` из темы);
   - скринсейвер (`ttfx`), таймеры бездействия; баннер для скринсейвера
     шрифтом «ANSI Shadow» (сейчас Plymouth-логотип — стандартный figlet);
   - ryzenadj по `data/ryzenadj.tsv` / `answers.toml`, индикатор Nvidia,
     порог батареи и «до 100%»; Nvidia: suspend/hibernate-службы и
     `NVreg_PreserveVideoMemoryAllocations=1`;
   - pkgdiff, виджет лимитов Claude (гибрид + статистика по дням),
     автоподкладка `user.js`;
   - копия заголовка LUKS, `RECOVERY.md`;
   - чистка «Загрузок» и корзины, буфер обмена, Docker, mise / uv / rustup;
   - последний шаг: git, SSH-ключ, `gh`.
   - личный слой: ссылки `~/.claude/CLAUDE.md` и `~/.claude/templates/` →
     `~/Projects/syncthing/claude/`, блок `attribution` (без соавторства) в
     `~/.claude/settings.json`.
   Убрать из кода всё из списка «Убрано» в `decisions.md` §9.
3. **CI:** написан (`.github/workflows/check.yml` → `test/ci-check.sh`:
   shellcheck, JSON archinstall, списки пакетов, «Убрано» из §9, шаблоны
   chezmoi). Первый прогон в Actions — через Claude Code на ПК (модель
   Sonnet); часть с chezmoi в песочнице не запускалась — её проверит CI.
   `install.sh` теперь отказывается работать вне live-ISO Arch.
4. **Тестовая установка в QEMU** (OVMF, UEFI) — разделы `tests.md` с
   пометкой (QEMU), включая 2–3 виртуальных монитора. Первым делом —
   «Установка и загрузка»: фаза 1 целиком ещё не запускалась.
5. **Установка на ноут**, затем на ПК — остальные пункты `tests.md`.
6. **Сервер** (рядом с VPN): RustDesk (hbbs/hbbr), узел Syncthing, точка
   входа SSH-туннелей, Vaultwarden (домен + HTTPS-сертификат; Bitwarden на
   машинах переключить на свой сервер).

## Открытые решения

- **Темы для старта:** какие 3–4 палитры кроме Vantablack.
- **Версии:** v1 (установщик, база, безопасность, снапшоты, Niri, Noctalia,
  меню, `golden-update`) → v2 (темы, `golden-disks` с ролями,
  `golden-doctor`, виджеты, миграции, pkgdiff) → v3 (Secure Boot, свой
  шелл). Друзьям — после v1 и месяца жизни на своих машинах.
- **Локаль системы:** сейчас `en_US.UTF-8` (поставил установщик, не решалось
  отдельно). Нужны ли русские форматы даты/чисел (`LC_TIME=ru_RU.UTF-8` и
  т.п.) или русский интерфейс приложений?
- **Polkit-агент** (окна «введите пароль» для GUI-программ): есть ли он в
  Noctalia v5 или нужен отдельный пакет.
- **Exiled Exchange 2** — стал обычным optional-пунктом; нужен способ
  установки AppImage (скрипт или пакет AUR, если появится).
- **[личное] кроме пакетов** (виджет лимитов Claude, pkgdiff): тоже вопросом
  «надо / не надо» при установке для всех — или только на моих машинах?

## Мелкие решения на время сборки

- Точные имена пакетов там, где помечено ⚠️ в `packages/` и `tests.md`.
- Список расширений VS Code — после первой установки.

## Позже, отдельными заходами

- **Secure Boot** — команда `golden-secureboot` (sbctl, ключи Microsoft,
  подпись UKI и Limine); проверить ryzenadj — может понадобиться
  `ryzen_smu`. Потом — разблокировка диска через TPM для удалённой
  перезагрузки ПК (initramfs уже на systemd + sd-encrypt).
- **Бэкап вне диска** — когда появится HDD (роль «бэкап» в `golden-disks`,
  btrbk) или второй сервер.
- **Свой шелл на Quickshell** — отдельный проект, читает тот же
  `menu.jsonc`; начать с бара и меню.
