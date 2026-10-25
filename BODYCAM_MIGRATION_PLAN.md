# Bodycam FPS Migration Plan — LastShift

**Status (2026-10-25):** initial audit only. No code has been changed for this migration, and nothing has been tested in Roblox Studio. Design decisions in section 7 are open.

**Re-checked 2026-10-25** against this branch (based on `main`, without PR #8): `lune run tests/run` 89 passed / 0 failed; StyLua, Selene, luau-lsp strict analysis and `rojo build` all clean. Counts below corrected to match the files.

Goal: turn LastShift into a cinematic, bodycam-inspired survival horror FPS for solo and co-op play, with both human and creature enemies, **without rewriting the game**. Working systems are kept or extended. Nothing is replaced without a stated reason.

Related: [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md) (phases 1–7), [ASSET_INTEGRATION_PLAN.md](ASSET_INTEGRATION_PLAN.md) and [ASSET_CATALOG.md](ASSET_CATALOG.md) (visual upgrade, on the `assets/audit-plan` branch, PR #8).

---

## Summary

- The game is a good base: modular services, every gameplay decision made on the server, all client requests going through one rate-limited remote wrapper, and 89 unit tests (PR #8 adds two more spec files). About 90% of it can be kept.
- The FPS parts don't exist yet:
  - Camera: the default Roblox third-person camera.
  - Inventory, weapons and human enemies: none.
  - The only enemy, the Echo, is invulnerable by design.
- **Phases 1–7 have never been tested in Studio.** Converting to an FPS on top of untested systems would mix old bugs with new ones, so the plan starts with a baseline playtest (Stage 0).
- **Combat changes the original design.** The game was built as non-combat "fair horror". Guns and human enemies need explicit design decisions (section 7) before Stage 4.

---

## 1. Project structure

A Rojo project (`default.project.json`), about 10.4k lines of strict-typed Luau in `src/`, all in the repo. Tools are pinned by Rokit: Rojo, Selene, StyLua, Lune, luau-lsp.

| Folder | Contents |
|---|---|
| `src/server/Services` (18 services; 19 with PR #8's PropService) | Round flow, objectives, player state, enemy, director, saving, rewards, map, interactions, remotes |
| `src/server/Enemy` | The Echo: AI object, pathfinding mover, placeholder rig |
| `src/server/Objectives`, `Map`, `Data` | Fuse / calibration / evidence objectives; station layout; save store |
| `src/shared/Config` (14 files; 16 with PR #8) | All tuning: player, enemy, anomalies, audio, economy, cosmetics, director, etc. |
| `src/shared/Logic` (13 modules; 14 with PR #8) | Pure, unit-tested rules: round phases, damage, stamina, Echo decisions, rewards, profile, director pacing |
| `src/client` | 17 UI/input controllers, state stores, settings, theme |
| `tests/` | Lune unit tests (`lune run tests/run`) |

- **Camera:** none. Players get the default third-person camera. The only camera code is the spectate subject switch, subtitle distance hints and UI scaling.
- **Character:** the default R15 avatar. The server sets walk speed, jump height and health. Shift-lock is disabled.
- **Remotes** (22, all created by the server from `src/shared/Remotes.luau`): RoundSnapshot, Notify, Results, CalibrationOpen/Close, AudioCue, ProfileUpdate, DecisionOpen/Close, LightFlicker, SnapshotRequest, PlayRequest, CalibrationSubmit/Cancel, SprintRequest, FlashlightToggle, DecoyUse, EquipCosmetic, BuyCosmetic, SaveSetting, DecisionSubmit, DevCommand (Studio only).

---

## 2. Dependency map

```
CLIENT  Controllers ──▶ State (round snapshot) / ProfileState / Settings
           │ intents only: PlayRequest, SprintRequest, FlashlightToggle, DecoyUse,
           │ CalibrationSubmit, DecisionSubmit, Equip/BuyCosmetic, SaveSetting
           ▼
        RemoteService (single OnServerEvent wrapper; rate limits every remote)
           ▼
SERVER  RoundService (the only owner of round phases)
          ├─ ObjectiveService ─▶ Fuse / Calibration / Evidence ─▶ Map, Interaction, Noise, Props
          ├─ PlayerStateService (stamina, flashlight, health, downed/revive) ─▶ Interaction, Noise
          ├─ EnemyService ─▶ Echo ─▶ EchoBrain (pure), EchoMover, EchoRig; Lighting, AudioEvent
          ├─ DirectorService ─▶ Lighting, AudioEvent, Enemy, Props;  DecoyService, ChargingService
          ├─ DecisionService, ExtractionService
          └─ RewardService ─▶ ProfileService ─▶ ProfileStore (DataStore, or mock in Studio)
        MapService ─▶ StationLayout or a hand-built map, room volumes, validator (PR #8)
        NoiseService ◀─ sprinting, failed repairs, revive, noise makers, power switch (Echo listens)
SHARED  Config/* · Logic/* (pure) · Types · Remotes · Util (Log, Maid, RateLimiter, Signal)
```

"Props", room volumes and the map validator come from PR #8 and are not on `main` yet.

---

## 3. System classification

| System | Where | Verdict | Reason |
|---|---|---|---|
| Round flow and phases | `RoundService`, `Logic/RoundTransitions` | **KEEP** | Works unchanged in an FPS |
| Remotes and rate limiting | `RemoteService` | **KEEP** | New weapon remotes plug into the same wrapper |
| Objectives, decision, extraction | `ObjectiveService`, `DecisionService`, `ExtractionService` | **KEEP** | Genre-neutral |
| Interactions | `InteractionService` (ProximityPrompts) | **KEEP** | Prompts work in first person |
| Noise system | `NoiseService` | **KEEP** | Gunshots become very loud noise events: a natural fit |
| Director, anomalies, audio cues, lighting | `DirectorService`, `Config/Anomalies`, `AudioEventService`, `LightingService` | **KEEP** | |
| Saving, rewards, cosmetics | `ProfileService`, `RewardService`, `Logic/Profile` | **KEEP** | The save-format upgrade path exists for new settings |
| Map tooling | `MapService`; room volumes, validator and asset audit (PR #8) | **KEEP** | Add human-enemy navigation checks later |
| Player survival state | `PlayerStateService`, `Logic/Damage`, `Logic/Stamina` | **EXTEND** | Add aiming slowdown, crouch, damage types (bullet vs creature) and friendly-fire rules |
| Flashlight | Server SpotLight on the head | **EXTEND** | It doesn't follow camera pitch (a known issue). Bodycam needs a chest-mounted light that tracks aim |
| Enemy system | `EnemyService`, `Echo` | **EXTEND** | Support several enemy types. Move shared perception and pathfinding out of `Echo`; keep `EchoBrain` unchanged |
| HUD, spectate, settings | `HUDController`, `SpectateController`, `Settings` | **EXTEND** | Bodycam overlay, ammo display, teammates' "bodycam feeds" when spectating, field-of-view and motion-sickness options |
| Fuse carrying, noise-maker attribute | `FuseObjective`, `DecoyService` | **REPLACE (later)** | These are one-off "items". Once a real inventory exists they should move into it rather than run alongside it, to avoid two competing item systems |
| Camera | Default Roblox camera | **REPLACE (new controller)** | A first-person bodycam controller, client only |
| Inventory, weapons, human enemies | None | **NEW** | |
| Lighting engine | Voxel | **INVESTIGATE** | "Future" lighting gives realistic flashlight shadows but costs more on mobile |
| Touch controls for an FPS | `InputController` | **INVESTIGATE** | Aiming and shooting on phones is a separate design problem |
| Echo vs guns | `Config/Enemy`, `EchoRig` | **INVESTIGATE** | Currently invulnerable; needs a design decision |

### Systems to preserve as they are
Round phases; the remote wrapper and rate limiting; interactions; objectives; the decision and extraction flow; the noise system; director and anomalies; saving and rewards; map tooling; all existing unit tests; and the rule that **clients only send intents** and the server decides outcomes.

---

## 4. Risks

### Security
- Weapons are the largest exploit surface. **Hits must be decided on the server:**
  - fire rate, ammo, range;
  - line of sight from the shooter's head;
  - a live, valid target.
- The client may request a shot and draw tracers. It never decides damage.
- Never add a remote that says "damage this NPC" or "give me ammo".
- New remotes go through `RemoteService.listen` with type checks and rate limits, like all existing ones.

### Networking
- Shooting with latency: the server checks the client's aim direction against a tolerance, rather than doing full lag compensation. This is a deliberate simplification that should be documented as such.
- Tracers, muzzle flash, recoil and camera effects run on the client only. NPCs stay owned by the server.
- Aim direction for the flashlight is sent a few times a second, not every frame.

### Performance
- The Echo runs a 0.2 s thinking loop with pathfinding. Several human enemies doing the same need a budget: about 4 NPCs maximum, with staggered ticks.
- First-person arms and weapon models exist only on the owning client.
- Real-time shadows on every flashlight plus "Future" lighting will hurt phones. This needs measuring at graphics quality 1–3.

### Assets and licensing
- Needed: weapon models, first-person arms, gunshot and reload sounds, enemy models.
- **Animations only play if they are owned by the game's owner (the user's account or group).** Free-model animations from other creators won't load; they must be created or re-uploaded by the owner.
- Every asset goes through the asset audit (PR #8) and is recorded in ASSET_CATALOG.md. Nothing with unknown licensing or unreviewed scripts is added.

### Content rating
Realistic guns and shooting human enemies change the game's Roblox maturity rating (set through the questionnaire). Decide the intended rating before choosing weapon and enemy designs.

---

## 5. Proposed changes

1. **First-person bodycam camera** (one new client controller): locked first person, wide field of view, chest-height framing, head bob and sway. All are adjustable or can be turned off in settings. No gameplay change.
2. **Bodycam presentation:**
   - REC and timestamp overlay, vignette and grain. Grain needs a texture asset or a UI-gradient approximation.
   - A chest-mounted flashlight that tracks the player's aim: the client sends its aim direction (rate-limited) and the server moves the light so teammates see it.
3. **Inventory** (server-owned, slot-based). The fuse and noise maker move into it. No second item system.
4. **Weapons:** server-decided hitscan, ammo, reloads; very loud noise when fired; first-person arms (asset-dependent).
5. **Enemy framework:** split reusable perception and pathfinding out of the Echo. **The Echo's behaviour must stay identical.**
6. **Human enemies:** a new decision module (patrol, investigate, engage with a visible aiming warning before firing, retreat), killable, capped per round, spawned by the director.
7. **Creature rules, balance and polish:** how the Echo reacts to gunfire, mobile controls, performance, and a full security review.

---

## 6. Staged plan and acceptance tests

Every stage must keep all existing unit tests passing and re-run the relevant Studio test scripts from DEVELOPMENT_PLAN.md (regression).

| Stage | Work | Acceptance tests |
|---|---|---|
| **0. Baseline** | Merge or settle PR #8; run the Phase 1–7 Studio test scripts | A solo round runs end to end in Studio; Echo chase, revive, both endings and saving work. Bugs are logged and fixed **before** Stage 1 |
| **1. Camera** | First-person bodycam controller; field-of-view, head-bob and motion settings (save format v3) | Camera locked in first person during a round; lobby still usable; settings persist across rejoin; head bob off removes all sway; spectate still works; no gameplay remote changes (unit test on the remotes list) |
| **2. Presentation** | Bodycam overlay; chest flashlight that follows aim | The beam follows where you look; teammates see your beam move; aim updates are rate-limited (spam test); reduced-flashes setting respected; mobile frame rate measured at quality 1 |
| **3. Inventory** | Server inventory; fuse and noise maker migrated | Fuse and noise-maker gameplay unchanged (Phase 1 and 4 tests); a client can't add items (command-bar exploit test); items cleared on death and round reset |
| **4. Weapons** | Hitscan, ammo, reloads, noise, first-person arms | Server rejects shots that are too fast, without ammo, out of range, through walls, or at dead targets (command-bar tests); new unit tests for hit validation; gunfire triggers Echo investigation; friendly fire follows config |
| **5. Enemy framework** | Shared perception and mover modules | **Echo behaviour unchanged:** all Echo decision unit tests and the Phase 3 Studio script pass; the map validator's navigation check still passes |
| **6. Human enemies** | New decision module, health, director spawning | A visible windup before every shot; they can be killed; they never shoot through walls; capped count; a solo player can survive an encounter; NPCs cleaned up on reset (3 rounds back to back) |
| **7. Balance and polish** | Creature vs gunfire rules, mobile controls, performance, security review | 4-player test; server frame time under budget with all enemies active; full exploit pass on every remote |

---

## 6b. Mapping to the requested A–I stages

The A–I order from the project brief was reordered to match what the code already has:

| Brief stage | Plan stage | Why moved |
|---|---|---|
| A. Audit and backup | Stage 0 | Backup exists: git, every phase on its own branch and PR. Missing piece is the Studio baseline playtest |
| B. Camera, movement, flashlight | Stages 1–2 | Unchanged. Split in two so the camera (client only) lands before the flashlight change (needs a new remote) |
| C. Environment, materials, lighting | PR #8 (in parallel) | Already planned and partly built on `assets/audit-plan`; touches no gameplay code, so it can run alongside |
| G. Inventory (part) | Stage 3 | Pulled **before** weapons: weapons need slots, and fuse/noise maker must move in first to avoid two item systems |
| D. Weapons and combat | Stage 4 | Blocked on combat design decisions (section 7) |
| F. Creature AI (refactor) | Stage 5 | The creature (Echo) already exists with hunt/search/attack. The shared enemy framework is split out before adding a second enemy type |
| E. Human enemy AI | Stage 6 | Built on the Stage 5 framework |
| G. Objectives and escape | — | Already exist (fuse, calibration, evidence, extraction). KEEP |
| H. Co-op and shared state | — | Already server-owned for 1–4 players, with solo-mode downed rules. Squad-size scaling added per enemy in Stages 5–6 |
| I. Audio, animation, horror, optimization | Stage 7 | Audio cues and the director already exist; this stage is balance and performance |

## 7. Missing information and open decisions

1. **Studio test results for Phases 1–7.** None exist yet (Stage 0).
2. **PR #8** (asset pipeline): merge it, or keep the asset work separate?
3. **Combat design:**
   - Are players armed from the start, or do they find weapons?
   - Which weapon types, and how scarce is ammo?
   - Can the Echo be killed, stunned, or only driven off?
4. **Human enemies:** who are they in the story (another crew, soldiers, a cult)? This affects models and the maturity rating.
5. **Target maturity rating** on Roblox.
6. **Mobile priority:** full FPS on touch, or PC/console first?
7. **Assets:** sources for weapon models, first-person arms and gunshot sounds, and who will create or upload the animations (they must be owned by the user's account or group).
8. **Studio-only content** not in the repo (for example a hand-built station in progress). Only the repo has been audited.

---

## Constraints for this migration (agreed)
- No rewrite from scratch. No replacing a working system without explaining why.
- No duplicate controllers, event handlers or competing state managers.
- Gameplay decisions on the server; camera and visual effects on the client.
- No assets with unknown licensing or unreviewed scripts.
- Nothing is called tested unless it was actually run in Roblox Studio.
