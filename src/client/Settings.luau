--!strict
-- Local accessibility settings. Values come from the saved profile when it loads; changing
-- one (Settings.set) applies it immediately and asks the server to save it.
-- The settings screen arrives in Phase 7.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Util.Signal)

export type Key = "Subtitles" | "AmbientSubtitles" | "ReducedFlashes"

local Settings = {}

Settings.Subtitles = true -- show subtitles for important audio cues
Settings.AmbientSubtitles = true -- also subtitle ambient sounds (footsteps, static)
Settings.ReducedFlashes = false -- replace light flicker with a slow dim

Settings.changed = Signal.new()

local KEYS: { Key } = { "Subtitles", "AmbientSubtitles", "ReducedFlashes" }

local function apply(key: Key, value: boolean)
	if (Settings :: any)[key] ~= value then
		(Settings :: any)[key] = value
		Settings.changed:Fire(key, value)
	end
end

function Settings.set(key: Key, value: boolean)
	apply(key, value)
	Remotes.getClient(Remotes.Names.SaveSetting):FireServer(key, value)
end

-- Called when the saved profile arrives.
function Settings.loadFrom(saved: { [string]: boolean })
	for _, key: Key in KEYS do
		local value = saved[key :: string]
		if type(value) == "boolean" then
			apply(key, value)
		end
	end
end

return Settings
