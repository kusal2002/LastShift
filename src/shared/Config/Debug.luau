--!strict
-- Development diagnostics. Verbose logging only ever turns on inside Roblox Studio,
-- so leaving this true cannot affect live servers.
return table.freeze({
	Enabled = true,
	-- Studio only: force an anomaly id ("Listener", "Mimic", "Blackout"), or nil for random.
	ForceAnomaly = nil :: string?,
})
