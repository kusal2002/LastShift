# Asset Catalog — LAST SHIFT: Signal Lost

Every external asset considered for the game is listed here: what it is, where it comes from, how far it has been checked, and where it's used. **Never add an asset ID that wasn't checked on the Creator Store.**

**Nothing has been imported yet.** "Listing verified" means the store page was checked on the date given. It does *not* mean the asset is in the project.

### Status legend
| Status | Meaning |
|---|---|
| Candidate | Found in search; store page not yet checked |
| Listing verified | Store page checked: free, creator, counts recorded |
| Imported | Saved into `assets/raw/` from Studio |
| Audited | Passed `tools/asset_audit.luau`; cleaned copy in `assets/props/` |
| In use | Placed in the game |
| Rejected | Failed a safety, licence, quality or performance rule (reason given) |

---

## 1. Official Roblox packs (listing verified 2026-10-24)

All are by **@Roblox**, free ("Get Model"), and the most trustworthy source on the store. Packs that contain scripts (interactive showcase pieces) will have them **stripped** during the audit; we only take geometry and materials.

| Asset | ID / URL | Created | Triangles (whole pack) | Scripts | Audio | Intended use | Status |
|---|---|---|---|---|---|---|---|
| Modular Building Kit – Modern City | [13168370735](https://create.roblox.com/store/asset/13168370735) | Apr 2023 | 796,055 | 8 | 4 | Walls, upper walls, cornices, windows, doors: station shell and exterior | Listing verified |
| Modern City Materials Pack | [13168345645](https://create.roblox.com/store/asset/13168345645) | not checked | not checked | not checked | not checked | MaterialVariants for concrete, tile, metal | Candidate |
| House Props Pack – Duvall Drive | [10840642581](https://create.roblox.com/store/asset/10840642581) | Sep 2022 | 243,941 | 1 | 2 | **Old radios**, VHS tapes, papers, phones, books: evidence and desk clutter | Listing verified |
| House Furniture Pack – Duvall Drive | [10847897579](https://create.roblox.com/store/asset/10847897579) | Sep 2022 | 345,162 | 101 | 66 | Chairs, tables, cabinets, drawers, lamps, doors/windows with frames: offices and cabins | Listing verified (heavy scripting: strip everything) |
| Landscaping Pack – Duvall Drive | [10840661513](https://create.roblox.com/store/asset/10840661513) | Sep 2022 | 912,716 | 4 | 2 | Stonework, planters, garden equipment: exterior details (use sparingly; heavy) | Listing verified |
| Space Station Interior Prop Pack – Beyond the Dark | [10981024261](https://create.roblox.com/store/asset/10981024261) | Sep 2022 | 421,490 | 47 | 2 | Consoles, crates, pipes, signage: industrial details now; **Below Zero** research facility later | Listing verified |
| Space Station Architecture Pack – Beyond the Dark | [10980780693](https://create.roblox.com/store/asset/10980780693) | Sep 2022 | 894,348 | 58 | 7 | Catwalks, columns, doors, railings, stairs, walls, windows: **Below Zero** | Listing verified |
| City Props Pack | [6370681139](https://create.roblox.com/store/asset/6370681139) | Feb 2021 | 66,318 | 2 | 0 | Telephone pole, power pylon, street light, AC unit, bins, railings: parking area and utilities | Listing verified |
| Forest Pack | [6432306802](https://create.roblox.com/store/asset/6432306802) | Feb 2021 | 153,252 | 13 | 0 | Realistic trees, bushes, rocks, logs, stumps: station surroundings; **Hollow Woods** | Listing verified |
| Synty Nature Pack | [6933438443](https://create.roblox.com/store/asset/6933438443) | Jun 2021 | 108,816 | 0 | 0 | Low-poly nature. **Style doesn't match** the realistic Forest Pack; keep as a backup only | Listing verified (not planned) |

Other official packs seen in search but not checked: City Road Pack (6432233485), City Building Pack (6418277837), Synty City Pack (6933556508), Synty Dungeon packs (6934021345, 6933905899, 6933790012, 6934081776).

---

## 2. Gaps: no official asset, needs vetted third-party or a custom build

| Needed for | Item | Search terms that worked | Notes |
|---|---|---|---|
| Broadcast studio | Transmitter rack, receiver, mixing console, studio microphone, headphones | "radio transmitter", "mixing console" | Results are noisy. Look for established creators; check script count is 0 |
| Comms room | Server racks | "server rack" (278 results) | e.g. [SFF Server Rack 85958996039326](https://create.roblox.com/store/asset/85958996039326) by Exuberance Developments Industries: 6,000 tris, **1 audio file**. Inspect before use |
| Offices | Desktop PCs, CRT monitors, keyboards, office chairs, filing cabinets | "computer desk monitor", "office desk", "filing cabinet" | **Most top results are keyword-stuffed bot uploads (see Rejected)** |
| Electrical room | Breaker panels, fuse boxes, conduit, generator | "electrical panel", "industrial generator" | Same bot problem; prefer the Space Station pack's consoles/pipes, or a custom fuse box |
| Ceilings | Fluorescent tube fixtures, emergency lights | not searched yet | Simple enough to custom-build from a MeshPart plus a neon strip |
| Mission objects | Cartridge fuse, cassette tape, folder, photo | not searched yet | Small and simple: custom-building is safer than importing |
| The Echo | Tall thin humanoid with animations | n/a | No suitable store asset matches the design; plan a custom rig (Blender or Studio) plus animations |
| Audio | Ambience, footsteps, static, PA chime, enemy cues | not searched yet | Must be licensed for use; record every ID here before adding to `Config/Assets.Sounds` |

---

## 3. Rejected

| Asset | ID | Creator | Reason |
|---|---|---|---|
| "Old Breaker Box Electrical Panel Fuse Boxes Joint" | 78226674555337 | @Rozosere48 (created Oct 13, 2026) | Description says "No scripts", store reports **8 scripts and 4 audio files**. Keyword-stuffed title, brand-new account. Likely backdoor |
| "Computer Desk Monitor Tower PC Setup Computers Old" | 118928615617433 | @Lilokina34 (created Oct 16, 2026) | Description says "No scripts", store reports **2 scripts and 1 audio file**. Only 28 triangles for a "computer setup". Same bot pattern |

**Pattern to watch for:** long keyword-stuffed titles, accounts days old, script count > 0 that contradicts the description, and audio inside static props. Several near-identical listings come from different new accounts.

---

## 4. How to add an asset to this catalog
1. Find it on the store. Open its page and record ID, URL, creator, created date, triangle / script / audio counts, and intended use. Status: **Listing verified**.
2. In Studio: **Get Model**, insert, delete what you don't need, and **Save to File** into `assets/raw/<Kit>/`. Status: **Imported**.
3. Run `lune run tools/asset_audit`. Fix or reject. Status: **Audited**.
4. Place it in the game. Note the room in ENVIRONMENT_DESIGN.md. Status: **In use**.
