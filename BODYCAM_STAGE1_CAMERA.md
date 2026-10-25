# Bodycam Stage 1 — First-person camera

**Status (2026-10-25):** code written; offline checks pass (unit tests, StyLua, Selene, luau-lsp strict, `rojo build`). **Not yet tested in Roblox Studio.** Part of [BODYCAM_MIGRATION_PLAN.md](BODYCAM_MIGRATION_PLAN.md), Stage 1 (brief stage B).

## What changes

- **First person during a shift.** A living participant in an active round (Investigation, Decision, Transmission, Extraction) is locked in first person. Lobby, briefing, results and spectating keep the normal camera.
- **Field of view** setting, 70–90°, default 80. Widens by up to 4° while sprinting.
- **Walking sway.** Footstep bob under 0.1 stud and roll under 0.6°, slightly stronger when sprinting and weaker while downed, plus a slow idle drift. The **Camera motion** setting scales all of it, and 0% turns it off, including the sprint widening.
- **Mouse sensitivity** setting, 20–200%. It uses `UserInputService.MouseDeltaSensitivity`, so it affects the mouse only; gamepad and touch look speed stay in the Roblox menu.
- **Mouse cursor.** Locked in first person, and freed automatically while Calibration, Decision, Settings, Results, Lobby or the open notes panel are on screen. Hold **Left Alt** to free it for the NOTES and SETTINGS corner buttons.
- **Flashlight.** Your own beam now tilts up and down with the camera, **on your screen only**. Teammates still see the head-mounted beam (making that shared is Stage 2, which needs a new remote). The Echo only checks whether the light is on, so gameplay is unchanged.

Not changed: sprint, stamina, flashlight battery and toggling, interactions, damage, all remotes, all server code, the save format version.

## Files

| File | Studio location | Change |
|---|---|---|
| `src/client/Controllers/CameraController.luau` | StarterPlayer › StarterPlayerScripts › Client › Controllers › CameraController (ModuleScript) | **New.** The only camera controller |
| `src/shared/Logic/CameraMotion.luau` | ReplicatedStorage › Shared › Logic › CameraMotion | **New.** Pure rules: when to use first person, sway, field of view |
| `src/shared/Config/Camera.luau` | ReplicatedStorage › Shared › Config › Camera | **New.** All tuning numbers and the list of menus that need a cursor |
| `src/client/ClientBootstrap.client.luau` | …› Client › ClientBootstrap (LocalScript) | Starts CameraController (one line) |
| `src/client/Settings.luau` | …› Client › Settings | Adds MouseSensitivity, FieldOfView, CameraMotion |
| `src/shared/Logic/Profile.luau` | ReplicatedStorage › Shared › Logic › Profile | Same three keys, defaults and ranges, so the server saves them. Old saves load the defaults; no version bump |
| `src/client/Controllers/SettingsController.luau` | …› Controllers › SettingsController | New CAMERA section |
| `src/client/Controllers/NotebookController.luau` | …› Controllers › NotebookController | Names the notes panel `NotesPanel` (one line) |
| `src/client/Controllers/HowToPlayController.luau` | …› Controllers › HowToPlayController | Mentions Left Alt |
| `tests/camera_spec.luau`, `tests/profile_spec.luau`, `tests/run.luau` | — (Lune only) | New tests |

No new RemoteEvents, attributes, tags or Studio objects. The controller creates its own `CameraCursor` ScreenGui (one invisible 1×1 `Modal` button) at runtime. It reads the server's existing `Sprinting` and `Downed` player attributes for presentation only.

## Installation

1. Pull the branch: `git switch stage-b/bodycam-camera`.
2. With Rojo: run `rojo serve` and connect the Studio plugin. Or build a place with `rojo build -o build/LastShift.rbxl` and open it.
3. Nothing to place by hand.

## Acceptance tests (Studio)

Run with **Play** (solo), then **Test › Clients and Servers** with 2 players.

1. **Lobby:** normal third-person camera, mouse free, scroll-zoom works.
2. **Briefing:** still the normal camera.
3. **Shift starts (Investigation):** camera locks in first person, body hidden, field of view visibly wider. Mouse look works.
4. **Walk / sprint / stop:** gentle bob when walking, a little stronger when sprinting with a slight field-of-view widening; it settles within about half a second of stopping. No drift or slow rotation while standing still for 30 s.
5. **Settings › Camera motion OFF:** no bob, no idle drift, no sprint widening. Field of view and sensitivity changes apply at once and **persist after rejoining** (live servers only; Studio shows "test data: not saved").
6. **Mouse sensitivity 20% and 200%:** look speed clearly changes.
7. **Cursor:** fix the radio (Calibration) and the cursor appears and works; it locks again on close. Press J: the notes panel opens with a cursor. Hold Left Alt: the cursor appears and NOTES/SETTINGS can be clicked. Esc menu still works.
8. **Flashlight (F):** the beam points where you look, including up and down. In the 2-player test, the other player sees your beam as before (level).
9. **Downed** (press the F6 dev key three times, 2 s apart): camera stays first person, sway weaker. Revive or solo recovery works as before.
10. **Death and spectate:** on elimination the camera leaves first person and spectate follows teammates; STOP returns to your own character.
11. **Respawn and next round:** after Results, the lobby camera is third person again (zoomed out, not stuck at the head). Start a second round: first person, sway and flashlight aiming all work on the new character.
12. **Touch (device emulator) and gamepad:** look and movement still work; RUN/LIGHT buttons still work.
13. **Performance:** MicroProfiler shows no new spikes; the two render steps are tiny.

Regression: re-run the Phase 2 (sprint, flashlight, downed/revive, spectate) and Phase 7 (settings) Studio scripts in [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md).

## Possible regressions to watch

- **Cursor stuck locked** on a screen not in `CursorScreens`: add its ScreenGui name to `Config/Camera.luau`. Left Alt is the fallback.
- **Camera drifting or rolling over time** means the default camera reads the sway offset. The controller removes it before each camera update; report it if seen.
- **Third-person zoom stuck close** after leaving first person: raise `ExitZoomDistance` or the 0.25 s delay in `deactivate`.
- **Motion sickness:** defaults are deliberately small; lower `Motion` values in `Config/Camera.luau` or set Camera motion to OFF.
- Your local beam and what teammates see now differ in pitch until Stage 2.

## Rollback

- Quick: remove the `require(Controllers.CameraController)` line from `ClientBootstrap.client.luau`. Everything else is inert without it, and saved settings are harmless.
- To flip only the flashlight aiming off: set `AimFlashlight = false` in `Config/Camera.luau`.
- Full: don't merge the branch (or revert its commit). Saved profiles that contain the three new keys still load on the old code, because unknown settings are ignored.
