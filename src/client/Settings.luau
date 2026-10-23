--!strict
-- Local accessibility settings. Defaults only for now; the settings screen arrives in Phase 7
-- (and persistence in Phase 6).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local Settings = {}

Settings.Subtitles = true -- show subtitles for important audio cues
Settings.AmbientSubtitles = true -- also subtitle ambient sounds (footsteps, static)
Settings.ReducedFlashes = false -- replace light flicker with a slow dim

Settings.changed = Signal.new()

function Settings.set(key: "Subtitles" | "AmbientSubtitles" | "ReducedFlashes", value: boolean)
	(Settings :: any)[key] = value
	Settings.changed:Fire(key, value)
end

return Settings
