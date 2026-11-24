# Ресёрч: аддон профилей биндов для WoW 3.3.5a (Warmane)

Дата: 2026-11-24. Клиент: 3.3.5a (build 12340, `## Interface: 30300`, Lua 5.1).

## 1. Задача

Хранить несколько наборов биндов (профилей) и переключать их из настроек аддона.
Основной сценарий — два режима: Bartender4 и стандартные панели Blizzard.
Профили общие для аккаунта, их можно применять на любом персонаже.

## 2. Существующие решения

| Аддон | 3.3.5a | Что делает | Чего не хватает |
|---|---|---|---|
| [Soulstone](https://github.com/pabhoz/Soulstone-WoW-Addon) (GPL-3, 2026) | да | Переносит бары, макросы, бинды и таланты между персонажами. Бинды пишет в char-set (`SaveBindings(2)`) | Снимок «персонаж целиком», а не переключаемые профили. Бинды собирает только через `GetBinding(i)` + `CLICK BT4Button1..120`. Не видит `SPELL`/`MACRO`/`ITEM`, `BT4PetButton`/`BT4StanceButton`. Нет конвертации BT4↔Blizzard |
| [SetupSwap](https://github.com/SuttonX/SetupSwap) (MIT) | да | Переключает наборы включённых аддонов и их SavedVariables через `EnableAddOn`/`DisableAddOn` + `ReloadUI`, AceDB-профили через `db:SetProfile` | В README прямо сказано: нативные бинды не сохраняет и не восстанавливает |
| [Key Bindings Profiler](https://wotlkhelper.com/category/addons/keybindingsprofiler) | заявлено | Сохранить, загрузить, удалить именованный профиль | Сам автор пишет, что бинды на спеллы, предметы и макросы могут не восстановиться. Детали не проверены |
| [Binder](https://warperia.com/addon-wotlk/binder/) | Warperia пишет «3.3.5», без interface-номера | Профили на аккаунт, автосмена по спеку (по описанию retail-версии) | Совместимость с 3.3.5 не подтверждена |
| [KeyBindProfiles](https://www.wowinterface.com/downloads/info26417-KeyBindProfiles.html) | нет (retail, Classic, Cata, TBC) | `/kbp save|load|delete|list`, профили по спекам | Не для 3.3.5a |
| BindPad | да | Бинды прямо на спеллы, предметы и макросы | Профилей всего набора биндов нет |
| Myslot | не подтверждено | Экспорт баров, макросов и биндов в строку | Поддержка 3.3.5 не подтверждена |

Вывод: на 3.3.5a никто не делает три вещи сразу:
- полный снимок биндов, включая `SPELL`/`MACRO`/`ITEM`/`CLICK` любых фреймов;
- переключение «режима» (Bartender4 вкл/выкл) вместе с биндами;
- конвертацию раскладки BT4↔Blizzard по слотам.

Ниша есть. Prior art для переключения аддонов — SetupSwap, для сбора биндов — Soulstone.

## 3. Как бинды устроены в 3.3.5a

### 3.1 API

- `SetBinding(key [, command [, mode]])`. Без `command` клавиша снимается. `SetBindingClick`, `SetBindingSpell`, `SetBindingMacro`, `SetBindingItem` — обёртки над командами `CLICK x:LeftButton`, `SPELL x`, `MACRO x`, `ITEM x`.
- Все `SetBinding*` запрещены в бою (`#nocombat`). Применение профиля нужно ставить в очередь до `PLAYER_REGEN_ENABLED`.
- `SaveBindings(1|2)` и `LoadBindings(1|2)`: 1 — аккаунт, 2 — персонаж. `GetCurrentBindingSet()` возвращает активный набор. Без `SaveBindings` изменения пропадут при следующей загрузке.
- Сохранение в набор 1 при активном наборе 2 удаляет персональные бинды (диалог `CONFIRM_DELETING_CHARACTER_SPECIFIC_BINDINGS`).
- `GetNumBindings()` / `GetBinding(i)` перечисляют только команды из `Bindings.xml`, включая заголовки `HEADER_*`. Бинды `SPELL`/`MACRO`/`ITEM` и `CLICK` на необъявленные фреймы в этот список не попадают.
  Полный снимок: перебрать все клавиши × 8 комбинаций модификаторов через `GetBindingAction(key)` и объединить с `GetBindingKey(cmd)` по списку `GetBinding`. Порядок модификаторов: `ALT-CTRL-SHIFT-`.
- `UPDATE_BINDINGS` — событие без payload.

### 3.2 Bartender4 4.4.2 (версия для 3.3.5)

Исходник сверен с коммитом `Nevcairiel/Bartender4@94f3b58`, он побайтно совпадает с 3.3.5-зеркалом.

- Кнопки: `BT4Button<N>`, где `N = (bar-1)*12 + i`, N = 1..120. Слот по умолчанию равен `N`. Бары 7–10 по умолчанию выключены.
- Бар 1 биндится на **`ACTIONBUTTON1-12`**, те же команды, что у Blizzard. `ReassignBindings` вешает override-бинды с этих клавиш на `BT4Button1-12`.
- Бары 2–10 биндятся через **`CLICK BT4ButtonN:LeftButton`** (`SetBindingClick`).
- Pet: `BONUSACTIONBUTTON1-10`. В 3.3.5 это команда пет-бара, общая с Blizzard. BT4 перехватывает её override-биндами.
- Stance: `SHAPESHIFTBUTTON1-10`, тоже общая команда с override.
- **`MULTIACTIONBAR*BUTTON*` BT4 4.4.2 не трогает.** Перенос появился только в 4.13.0 (2022). Отсюда главная разница между режимами — бары 3–6.
- `ReassignBindings` срабатывает на каждый `UPDATE_BINDINGS` и всегда вызывает `SaveBindings(GetCurrentBindingSet())`.
- Бинды **не хранятся** в профиле `Bartender4DB`, они живут в наборе биндов клиента. Профиль BT4 можно сменить снаружи: `Bartender4.db:SetProfile(name)`. Делать это только вне боя: `UpdateModuleConfigs` трогает secure-фреймы.
- Blizzard-бары при включённом BT4 скрыты (`Hide` + `UnregisterAllEvents`), но не уничтожены.

### 3.3 Соответствие слотов

| Слоты | Blizzard | Bartender4 |
|---|---|---|
| 1–12 | `ACTIONBUTTON1-12` | бар 1, тот же `ACTIONBUTTON1-12` |
| 13–24 | нет кнопки (2-я страница главного бара) | `CLICK BT4Button13-24` (бар 2) |
| 25–36 | `MULTIACTIONBAR3BUTTON1-12` (Right) | `CLICK BT4Button25-36` (бар 3) |
| 37–48 | `MULTIACTIONBAR4BUTTON1-12` (Right 2 / Left) | `CLICK BT4Button37-48` (бар 4) |
| 49–60 | `MULTIACTIONBAR2BUTTON1-12` (Bottom Right) | `CLICK BT4Button49-60` (бар 5) |
| 61–72 | `MULTIACTIONBAR1BUTTON1-12` (Bottom Left) | `CLICK BT4Button61-72` (бар 6) |
| 73–120 | нет кнопки (страницы стоек на главном баре) | `CLICK BT4Button73-120` (бары 7–10) |
| pet 1–10 | `BONUSACTIONBUTTON1-10` | то же |
| stance 1–10 | `SHAPESHIFTBUTTON1-10` | то же |

Бары 3–6 переводятся в обе стороны без потерь. Бар 1, pet и stance одинаковы в обоих режимах.
Бары 2 и 7–10 есть только в BT4: при переводе в Blizzard такие бинды попадают в отчёт «не перенесено».

## 4. Предложения к идее

Базовая идея пользователя — п. 4.1. Остальное — доработки. Приоритет обсуждаем на этапе спеки.

1. **Профили-снимки (ядро).** Сохранить текущие бинды под именем, применить, переименовать, дублировать, удалить. Хранение в account-wide SavedVariables, формат `key -> command`. Применение — полная замена: снять все текущие бинды и выставить бинды профиля.
2. **Полный сбор биндов.** Перебор клавиш вместо одного `GetBinding(i)`. Тогда сохранятся бинды `SPELL`/`MACRO`/`ITEM` и `CLICK` любых аддонов (BT4 pet/stance и прочие). Это слабое место Soulstone и Key Bindings Profiler.
3. **Режим как часть профиля.** Профиль может запомнить окружение: включён ли Bartender4 и, опционально, имя профиля BT4.
   При применении, если окружение отличается, аддон предлагает `EnableAddOn`/`DisableAddOn` + `ReloadUI`. Бинды применяются после перезагрузки (pending-флаг в SavedVariables).
   Переключение режима становится одним действием вместо «отключил BT4, релог, вспомнил бинды». Механизм проверен в SetupSwap.
4. **Конвертация BT4↔Blizzard по слотам (п. 3.3).** Настроил раскладку в одном режиме — получил профиль для другого. Непереносимые бинды попадают в отчёт.
5. **Безопасность:**
   - очередь применения до выхода из боя;
   - авто-бэкап перед каждым применением и кнопка «Отменить»;
   - предпросмотр diff: сколько и каких клавиш изменится;
   - выбор набора: char (2) или account (1). Предупреждение, что запись в account-set затирает char-set.
6. **Валидация при применении:** `CLICK` на несуществующий фрейм (например, BT4 выключен), неизвестный спелл, отсутствующий макрос — предупреждение, не ошибка.
7. **Автоприменение:** профиль по умолчанию для персонажа и, опционально, для каждого из двух спеков (`ACTIVE_TALENT_GROUP_CHANGED`).
8. **Импорт/экспорт строкой** для переноса между аккаунтами Warmane.
9. **Мост (опционально, v2).** Live override-бинды без переключения профиля:
   - при включённом BT4 — клавиши `MULTIACTIONBARnBUTTONm` на `BT4ButtonN`, как делает BT4 4.13+;
   - без BT4 — `CLICK BT4ButtonN` на `MultiBar*ButtonM`.
   Тогда один набор биндов работает в обоих режимах. Override-бинды не сохраняются в бинд-сет, поэтому мост ничего не портит.

## 5. Технические заметки

- Стек: Lua 5.1, Ace3 для 3.3.5 (AceAddon, AceDB, AceEvent, AceConsole, AceConfig/AceConfigDialog для панели в Interface Options). Библиотеки встраиваем, LibStub разруливает версии с копией в BT4.
- SavedVariables: account-wide `<Addon>DB` с полями `profiles`, `backups`, `pending`, `charSettings`.
- Тестируемость: ядро (сбор, diff, конвертация, применение) держим в чистых функциях над абстракцией WoW API. Тесты на `busted` с моками API, статика `luacheck`. Ручной чек-лист в игре на Warmane.
- Клиентские файлы: бинды лежат в `WTF/Account/<ACC>/bindings-cache.wtf` и `.../<Realm>/<Char>/bindings-cache.wtf`. Профили аддона — в `WTF/Account/<ACC>/SavedVariables/<Addon>.lua`. Это независимая копия, она защищает от потери биндов.

## 6. Непроверенное — проверить в игре (spike) до или в начале реализации

1. Сохраняются ли бинды `CLICK BT4ButtonN` в наборе, если BT4 выключен, а бинды пересохранены (`SaveBindings`)? От этого зависит, нужны ли наши снимки для защиты от потери.
2. Срабатывают ли при включённом BT4 клавиши, забинженные на `MULTIACTIONBAR*` (через скрытые Blizzard-кнопки)? Вывод сделан по коду, в игре не проверен.
3. Срабатывает ли `UPDATE_BINDINGS` на `SaveBindings` в 3.3.5? Нет ли цикла с `ReassignBindings` из BT4 при массовом применении?
4. Запрещены ли `SaveBindings`/`LoadBindings` в бою на 3.3.5?
5. Сколько клавиш возвращает `GetBinding(i)` в 3.3.5: две или больше?
6. Синхронизирует ли Warmane `bindings-cache` с сервером (account data)?

## Источники

- Soulstone: https://github.com/pabhoz/Soulstone-WoW-Addon (`Core.lua`: `BindingCommands`, `CaptureBindings`, `RestoreBindings`)
- SetupSwap: https://github.com/SuttonX/SetupSwap
- Key Bindings Profiler: https://wotlkhelper.com/category/addons/keybindingsprofiler
- Binder: https://warperia.com/addon-wotlk/binder/ , https://www.curseforge.com/wow/addons/binder
- KeyBindProfiles: https://www.wowinterface.com/downloads/info26417-KeyBindProfiles.html
- Список аддонов 3.3.5a: https://github.com/NoM0Re/WoW-3.3.5a-Addons
- Bartender4: https://github.com/Nevcairiel/Bartender4 (коммит `94f3b58`), 3.3.5-зеркало `BoatManFall3n/WoW_3.3.5a_Bartender4`
- API: https://warcraft.wiki.gg/wiki/API_SetBinding , https://warcraft.wiki.gg/wiki/API_SetBindingClick , https://warcraft.wiki.gg/wiki/API_SetOverrideBindingClick
- FrameXML 3.3.5: `wowgaming/3.3.5-interface-files` (`Blizzard_BindingUI.lua`, `MultiActionBars.lua`, `BonusActionBarFrame.lua`)
