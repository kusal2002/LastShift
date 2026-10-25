--!strict
-- Local settings: subtitles, reduced flashes, volumes, text size and camera. Values come from the saved
-- profile when it loads; Settings.set applies a change immediately and asks the server to save
-- it (the server validates and clamps). The settings screen is SettingsController.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Util.Signal)
local Theme = require(script.Parent.UI.Theme)

export type Key =
	"Subtitles"
	| "AmbientSubtitles"
	| "ReducedFlashes"
	| "MasterVolume"
	| "EffectsVolume"
	| "AmbientVolume"
	| "TextScale"
	| "MouseSensitivity"
	| "FieldOfView"
	| "CameraMotion"

local Settings = {}

Settings.Subtitles = true -- subtitles for important audio cues
Settings.AmbientSubtitles = true -- also subtitle background sounds (footsteps, static)
Settings.ReducedFlashes = false -- replace light flicker with a slow dim
Settings.MasterVolume = 1
Settings.EffectsVolume = 1 -- important cues (enemy, alarms, PA)
Settings.AmbientVolume = 0.8 -- background cues
Settings.TextScale = 1 -- UI size multiplier
Settings.MouseSensitivity = 1 -- mouse look speed multiplier
Settings.FieldOfView = 80 -- first-person field of view, degrees
Settings.CameraMotion = 1 -- walking sway strength; 0 turns all camera motion off

-- Matches Profile.SettingRanges on the server.
Settings.Ranges = table.freeze({
	MasterVolume = { 0, 1 },
	EffectsVolume = { 0, 1 },
	AmbientVolume = { 0, 1 },
	TextScale = { 0.85, 1.3 },
	MouseSensitivity = { 0.2, 2 },
	FieldOfView = { 70, 90 },
	CameraMotion = { 0, 1 },
})

Settings.changed = Signal.new() -- (key, value)

local KEYS: { Key } = {
	"Subtitles",
	"AmbientSubtitles",
	"ReducedFlashes",
	"MasterVolume",
	"EffectsVolume",
	"AmbientVolume",
	"TextScale",
	"MouseSensitivity",
	"FieldOfView",
	"CameraMotion",
}

local function apply(key: Key, value: any)
	local current = (Settings :: any)[key]
	if type(value) ~= type(current) or current == value then
		return
	end
	(Settings :: any)[key] = value
	if key == "TextScale" then
		Theme.setUserScale(value)
	end
	Settings.changed:Fire(key, value)
end

function Settings.get(key: Key): any
	return (Settings :: any)[key]
end

function Settings.set(key: Key, value: boolean | number)
	if type(value) == "number" then
		local range = (Settings.Ranges :: any)[key]
		if range then
			value = math.round(math.clamp(value, range[1], range[2]) * 20) / 20
		end
	end
	apply(key, value)
	Remotes.getClient(Remotes.Names.SaveSetting):FireServer(key, value)
end

-- Called when the saved profile arrives.
function Settings.loadFrom(saved: { [string]: any })
	for _, key: Key in KEYS do
		local value = saved[key :: string]
		if value ~= nil then
			apply(key, value)
		end
	end
end

return Settings
