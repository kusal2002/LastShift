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
--
-- Rooms: storage (top left), operations (top middle), tower access (top right),
-- corridor (middle), generator (bottom left), entrance hall (bottom middle),
-- maintenance (bottom right), loading bay (beyond the exit door).
return {
	CellSize = 8,
	WallHeight = 14,
	-- Raised well above any default baseplate so the two never overlap.
	Origin = { X = 0, Y = 100, Z = 0 },
	LobbyOrigin = { X = 92, Y = 100, Z = -160 },
	LobbySize = 64,
	MountedChars = { P = true, R = true, B = true, Q = true },
	Rows = {
		"########################",
		"#E..F.#.......R..#F...E#",
		"#.....#..........#.....#",
		"#..L..#...L..L...#..L..#",
		"#.....#..........#.....#",
		"#.....#..........#....Q#",
		"###.#######.#######.####",
		"#......................#",
		"#...C......C.......C...#",
		"###.#######.#######.####",
		"#Q....#..........#.....#",
		"#..L.P#...L..L...#..L.B#",
		"#.....#...S..S...#.....#",
		"#E....#..........#....E#",
		"#.....#...S..S...#..F..#",
		"###########DD###########",
		"##########XXXX##########",
		"########################",
	},
}
