# Golden setup — что осталось

Решения — `decisions.md`, проверки на живой системе — `tests.md`.
Здесь — только то, что ещё предстоит сделать или решить.

## Где мы сейчас

Все решения пересмотрены и зафиксированы (ревизия 2026-10-11/12). Сессия по
Niri завершена (2026-10-12): конфиг готов и проверен парсером Niri 26.04 —
лежит в `dot_config/niri/`. Остальной код ещё живёт в `raw.md` и местами
расходится с решениями — при сборке репозитория правда за `decisions.md`.

## Следующие шаги — по порядку

0. **Документы — в GitHub-репозиторий** (папка `docs/`), чтобы не
   зависеть от чатов: история правок, доступ из любого чата по ссылке.
1. ~~**Сессия по Niri**~~ — готово, `decisions.md` §6а, файлы в
   `dot_config/niri/`.
2. **Собрать chezmoi-репозиторий** (публичный) по `decisions.md`. Перенести
   код из `raw.md` и привести к решениям, дописать новое:
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
   - `install.sh` + JSON archinstall (вопросы из `decisions.md` §1);
   - детект железа, пакеты файлами (core / optional / железо / личное);
   - Plymouth-тема Omarchy с баннером, greetd с автологином, пустая связка;
   - nftables (input + forward для Docker) и `port-open` / `port-close`;
   - `golden-dns`, `golden-disks`, `golden-update`, `golden-doctor`,
     миграции;
   - меню `menu.jsonc` + отрисовка через fuzzel, кнопка-логотип в баре;
   - система тем: палитры Omarchy + шаблоны + переключатель;
   - скринсейвер (`ttfx`), таймеры бездействия;
   - ryzenadj по таблице CPU, индикатор Nvidia, порог батареи и «до 100%»;
   - pkgdiff, виджет лимитов Claude (гибрид + статистика по дням),
     автоподкладка `user.js`;
   - копия заголовка LUKS, `RECOVERY.md`;
   - чистка «Загрузок» и корзины, буфер обмена, Docker, mise / uv / rustup;
   - последний шаг: git, SSH-ключ, `gh`.
   - личный слой: ссылки `~/.claude/CLAUDE.md` и `~/.claude/templates/` →
     `~/Projects/syncthing/claude/`, блок `attribution` (без соавторства) в
     `~/.claude/settings.json`.
   Убрать из кода всё из списка «Убрано» в `decisions.md` §9.
3. **CI:** shellcheck в GitHub Actions.
4. **Тестовая установка в QEMU** — разделы `tests.md` с пометкой (QEMU),
   включая 2–3 виртуальных монитора.
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

## Мелкие решения на время сборки

- Точные имена пакетов там, где помечено ⚠️ в `tests.md`.
- Список расширений VS Code — после первой установки.

## Позже, отдельными заходами

- **Secure Boot** — команда `golden-secureboot` (sbctl, ключи Microsoft,
  подпись Limine); проверить ryzenadj — может понадобиться `ryzen_smu`.
  Потом — разблокировка диска через TPM для удалённой перезагрузки ПК.
- **Бэкап вне диска** — когда появится HDD (роль «бэкап» в `golden-disks`,
  btrbk) или второй сервер.
- **Свой шелл на Quickshell** — отдельный проект, читает тот же
  `menu.jsonc`; начать с бара и меню.
