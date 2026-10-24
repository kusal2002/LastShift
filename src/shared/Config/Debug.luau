--!strict
-- Development diagnostics. Verbose logging only ever turns on inside Roblox Studio,
-- so leaving this true cannot affect live servers.
return table.freeze({
	Enabled = true,
	-- Studio only: force an anomaly id ("Listener", "Mimic", "Blackout"), or nil for random.
	ForceAnomaly = nil :: string?,
	-- Studio only: test-path the map a few seconds after start (results in Output). F11 runs it on demand.
	ValidateNavigationOnStart = true,
})
