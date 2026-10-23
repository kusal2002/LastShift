--!strict
-- Round timing and lobby rules. Times are in seconds.
local Round = table.freeze({
	MinPlayers = 1,
	MaxPlayers = 4,
	LobbyCountdown = 10, -- starts once MinPlayers are ready
	AllReadyCountdown = 3, -- shortened countdown when everyone in the server is ready
	BriefingDuration = 8,
	InvestigationDuration = 8 * 60,
	TransmitDuration = 40, -- the dangerous countdown after choosing to transmit
	ExtractionDuration = 90,
	ExtractionHoldSeconds = 3, -- time a player must stay in the extraction zone
	ResultsDuration = 15,
	TickInterval = 0.25, -- how often the round clock updates

	Briefing = table.freeze({
		Location = "Relay Station K-7 / Harrow Forest",
		Objective = "Restore the relay: replace the blown fuse, tune the radio to the posted frequency, "
			.. "and recover evidence of what is in the station. Then report it at the transmitter, and get out.",
		Controls = "Move: WASD or thumbstick    Interact: hold E or tap the prompt",
	}),
})

return Round
