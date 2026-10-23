# LAST SHIFT: Signal Lost — Development Plan

Status legend: `[ ]` not started · `[~]` in progress · `[x]` done (code written and checked offline) · `[✓]` verified in Studio

**Current state (2026-10-23):** Phases 1–3 code complete and passing all offline checks. **None has been tested in Roblox Studio yet.**

Repository: https://github.com/kusal2002/LastShift (Phase 1 on `main`; Phase 2 on `phase-2/player-systems`, PR #1; Phase 3 on `phase-3/echo-ai`, stacked on Phase 2).

---

## Toolchain

Pinned in `rokit.toml` (install Rokit, then run `rokit install` in this folder):

| Tool | Version | Used for |
|---|---|---|
| Rojo | 7.7.1 | Syncs `src/` into Studio, builds the place file |
| Selene | 0.32.0 | Lint |
| StyLua | 2.6.0 | Formatting |
| Lune | 0.11.1 | Runs unit tests for pure logic outside Roblox |
| luau-lsp | 1.70.1 | Strict type checking against the Roblox API |

### Check commands
```bash
lune run tests/run
stylua --check src tests
selene src
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --definitions=@roblox=types/globalTypes.d.luau src
rojo build -o build/LastShift.rbxl
```
`types/globalTypes.d.luau` is downloaded (not committed) from
`https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau`.

---

## Phase 0 — Repository audit ✅

- Folder was empty; nothing to preserve. Roblox Studio installed; no Roblox tooling installed.
- Decision: Rojo workflow, no Wally packages, all helpers written in-house.
- Decision: graybox map generated from a text grid in code; gameplay finds map objects by CollectionService tags, so a hand-built map can replace it later without code changes.

---

## Phase 1 — Playable graybox `[x]` (awaiting Studio test)

### Layout
```
src/
  shared/  -> ReplicatedStorage.Shared
    Config/      Round, Objectives, Tags, Debug, Assets
    Logic/       RoundTransitions, RoundOutcome, Calibration, Selection, MapGrid   (pure, unit-tested)
    Util/        Log, Maid, RateLimiter, Signal
    Types.luau   Remotes.luau
  server/  -> ServerScriptService.Server
    Bootstrap.server.luau
    Map/StationLayout.luau      text-grid station layout
    Services/    RemoteService, MapService, InteractionService, ObjectiveService, ExtractionService, RoundService
    Objectives/  ObjectiveTypes, FuseObjective, CalibrationObjective, EvidenceObjective
  client/  -> StarterPlayer.StarterPlayerScripts.Client
    ClientBootstrap.client.luau  State.luau  UI/Theme.luau
    Controllers/ Lobby, Briefing, HUD (+ toasts), Calibration, Results
tests/     harness, logic_spec, run   (Lune)
```

### Round flow (all owned by `RoundService`)
Lobby → (PLAY pressed, 10 s countdown; 3 s if everyone is ready) → Briefing (8 s) → Investigation (8 min) → Extraction (90 s, stand in loading bay 3 s) → Results (15 s) → Lobby.
Cancels back to Lobby if every participant leaves. Ends early if nobody is left alive inside.

### Map tags and attributes
| Tag | Object | Notes |
|---|---|---|
| `StationSpawn` | invisible marker | 4 in the entrance hall |
| `FuseSpawn` | invisible marker on a crate | 3; one picked per round |
| `FusePanel` | breaker panel part | attribute `PanelId` |
| `RadioConsole` | console part | |
| `FrequencyBoard` | board part | target frequency shown on its front face (SurfaceGui `FrequencyDisplay`, auto-created) |
| `EvidenceSpawn` | invisible marker on a desk | 4; one picked per round |
| `ExtractionZone` | invisible non-colliding box | loading bay beyond the exit door |
| `ExitDoor` | door part | becomes passable at extraction |
| `LobbySpawn` | SpawnLocation | the only enabled spawn |

### Remotes (`ReplicatedStorage.Remotes`, created by the server)
| Remote | Direction | Validation |
|---|---|---|
| `RoundSnapshot`, `Notify`, `Results`, `CalibrationOpen`, `CalibrationClose` | server → client | client type-checks payloads |
| `SnapshotRequest` | client → server | rate limited (2 burst, 0.2/s) |
| `PlayRequest(boolean)` | client → server | type check, rate limit, rejected for players inside the station |
| `CalibrationSubmit(number)` | client → server | open session, round gate, alive, distance ≤ 14+4 studs, finite and in range, rate limit, lockout |
| `CalibrationCancel()` | client → server | rate limit |

Prompt interactions (fuse pickup, panel, console, evidence) are checked on the server for rate limit, round phase, player alive inside the station, and distance.

### Checklist
- [x] 1.0 Rokit, Rojo, Selene, StyLua, Lune, luau-lsp installed and pinned; git initialised
- [ ] 1.0 Rojo Studio plugin — **you need to install it** (see "Studio setup")
- [x] 1.0 Project moved to `D:\Projects\ROblox` and pushed to GitHub
- [x] 1.1 Shared config, types, remotes list, utilities, pure logic
- [x] 1.2 Server: bootstrap, remotes, map builder, interactions, objectives (fuse, calibration, evidence), extraction, round service
- [x] 1.3 Client: lobby, briefing, HUD with toasts, calibration dial, results
- [x] 1.4 Offline checks: 21/21 unit tests, StyLua clean, Selene 0 errors / 0 warnings, luau-lsp strict analysis 0 errors, `rojo build` succeeds
- [ ] 1.4 Studio playtest (steps below)

### Offline results (actually run, 2026-10-23)
- `lune run tests/run`: 21 passed, 0 failed (round transitions, outcomes, calibration math/input validation, selection, rate limiter, station layout validity and reachability)
- `selene src`: 0 errors, 0 warnings (disabled the `UDim2.fromScale` style suggestion)
- `luau-lsp analyze` (strict, Roblox definitions, Rojo sourcemap): 0 errors
- `rojo build`: produced `build/LastShift.rbxl`

Nothing has been run inside Roblox, so physics, prompts, UI layout and replication are unverified.

### Studio setup
1. Install the Rojo plugin: in a normal terminal (not inside the Claude app) run `rojo plugin install`, then restart Studio. (Installing from inside the Claude app fails because its writes to `%LOCALAPPDATA%\Roblox` are redirected.)
2. Build and open the place: `rojo build -o build/LastShift.rbxl`, then open `build/LastShift.rbxl` in Studio. (This place has no baseplate; the map is built by the server at runtime.)
3. For live editing: run `rojo serve` in this folder, then click **Connect** in the Rojo plugin.

### Studio test script (Phase 1 acceptance)
Run each and note pass/fail here.
1. **Solo start** — Play (F5). You spawn in the lobby with the lobby panel. Press PLAY → "DEPLOYING IN 3" → briefing → you appear in the entrance hall with the HUD.
2. **Fuse** — Find the glowing amber fuse on a crate, hold E/tap to pick up (toast + HUD "Carried by"). Breaker panel is in the generator room (bottom left). Hold to insert → panel turns amber, objective ticked. Try the panel without a fuse first → "needs a fuse" toast.
3. **Calibration** — Read the target on the board in the maintenance room (bottom right). Use the radio console in the operations room (top middle). Submit a wrong value → static toast, attempts drop. Three wrong → overload, console locked 10 s. Correct value → "Signal locked".
4. **Evidence** — Find the faint green-lit paper on a desk in a corner room; hold to examine.
5. **Extraction success** — After all three, exit door turns green and becomes passable. Stand in the loading bay 3 s → teleported to lobby, results show "SHIFT COMPLETE".
6. **Extraction fail** — Repeat, but don't enter the bay; after 90 s results show "SIGNAL LOST / exit sealed".
7. **Time-up** — Set `InvestigationDuration` to 30 in `Config/Round.luau`, start a round, do nothing → "shift ran out". Restore the value.
8. **Death** — During investigation, reset character (Esc → Reset). Solo: round ends "Nobody made it out"; you respawn in the lobby.
9. **Reset hygiene** — Play three rounds back to back. Check `Workspace.Station.RoundObjects` is empty in the lobby, only one fuse/evidence exists per round, no duplicate prompts on the panel/console, and the Output window has no errors.
10. **Two players** — Test tab → Clients and Servers → 2 players. Both press PLAY; both enter. One leaves mid-round (close their window) → round continues for the other. Both leave → server returns to lobby.
11. **Mobile layout** — Device emulator, a phone in portrait and landscape: panels fit, buttons are tappable, toasts don't cover the HUD.

---

## Phase 2 — Player systems `[x]` (awaiting Studio test)

### What was added
- `PlayerStateService` (server) owns stamina, sprinting, flashlight battery, health and downed state. Clients send only intents (`SprintRequest(boolean)`, `FlashlightToggle()`); the server sets `Humanoid.WalkSpeed` and publishes state as Player attributes: `Stamina`, `Battery`, `FlashlightOn`, `Sprinting`, `Downed`, `DownedEndsAt`, `SoloDowned`.
- Sprint: walk 12, sprint 19 studs/s. Stamina drains only while actually moving; after running dry you must recover to 25 before sprinting again. Tuning in `Config/Player.luau`.
- Flashlight: a server-side SpotLight on the head, so everyone sees each other's beams. Battery lasts 5 minutes and drains only during a round. Two wall chargers (`Q` in the layout, tag `ChargingStation`) give 2 refills each per round.
- Damage: `PlayerStateService.applyDamage(player, amount, source)` is the only way to hurt a player. A hit gives 1.5 s of protection. The first lethal hit **downs** you (crawl speed 3, no jumping, no interactions, no light).
  - Multiplayer: a teammate holds **Revive** for 4 s within 30 s, or you bleed out. Revive restores 50 health with 3 s of protection.
  - Solo: you get back up on your own after 10 s, once per round.
  - A second lethal hit, or any hit while downed, eliminates you.
  - Default Roblox health regeneration is disabled (`src/character/Health.server.luau`).
- Downed players can't extract; the team list in the HUD shows OK / DOWN / ESCAPED / LOST.
- Spectating: eliminated players can cycle the camera through teammates still inside (top-left panel; STOP returns to your own camera).
- HUD: health, stamina and light meters (bottom centre, with numbers as well as bars), team status, key hints.
- Controls: Shift (hold) / L3 sprint, F / Y flashlight. Touch devices get on-screen **RUN** (tap to toggle) and **LIGHT** buttons above the jump button. Shift-lock is disabled since Shift is sprint.
- Studio-only dev keys (server ignores them on live servers): **F6** take 40 damage, **F7** end the current phase timer, **F8** set battery to 5%.
- `Workspace.StreamingEnabled` set to false (small map, avoids parts not being loaded when teleporting or spectating). Ambient light returned to dark now that there is a flashlight.

### Checklist
- [x] Contextual interactions (ProximityPrompts, server-validated; blocked while downed)
- [x] Sprint and stamina (server-authoritative)
- [x] Flashlight with battery and limited charging stations
- [x] Player state management
- [x] Damage, downed-once, revive, solo self-recovery, death
- [x] Spectating for eliminated players
- [x] Basic mobile controls
- [x] Interaction validation (distance, phase, alive, not downed, rate limit)
- [ ] Crouch — deferred; not needed until the enemy can hear footsteps (Phase 3/4)
- [ ] Studio playtest (steps below)

### Offline results (actually run, 2026-10-23)
- `lune run tests/run`: 29 passed, 0 failed (adds stamina drain/regen/exhaustion and damage/downed/revive rules)
- `selene src`: 0 errors, 0 warnings · `stylua --check`: clean · `luau-lsp analyze` (strict): 0 errors · `rojo build`: OK

### Studio test script (Phase 2 acceptance)
1. **Sprint** — In a round, hold Shift while moving: faster, STAMINA bar drains. Standing still with Shift held doesn't drain. Run dry → can't sprint until the bar passes 25%.
2. **Flashlight** — F toggles the beam; LIGHT meter shows ON/OFF and drains only in a round. F8 → 5%, wait for "battery is dead". Use a charger (generator room, tower room) → full; the charger's prompt shows charges left and disables after 2.
3. **Damage (solo)** — F6 twice (protection blocks a second hit within 1.5 s; wait, then hit again) → health drops. Keep hitting until downed: red overlay, crawl speed, can't use prompts. After 10 s you stand up with 50 health. Go down again → eliminated, round ends.
4. **Revive (2 players)** — Clients and Servers, 2 players. Down player A with F6. Player B sees "Revive A"; A does not see their own prompt. B holds 4 s → A is up. Down A again and let 30 s pass → A bleeds out, spectate panel appears for A and follows B; `<` `>` and STOP work.
5. **Extraction while downed** — A downed player standing in the loading bay does not escape.
6. **Exploit checks** — In the client's command bar, fire `SprintRequest` with a non-boolean, or `FlashlightToggle` 50 times: no errors, server ignores/rate limits. `DevCommand` does nothing in a published game (check with a live test server if possible).
7. **Mobile** — Device emulator (phone): RUN and LIGHT buttons visible above the jump button and don't overlap it; RUN highlights when toggled on; meters fit at the bottom without covering the thumbstick.
8. **Regression** — Run the Phase 1 test list again.

## Phase 3 — The Echo AI `[x]` (awaiting Studio test)

### How it works
- **`Logic/EchoBrain.luau`** (pure, unit-tested) decides the next state each AI tick from a perception record: can it see a target, how far, how long since it last saw one, alert level, whether it heard something, whether its move arrived or failed, attack cooldown.
- **`Enemy/Echo.luau`** (server) gathers that perception and acts on the state. One AI thread per Echo, ticking every 0.2 s; destroying the Echo stops it. Tick errors are caught and logged; after 20 errors the AI stops rather than spamming.
- **`Enemy/EchoMover.luau`** follows PathfindingService paths. It re-paths at most every 0.5 s while chasing and every 2 s otherwise, re-paths when a path is blocked, and walks straight at the goal if pathing fails within 12 studs. If it makes no progress for 2 s it re-paths; after 3 stuck checks the move counts as failed. After 4 failed moves in a row, the Echo moves to a patrol point more than 40 studs from players that none of them can see. It never relocates near players.
- **`Enemy/EchoRig.luau`**: placeholder tall, thin, dark humanoid built from parts (about 10 studs tall, long arms, two pale eyes). No animations. Server-owned physics.
- **`EnemyService`** spawns one Echo at the `Z` lair (tower room) when players enter the station, and removes it when the round resets. Patrol points are every lit cell (`L`/`C`).
- **`NoiseService`**: server-only noise events. Sources (loudness 0..1): sprinting 0.6 every 0.5 s, failed calibration 1.0, fuse insert 0.8, revive 0.6, charging 0.5. Walking is silent. A sound is heard within 60 studs × loudness.

### States
| State | Behaviour | Leaves when |
|---|---|---|
| Dormant | Waits in its lair for 40 s after players enter | Grace period ends (F9 skips it) |
| Patrol | Walks between lit cells at 8 | Sees a player → Stalk (far) or Hunt (close / alert ≥ 60); hears a sound → Listen |
| Listen | Stops and turns toward the sound for 1.5 s | Sees a player, or time up → Investigate |
| Investigate | Walks to the sound at 11 | Sees a player; arrives, can't reach it, or 20 s → Search |
| Stalk | Follows to about 30 studs away and watches at 7 | Player closer than 18 or alert ≥ 60 → Hunt; out of sight 4 s → Search; 8 s → Retreat |
| Hunt | Chases the last place it saw the target at 16 solo / 17 team (players sprint at 19) | In range with cooldown ready → Attack; out of sight 4 s → Search; 20 s solo / 25 s team → Retreat |
| Attack | Stops, faces the target, eyes flare red, 0.7 s windup | Hit → Retreat; miss → Hunt |
| Search | Checks patrol points within 30 studs of the last sighting for 10 s | Sees → Hunt/Stalk; hears → Listen; time up → Recover |
| Retreat | Walks to the patrol point farthest from players at 14 | Arrives, fails, or 15 s → Recover |
| Recover | Pauses 3 s and forgets alert, target and sounds | → Patrol |

- **Sight:** 70 studs (91 if the player's flashlight is on), 110° field of view, raycast line of sight from its head to the player's head. It notices anyone within 6 studs regardless of facing. It never tracks through walls: the chase goal is the last place it actually saw you.
- **Attack fairness:** the hit only lands if, when the 0.7 s windup ends, the target is still within 7 studs, visible and not downed. Damage 55 (two hits down a healthy player). Cooldown 3.5 s solo / 2.5 s team. It retreats after every hit, giving the victim time to escape or be revived. **Downed players are not targeted.**
- **Readable cues (until audio in Phase 4):** eye colour — pale (patrol), warm (listen/investigate/stalk/search), red (hunt), bright red (attack windup).
- **Debugging:** in Studio, a label above the Echo shows its state and alert. Set `Config/Debug.Enabled` to true to log every state change and noise.

### Checklist
- [x] Enemy rig integration (placeholder)
- [x] State machine with all 10 states
- [x] Patrol and investigation
- [x] Sound event handling
- [x] Detection with field of view and line of sight
- [x] Pursuit and server-validated attack
- [x] Search and recovery
- [x] Navigation failure handling (failed paths, blocked paths, stuck detection, unseen relocation)
- [ ] Studio playtest (steps below)

### Offline results (actually run, 2026-10-23)
- `lune run tests/run`: 42 passed, 0 failed (adds 13 Echo decision tests: every state's exits, alert, field of view, hearing)
- `selene src`: 0 errors, 0 warnings · `stylua --check`: clean · `luau-lsp analyze` (strict): 0 errors · `rojo build`: OK

### Studio test script (Phase 3 acceptance)
1. **Spawn** — Start a solo round. The Echo stands in the tower room (top right) with a debug label reading `Dormant`. Output shows "Echo spawned (solo)". No errors.
2. **Patrol** — Press F9. The label changes to `Patrol` and it walks between rooms through doorways without grinding into walls.
3. **Hearing** — Out of its sight, sprint nearby: it switches to `Listen` (stops and turns), then `Investigate` (walks to where you were), then `Search`. Walking in the same place should not trigger it.
4. **Stalk and hunt** — Let it see you from far away: `Stalk` (keeps its distance, watches). Approach it or stay visible: `Hunt`, eyes red.
5. **Escape** — During a hunt, sprint and break line of sight around a corner. After about 4 s it goes to `Search`, then `Recover`, then `Patrol`.
6. **Attack** — Let it reach you. It stops with bright red eyes for 0.7 s; step away during the windup and the hit misses. Stand still and you take 55 damage, then it retreats. A second hit downs you; it does not attack you while downed.
7. **Failed calibration** — Submit a wrong frequency at the console: it hears it from across the station (`Listen` → `Investigate` toward the operations room).
8. **Unreachable goal** — Jump onto a crate while it hunts you. It should keep trying briefly, then give up (`Search`) rather than freeze in place. If it gets stuck repeatedly, Output shows "relocated out of sight".
9. **Round reset** — Finish or fail the round. The Echo is removed (Workspace.Enemies empty in the lobby), and a new one appears next round. Run three rounds; no duplicate Echoes, no errors.
10. **Two players** — It chases one; the other can revive the downed one. It ignores the downed player.
11. **Performance** — With the Echo hunting, check the server Script Performance / MicroProfiler: the AI should stay well under 1 ms per tick.

## Phase 4 — Horror and anomaly variants (not started)

## Known issues / limitations
- Dropped fuse returns to its original spot rather than where the carrier fell.
- The flashlight beam follows the head's facing, not the camera's up/down angle. A client-side aim for the owner's own beam is planned for the polish phase.
- Like any Roblox game, a cheater can raise their own WalkSpeed on their client. The server controls the intended speed; detecting speed hacks is out of scope for the MVP.
- On-screen RUN/LIGHT button positions are a best guess and need checking in the device emulator.
- Calibration UI has buttons only (no keyboard shortcuts yet).
- Escaped players are teleported straight to the lobby; no exit cutscene.
- All art is placeholder geometry; no sounds (no verified asset IDs chosen).
- The Echo has no animations: it glides upright. Its only state cue is eye colour until Phase 4 adds audio.
- The Echo's tuning (speeds, ranges, timings in `Config/Enemy.luau`) is a first guess and needs balancing in playtests.
- Players can stand on crates the Echo can't path onto. It gives up rather than getting stuck, but this may be exploitable; consider making furniture taller or adding a crate-climb later.

## Deferred features
- See master spec §21. Nothing beyond the MVP until Phase 9 passes.
