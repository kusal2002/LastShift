--!strict
-- Graybox layout for Relay Station K-7. Pure data (no Roblox APIs) so tests can validate it.
--
-- Each character is one cell (CellSize x CellSize studs). Legend:
--   #  wall                     .  floor
--   S  player spawn             F  fuse spawn (crate + marker)
--   E  evidence spawn (desk)    P  breaker panel (wall-mounted)
--   R  radio console (wall)     B  frequency board (wall-mounted)
--   L  warm ceiling light       C  cold ceiling light
--   D  exit door (opens at extraction)
--   X  extraction zone (loading bay)
--   Q  flashlight charging station (wall-mounted)
--   Z  Echo spawn (lair). Every L and C cell is also an Echo patrol point.
--   G  backup power switch (wall-mounted); ends a blackout early
--   N  noise maker pickup (shelf + marker)
--   K  optional risky evidence (desk near the Echo lair)
return {
	CellSize = 8,
	WallHeight = 14,
	-- Raised well above any default baseplate so the two never overlap.
	Origin = { X = 0, Y = 100, Z = 0 },
	LobbyOrigin = { X = 92, Y = 100, Z = -160 },
	LobbySize = 64,
	MountedChars = { P = true, R = true, B = true, Q = true, G = true },
	Rows = {
		"########################",
		"#E..F.#.......R..#F...E#",
		"#.....#..........#..Z..#",
		"#..L..#...L..L...#..L..#",
		"#.....#..........#..K..#",
		"#.....#..........#....Q#",
		"###.#######.#######.####",
		"#N....................N#",
		"#...C......C.......C...#",
		"###.#######.#######.####",
		"#Q....#..........#.....#",
		"#..L.P#...L..L...#..L.B#",
		"#.....#.N.S..S...#.....#",
		"#E...G#..........#....E#",
		"#.....#...S..S...#..F..#",
		"###########DD###########",
		"##########XXXX##########",
		"########################",
	},
	-- Wall signs. The first line is always the room name exactly as the HUD shows it, so players
	-- can match a radio call or teammate location to a place. Each cell needs a wall beside it.
	Signs = {
		{ Text = "STORAGE", Row = 1, Col = 3 },
		{ Text = "OPERATIONS\nRELAY TRANSMITTER", Row = 1, Col = 10 },
		{ Text = "TOWER ACCESS\nAUTHORIZED PERSONNEL ONLY", Row = 1, Col = 20, Warning = true },
		{ Text = "CORRIDOR", Row = 7, Col = 8 },
		{ Text = "GENERATOR ROOM\nDANGER: HIGH VOLTAGE", Row = 10, Col = 4, Warning = true },
		{ Text = "ENTRANCE HALL", Row = 10, Col = 8 },
		{ Text = "MAINTENANCE", Row = 10, Col = 20 },
	},
	-- Named areas (zero-based, inclusive). Shown in the HUD team list and used by events.
	Rooms = {
		{ Name = "Storage", Rows = { 1, 5 }, Cols = { 1, 5 } },
		{ Name = "Operations", Rows = { 1, 5 }, Cols = { 7, 16 } },
		{ Name = "Tower Access", Rows = { 1, 5 }, Cols = { 18, 22 } },
		{ Name = "Corridor", Rows = { 6, 9 }, Cols = { 1, 22 } },
		{ Name = "Generator Room", Rows = { 10, 14 }, Cols = { 1, 5 } },
		{ Name = "Entrance Hall", Rows = { 10, 15 }, Cols = { 7, 16 } },
		{ Name = "Maintenance", Rows = { 10, 14 }, Cols = { 18, 22 } },
		{ Name = "Loading Bay", Rows = { 16, 16 }, Cols = { 10, 13 } },
	},
}
