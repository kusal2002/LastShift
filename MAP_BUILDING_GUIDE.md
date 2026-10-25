# Map Building Guide (route B: hand-built in Studio)

How to build the station in Roblox Studio so the game's systems find everything. The visuals are entirely up to you. The game only cares about **tagged parts** and a few **attributes**.

If anything required is missing, the server says so in **Output** at start-up and falls back to the generated graybox, so a half-built map never breaks a playtest.

---

## 1. Workflow

1. **Get assets** (see [ASSET_CATALOG.md](ASSET_CATALOG.md)):
   - Toolbox → Get Model → insert → delete what you don't need.
   - Right-click the pieces you keep → **Save to File** → `assets/raw/<Kit>/<Name>.rbxm`.
2. **Audit them** (from the project folder):
   ```bash
   lune run tools/asset_audit
   ```
   - Clean models are written to `assets/props/<Kit>/<Name>.rbxm` with scripts removed and parts anchored.
   - **Rejected** models (backdoor patterns) are not written. Delete them and log them as Rejected in the catalog.
   - The full report is `build/asset_audit_report.md`.
3. **Use them:** cleaned props appear in Studio under **ServerStorage → Props** (synced by Rojo). Copy them into your map.
4. **Build the map** as a Model named **`Station`** in Workspace, in a place connected to Rojo (`rojo serve`) or a separate work place.
5. **Save the map into the repo:** right-click `Station` → **Save to File** → `assets/maps/Station.rbxm`. Optionally do the same with a `Lobby` model → `assets/maps/Lobby.rbxm`.
   - Rojo is one-way (files → Studio). Edits made in Studio are only kept by saving the model to file again.
   - Before saving, **delete the `Station` model from Workspace in your work place** (or work in a separate place). If a `Station` is already in Workspace when the game starts, that copy is used instead of the file.
6. **Test:** play in Studio.
   - Output shows `Loaded hand-built Station from assets/maps`, then `Hand-built station: 0 error(s), N warning(s)`.
   - About 3 seconds later the navigation check runs (`Config/Debug.ValidateNavigationOnStart`). Press **F11** to run the whole check again at any time.

---

## 2. Tag contract

Add tags with Studio's **Tag Editor** (View → Tag Editor) or the Properties panel → Tags. **Tag the Part itself, never a Model.** Every tagged part must be **Anchored**. Counts below are minimum → recommended.

| Tag | Count | What to tag | Notes |
|---|---|---|---|
| `RoomVolume` | 1 → 6+ | An invisible box covering each room, floor to ceiling | Attribute **`RoomName`** (string). Use exactly the names players should see in the HUD and on signs: `Reception`, `Broadcast Studio`, `Comms Room`, `Generator Room`, `Storage`, `Security Office`, `Maintenance Corridors`, `Transmission Room`, `Parking Area`. Transparency 1, CanCollide off, CanQuery off. Volumes shouldn't overlap |
| `StationSpawn` | 1 → 4 | Invisible marker parts where players appear at round start | About 3 studs above the floor, clear space around |
| `FuseSpawn` | 1 → 3 | Invisible marker where the fuse can appear | The fuse spawns centred on the marker: put it on a shelf or workbench surface |
| `FusePanel` | 1 | The fuse box's front panel part | The game recolours this part (red = broken, amber = fixed), so tag a visible panel or door part. The prompt appears at the part's centre |
| `RadioConsole` | 1 | The broadcast desk's main part | Calibration and the transmitter use this part's prompt. It turns green when the signal locks |
| `FrequencyBoard` | 1 | A flat part (CRT screen, whiteboard) | The target frequency is drawn on its **Front** face (a SurfaceGui is added automatically). Make sure Front faces the room |
| `EvidenceSpawn` | 3 → 4+ | Invisible markers on desks, shelves, tables | Evidence appears centred on the marker. Spread them over different rooms |
| `RiskyEvidenceSpawn` | 0 → 1 | Invisible marker in the most dangerous room (basement) | Optional high-value evidence |
| `ExtractionZone` | 1 | Invisible box around the van / exit area | Players stand inside it to escape. CanCollide off |
| `ExitDoor` | 0 → 1 | The door part(s) between the station and the exit area | Becomes non-colliding and see-through at extraction |
| `EchoSpawn` | 1 | Floor-level marker in the Echo's lair | The Echo appears standing on this point |
| `EchoPatrol` | 6 → 10+ | Floor-level markers along corridors and in rooms | The Echo walks between these. Put them on open floor, at least one per room, never inside furniture |
| `StationLight` | 1 → 8+ | Each ceiling lamp part that contains a PointLight / SpotLight / SurfaceLight | Blackouts turn these off. Attribute `Room` is filled in automatically from the room volumes |
| `ChargingStation` | 0 → 2 | Charger part on a wall | Prompt at the part's centre |
| `PowerSwitch` | 0 → 1 | Generator pull-start / lever part | Ends blackouts early |
| `DecoySpawn` | 0 → 2+ | Invisible markers on shelves | Noise makers appear here |

**Lobby** (optional `Lobby` model): one `SpawnLocation` tagged `LobbySpawn`. The lobby must not be connected to the station by walkable ground.

---

## 3. Space and navigation rules

The Echo is about 10 studs tall, has a 2-stud radius, and can't jump or climb.
- Doorways and corridors on Echo routes: **at least 6 studs wide and 11 studs tall** (clear of frames and pipes).
- Stairs: low, regular steps, or a ramp. The navigation check reports any patrol point the Echo can't reach.
- Small clutter (papers, cups, cables): **CanCollide off**, so nothing snags the Echo or players.
- Big furniture keeps collision; leave walking space around it.
- Every main room should have two ways in or out where possible (chases need escape routes).

---

## 4. Performance checklist
- Anchor everything static (the audit does this for imported props).
- Complex meshes: `CollisionFidelity = Box` or `Hull`.
- Small props: `CastShadow` off.
- Keep under about 40 lights in the station, with shadows on about 10 at most.
- Budgets are in ASSET_INTEGRATION_PLAN.md section 7.

---

## 5. Reading validator output

| Output line | Meaning | Fix |
|---|---|---|
| `ERROR: FusePanel: found 0, need at least 1` | A required object is missing | Add and tag it |
| `ERROR: ... is tagged but is not a part` | A Model was tagged | Move the tag to a part inside it |
| `ERROR: two RoomVolumes are both named "Storage"` | Duplicate room names | Rename one, or merge the boxes into one name per room |
| `warning: ... is not inside any RoomVolume` | A marker sits outside every room box | Grow the room box or move the marker |
| `ERROR: Echo can't reach patrol point ...` | Navigation is blocked | Widen the doorway, remove collision from clutter, or move the marker |
| `ERROR: players can't reach ...` | An objective can't be reached | Same as above; check for blocked doors |
| `using the generated graybox instead` | The hand-built map had errors | Fix the errors listed above it |

---

## 6. Imported models on gameplay objects

Spawned objects (fuse, evidence, noise maker) are dressed automatically when matching models exist. The names are in `src/shared/Config/Props.luau`:

| Object | Expected file |
|---|---|
| Fuse | `assets/props/Mission/Fuse.rbxm` |
| Noise maker | `assets/props/Mission/NoiseMaker.rbxm` |
| Evidence: Recording | `assets/props/Mission/CassetteTape.rbxm` |
| Evidence: Document | `assets/props/Mission/Folder.rbxm` |
| Evidence: Reading | `assets/props/Mission/Printout.rbxm` |
| Evidence: Visual | `assets/props/Mission/Photograph.rbxm` |

Set each model's **pivot at its visual centre** before saving. Size them for real life: a fuse is about 0.6 studs long, a cassette tape about 0.8 studs wide. Until a file exists, the current placeholder shape is used.
