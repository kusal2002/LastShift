--!strict
-- What a playable station must contain, checked by the map validator at server start.
-- `min` below = error (the round can't work); below `recommended` = warning.
-- Keep in step with Config/Evidence (SpawnCount) and Config/Anomalies (DecoyCount).
export type Requirement = { tag: string, min: number, recommended: number?, what: string }

local requirements: { Requirement } = {
	{ tag = "StationSpawn", min = 1, recommended = 4, what = "invisible marker where players enter" },
	{ tag = "FuseSpawn", min = 1, recommended = 3, what = "marker where the fuse can appear" },
	{ tag = "FusePanel", min = 1, what = "breaker / fuse box part" },
	{ tag = "RadioConsole", min = 1, what = "broadcast desk part (calibration and transmitter)" },
	{ tag = "FrequencyBoard", min = 1, what = "part whose front face shows the target frequency" },
	{ tag = "EvidenceSpawn", min = 3, recommended = 4, what = "marker where evidence can appear" },
	{ tag = "RiskyEvidenceSpawn", min = 0, recommended = 1, what = "marker for the optional risky evidence" },
	{ tag = "ExtractionZone", min = 1, what = "non-colliding box players stand in to escape" },
	{ tag = "ExitDoor", min = 0, recommended = 1, what = "door part that opens at extraction" },
	{ tag = "EchoSpawn", min = 1, what = "floor marker where the Echo starts" },
	{ tag = "EchoPatrol", min = 6, recommended = 10, what = "floor markers the Echo walks between" },
	{ tag = "ChargingStation", min = 0, recommended = 2, what = "flashlight charger part" },
	{ tag = "PowerSwitch", min = 0, recommended = 1, what = "backup power part (ends blackouts)" },
	{ tag = "DecoySpawn", min = 0, recommended = 2, what = "marker where a noise maker can appear" },
	{ tag = "StationLight", min = 1, recommended = 8, what = "ceiling lamp part with a light inside" },
	{
		tag = "RoomVolume",
		min = 1,
		recommended = 6,
		what = "invisible box covering a room (attribute RoomName)",
	},
}

return table.freeze(requirements)
