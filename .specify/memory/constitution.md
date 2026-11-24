# BindShifter Constitution

BindShifter is a World of Warcraft 3.3.5a addon for Warmane (client build 12340, Interface 30300).
It stores account-wide keybinding profiles and switches between them, including switching between
Bartender4 and Blizzard action bar modes. It is built as a complete product, not an MVP. The
background research is in `docs/research.md`.

## Core Principles

### I. Target Platform Fidelity

- Code MUST be Lua 5.1 and MUST use only APIs that exist in the 3.3.5a client (build 12340).
- APIs from retail or Classic-era clients MUST NOT be used. This includes the `C_*` namespaces,
  `Settings.*`, mixins and `GetBinding` returns that include a category.
- If no API reference covers 3.3.5a behaviour, the 3.3.5 FrameXML source is the reference.
- Third-party libraries (Ace3, LibStub and others) MUST be embedded. They MUST be versions that
  are known to run on 3.3.5a.
- The TOC MUST declare `## Interface: 30300`.
- Bartender4 MUST be an optional dependency. Every feature that does not concern Bartender4 MUST
  work when Bartender4 is not installed.

Rationale: Warmane runs the frozen 3.3.5a client. One call to an API that does not exist breaks
the whole addon at load time.

### II. Combat Safety (NON-NEGOTIABLE)

- The addon MUST NOT call `#nocombat` or protected operations while `InCombatLockdown()` is true.
  These include:
  - `SetBinding*` and `SaveBindings`/`LoadBindings`;
  - `EnableAddOn`/`DisableAddOn` followed by `ReloadUI`;
  - Bartender4 profile changes (`Bartender4.db:SetProfile`).
- If one of these operations is requested during combat, the addon MUST queue it, tell the user,
  and run it on `PLAYER_REGEN_ENABLED`. A newer request for the same kind of operation replaces
  the older one.
- The addon MUST NOT taint secure frames. It MUST NOT modify secure attributes or replace Blizzard
  or Bartender4 functions. Where a hook is unavoidable, it MUST use `hooksecurefunc`.
- A flow that toggles addons or reloads the UI MUST get explicit user confirmation first.

Rationale: if the client blocks an action in combat, the user can end up with a half-applied
binding set at the worst possible moment.

### III. Never Lose User Bindings (NON-NEGOTIABLE)

- Before any operation that changes the live bindings or stored data, the addon MUST create an
  automatic backup of the current state. Such operations include applying a profile, converting
  and applying, an import that overwrites, a delete and a reset.
- The user MUST be able to undo the operation in one action.
- An apply that the user starts MUST show a diff preview: keys added, changed and removed. The
  user MUST confirm the preview before anything is applied.
- An automatic apply (auto-apply on login or on spec change) MUST still create a backup and MUST
  print a summary of what changed.
- Some bindings cannot be applied: the target frame is missing, the spell is unknown, the macro is
  missing, or the slot cannot be translated between modes. These bindings MUST be reported to the
  user. They MUST NOT be removed from the stored profile.
- Capture MUST record every bound key, not only commands listed in `Bindings.xml`. This includes
  `SPELL`, `MACRO`, `ITEM` and `CLICK` bindings to any frame.

Rationale: losing a keybinding layout costs the user hours. A profile must be a reliable source
of truth.

### IV. Testable Pure Core

- Domain logic MUST be pure Lua that does not read WoW globals directly. Domain logic covers:
  - the binding snapshot model and capture normalization;
  - diff;
  - Bartender4↔Blizzard slot translation;
  - import/export serialization;
  - the profile store and schema migrations;
  - validation;
  - the operation queue.
- All WoW API access MUST go through a thin adapter that the domain code receives as a dependency.
- Domain logic MUST be covered by `busted` unit tests with a mocked adapter. Tests for a behaviour
  are written before or together with its implementation.
- `luacheck` MUST pass with the project configuration.
- Behaviour that cannot be unit-tested MUST have steps in a manual in-game checklist that is run
  on Warmane before release. This covers secure frames, reload flows, Bartender4 interaction and
  UI rendering.

Rationale: the game client cannot run in CI. A pure core and an adapter seam keep most behaviour
verifiable without the game.

### V. Explicit Binding-Set Semantics

- By default, profiles MUST be applied to the character binding set (`SaveBindings(2)`).
- The account binding set (`SaveBindings(1)`) MAY be used only if the user chooses it explicitly.
  The UI MUST then warn the user that saving to the account set removes the character's own
  bindings.
- Every apply path MUST be explicit about which binding set it reads from and writes to. No apply
  path may rely on whatever set the client last left active.

Rationale: in 3.3.5a, writing to the wrong binding set silently changes bindings on every
character of the account.

### VI. Simplicity and Minimal Footprint

- Event handlers MUST be used instead of `OnUpdate` polling wherever an event exists.
- At load time the addon MUST do no more than read and migrate SavedVariables and register
  events and options.
- Persistent state MUST live in one account-wide SavedVariables table. That table MUST have a
  `schemaVersion` field and ordered migrations.
- The only globals the addon may create are its addon table, its SavedVariables and the slash
  command and binding identifiers that WoW requires.
- Every feature MUST trace back to a requirement in the spec. Any extra complexity MUST be
  justified in the plan's Complexity Tracking table.

Rationale: a small addon that loads quickly coexists well with the heavy UI addon sets that are
common on private servers.

### VII. Localization and Language Policy

- Every user-facing string in game MUST come from a locale table. `enUS` is the default and
  fallback. `ruRU` MUST be complete at release.
- Code, identifiers, code comments and commit messages MUST be in English.
- Project documents (spec, plan, research) MAY be in Russian.

Rationale: the main users are Russian-speaking Warmane players. An English codebase keeps the
code consistent and open to contributors.

## Platform & Technology Constraints

- Runtime: WoW client 3.3.5a (12340), Lua 5.1. No external processes or files other than
  SavedVariables.
- Libraries: LibStub plus the Ace3 modules that are needed (AceAddon-3.0, AceDB-3.0, AceEvent-3.0,
  AceConsole-3.0, AceConfig-3.0, AceConfigDialog-3.0, AceGUI-3.0, AceSerializer-3.0). Add a
  compression or encoding library only if the plan justifies it.
- Bartender4 integration targets Bartender4 4.4.x (the 3.3.5a line). It covers these binding
  commands:
  - `ACTIONBUTTON1-12` on bar 1;
  - `CLICK BT4Button13-120:LeftButton` on bars 2–10;
  - `BONUSACTIONBUTTON` and `SHAPESHIFTBUTTON` for the pet and stance bars;
  - `CLICK BT4PetButtonN` and `CLICK BT4StanceButtonN`.
  The slot mapping is defined in `docs/research.md` §3.3.
- Development tooling runs outside the game: `busted` for tests and `luacheck` for linting, both
  on Lua 5.1 or LuaJIT. The release package is a folder named `BindShifter` that contains
  `BindShifter.toc`.

## Development Workflow & Quality Gates

- The workflow follows Spec Kit: constitution → specify → clarify → plan → tasks → implement.
  Every plan MUST pass the Constitution Check before Phase 0 research and again after design.
- Gates before merging to `main`:
  1. `busted` is green.
  2. `luacheck` is clean.
  3. A changed SavedVariables schema has a migration and a test for it.
  4. A change to user-visible strings updates both the `enUS` and `ruRU` locale tables.
- Gate before release: the manual in-game checklist passes on Warmane, with Bartender4 enabled
  and with it disabled.
- Assumptions about 3.3.5a behaviour that are not yet verified (`docs/research.md` §6) MUST be
  recorded as spikes. They MUST be resolved before the features that depend on them are marked
  done.

## Governance

- This constitution overrides all other project practices. If it conflicts with another document,
  the constitution wins until it is amended.
- An amendment MUST:
  - be proposed as a change to `.specify/memory/constitution.md`;
  - include a Sync Impact Report;
  - check and update any dependent Spec Kit templates or docs in the same change.
- Versioning follows semantic versioning:
  - MAJOR when a principle is removed or redefined in a way that is not backward compatible;
  - MINOR when a principle or section is added or materially expanded;
  - PATCH for clarifications and wording.
- Every review MUST check compliance with the principles. The two NON-NEGOTIABLE principles (II
  and III) cannot be waived by Complexity Tracking.

**Version**: 1.0.0 | **Ratified**: 2026-11-24 | **Last Amended**: 2026-11-24
