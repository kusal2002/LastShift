--!strict
-- Persistence settings.
return table.freeze({
	StoreName = "LastShift_Profiles_v1",
	KeyPrefix = "u_",
	-- "Auto": real DataStores on live servers; in Studio, real DataStores if API access is
	-- enabled, otherwise the in-memory mock (progress is NOT saved, and a warning is printed).
	-- "Mock": always the in-memory mock (Studio only; live servers always use DataStores).
	Mode = "Auto" :: "Auto" | "Mock",
	AutosaveSeconds = 60,
	LockStaleSeconds = 180, -- a lock older than this belongs to a crashed server and can be taken
	LoadAttempts = 5, -- retries (with backoff) before kicking with a friendly message
	SaveAttempts = 4,
	ShutdownWaitSeconds = 25,
})
