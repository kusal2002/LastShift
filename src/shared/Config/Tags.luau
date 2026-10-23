--!strict
-- CollectionService tags that gameplay code uses to find map objects.
-- A hand-built map only needs to use the same tags (and attributes) to work.
return table.freeze({
	StationSpawn = "StationSpawn", -- invisible marker; players are placed here at round start
	FuseSpawn = "FuseSpawn", -- marker; one is picked per round for the fuse
	FusePanel = "FusePanel", -- breaker panel part
	RadioConsole = "RadioConsole", -- calibration console part
	FrequencyBoard = "FrequencyBoard", -- part whose front face shows the target frequency
	EvidenceSpawn = "EvidenceSpawn", -- marker; one is picked per round for the evidence item
	ExtractionZone = "ExtractionZone", -- non-colliding box; stand inside to escape
	ExitDoor = "ExitDoor", -- part that opens when extraction starts
	LobbySpawn = "LobbySpawn", -- the lobby SpawnLocation
	ChargingStation = "ChargingStation", -- wall unit that refills flashlight batteries
	EchoSpawn = "EchoSpawn", -- floor marker where the Echo appears each round
	EchoPatrol = "EchoPatrol", -- floor markers the Echo wanders between
})
