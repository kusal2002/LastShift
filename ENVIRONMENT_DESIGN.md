# Environment Design — LAST SHIFT: Signal Lost

How each location should look, play and sound. Visual work follows this document; gameplay hooks (tags) are in ASSET_INTEGRATION_PLAN.md section 3.

---

## Visual rules (all chapters)

- **Palette:** desaturated blue-grey shadows, dirty concrete, faded industrial paint, warm amber equipment lights, muted green CRT screens, red emergency lighting used sparingly.
- **Readable darkness:** every room has at least one light source or a lit doorway. No room is pitch black unless a blackout event caused it. Objective objects always carry a small light or emissive detail.
- **Purpose first:** every prop answers "why is this here?". Clutter sits where people worked: desks, benches, the floor near broken equipment. Never scattered randomly.
- **Recognisable interactables:** interactive objects have a distinct silhouette and a small light (amber = actionable, green = done, red = locked).
- **Story through objects:** half-finished work, a chair knocked over facing the door, logs that stop mid-sentence, photographs with faces scratched out.
- **Accessibility:** the existing settings (reduced flashes, subtitles, text size) apply to all environments. Avoid colour-only signals.

---

## Chapter 1 — The Signal: Remote Radio Station (current game, to be upgraded)

### Story beat
A small relay station in a pine forest, staffed by three technicians until a week ago. The last log entries describe voices on the transmitter and lights failing room by room. The team (players) arrives by van at night.

### Room plan
The current grid rooms map onto the new layout. Room names must match the HUD exactly; where a name changes, the code's room list and the signs change with it.

| New room | Replaces (current) | Purpose and gameplay | Key props | Interactables / tags | Lighting | Sound |
|---|---|---|---|---|---|---|
| **Parking Area** (exterior) | Loading Bay | Arrival and **extraction**: reach the van | Team van, chain-link fence, gate, power pole, utility box, floodlight, gravel, forest edge | `ExtractionZone` around the van; `StationSpawn`s near the van | One sodium floodlight, van headlights | Wind, distant owl, generator hum through walls |
| **Reception** | Entrance Hall | Safe-feeling start; orientation | Front desk, visitor log, notice board, faded posters, waiting chairs, wall clock stopped at 3:12 | Visitor log terminal (story); room sign | Flickering fluorescent tube, exit sign glow | Buzzing light, clock not ticking |
| **Broadcast Studio** | Operations | Heart of the station: **calibration and transmitter** | Broadcast desk, transmitter rack, mixing console, mic on arm, headphones, ON AIR light, acoustic panels, window into Comms | `RadioConsole` (desk), `FrequencyBoard` moved to Comms | Warm amber desk lamps, ON AIR red | Static bursts, faint voices in headphones |
| **Comms Room** | (new; part of Operations/Maintenance) | Where the target frequency is found | Server racks, CRT monitors, desk with PC, cable trays, frequency chart | `FrequencyBoard` (CRT showing target), station log terminal | Cold monitor glow, rack LEDs | Fans, hard-drive clicks |
| **Generator Room** | Generator Room | **Fuse objective** and **backup power** | Diesel generator, breaker panel wall, conduit, pipes, warning signs, oil drums, tool cart | `FusePanel` (fuse box), `PowerSwitch` (generator pull-start), `ChargingStation` | Red emergency light, sparks during events | Generator chug, electrical buzz |
| **Storage** | Storage | Fuse spares, noise makers | Metal shelving, crates, spare parts bins, mop bucket | `FuseSpawn`, `DecoySpawn`, `EvidenceSpawn` | One bare bulb | Dripping pipe |
| **Security Office** | (new; part of Maintenance) | Evidence and cameras | Desk with monitors (camera images), lockers, key board, evidence boxes | `EvidenceSpawn`, monitors flicker during events | Monitor glow | Static from monitors |
| **Maintenance Corridors** | Corridor | Connective loop; Echo patrol; sightlines | Pipes along the ceiling, cable runs, fire extinguishers, door plaques, a vent | `EchoPatrol`, `DecoySpawn` | Sparse cold fluorescents, some dead | Ventilation, distant footsteps (events) |
| **Transmission Room** (basement, restricted) | Tower Access | **Echo lair**, **risky evidence**, high tension | Tower base equipment, cable bundles disappearing into the floor, scorched desk, chalk marks, a chair facing the wall | `EchoSpawn`, `RiskyEvidenceSpawn`, `ChargingStation`; power-locked door (backlog) | Almost dark, one red light, strong silhouettes | Low drone, the Echo's clicking |

### Player route and pacing
1. Van (spawn) → gate → **Reception** (safe, learn controls).
2. Corridor loop opens up: Storage (fuse), Generator (panel), Comms (frequency), Broadcast Studio (tune).
3. Evidence is spread across Security, Storage and the offices; the risky item pulls brave players into the basement.
4. Decision at the Broadcast Studio → transmit (hold the studio) or abort → back through Reception to the van.

### Sightlines and counterplay
- Long corridor sightlines let the Echo *stalk* visibly at a distance (readable threat).
- Every main room has **two exits** where possible, so chases have escape options.
- The corridor loop lets players break line of sight by circling.
- No dead-end room without a hiding or escape option except the basement (it's meant to be risky).

### Navigation constraints (Echo)
Clear doorways ≥ 6 studs wide and ≥ 11 studs tall on all Echo routes. Basement stairs must be shallow or a ramp. See ASSET_INTEGRATION_PLAN.md section 8.

### Rough layout sketch (top view, not to scale)
```
                 forest
   ┌────────────────────────────────────────┐
   │  STORAGE  │  BROADCAST  │  COMMS │ SEC  │
   │           │   STUDIO    │        │ OFF. │
   ├────┬──────┴─────┬───────┴────┬───┴──────┤
   │    │  MAINTENANCE CORRIDOR (loop)  │ ▼ stairs
   ├────┴────┬──────┴──────┬──────────┴──────┤ to TRANSMISSION
   │GENERATOR│  RECEPTION  │  (offices)      │ ROOM (basement)
   └─────────┴────┬─┬──────┴─────────────────┘
                  │ │ front door
          PARKING AREA + van (extraction)
                 forest
```

---

## Chapter 2 — Below Zero: Underground Research Facility (not started)

- **Identity:** clean sci-fi turned cold and abandoned. White panels, frost, failing strip lights, observation glass.
- **Rooms:** security checkpoint, labs, examination rooms, server room and control centre, generator and maintenance, containment wing, emergency exits and service tunnels.
- **Asset base:** Space Station Architecture and Interior Prop packs (official Roblox), recoloured and frosted.
- **Signature mechanic idea:** sealed doors that need power routing; cold zones that drain stamina.

## Chapter 3 — The Hollow Woods (not started)

- **Identity:** night forest, fog in clearings, flashlight-lit paths, abandoned cabins and research outposts, a communication tower.
- **Asset base:** Forest Pack (trees, rocks, logs), City Props Pack (power poles), House Furniture/Props packs (cabin interiors).
- **Design focus:** varied sightlines (dense brush vs open clearings), landmarks for navigation, streaming enabled.

## Chapter 4 — The Other Frequency (not started)

- **Identity:** the station "as the signal sees it": familiar rooms rearranged, impossible corridors, colour-shifted lighting, controlled spatial tricks (looping hallway, rooms bigger inside).
- **Rule:** stay readable. Strong landmarks, consistent interaction language, effects that respect reduced-flash settings.
