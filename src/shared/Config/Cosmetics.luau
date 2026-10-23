--!strict
-- Cosmetic catalogue. Cosmetics never affect survival: flashlight skins only change the beam
-- colour (same range and brightness), badges are titles shown in the lobby.
-- Unlock kinds: Default (everyone), Level (reach a player level), Credits (buy with credits).
-- Robux items arrive in Phase 8.

export type Slot = "Flashlight" | "Badge"
export type Unlock =
	{ Kind: "Default" }
	| { Kind: "Level", Level: number }
	| { Kind: "Credits", Price: number }

export type Cosmetic = {
	Id: string,
	DisplayName: string,
	Slot: Slot,
	Unlock: Unlock,
	Color: { number }?, -- flashlight beam colour, RGB 0-255
}

local items: { Cosmetic } = {
	-- Flashlight beams
	{
		Id = "flashlight_standard",
		DisplayName = "Standard Issue",
		Slot = "Flashlight",
		Unlock = { Kind = "Default" },
		Color = { 255, 244, 214 },
	},
	{
		Id = "flashlight_sodium",
		DisplayName = "Sodium Amber",
		Slot = "Flashlight",
		Unlock = { Kind = "Level", Level = 3 },
		Color = { 255, 190, 110 },
	},
	{
		Id = "flashlight_cathode",
		DisplayName = "Cold Cathode",
		Slot = "Flashlight",
		Unlock = { Kind = "Level", Level = 6 },
		Color = { 190, 215, 255 },
	},
	{
		Id = "flashlight_phosphor",
		DisplayName = "Phosphor Green",
		Slot = "Flashlight",
		Unlock = { Kind = "Credits", Price = 400 },
		Color = { 170, 255, 170 },
	},
	{
		Id = "flashlight_darkroom",
		DisplayName = "Darkroom Red",
		Slot = "Flashlight",
		Unlock = { Kind = "Credits", Price = 750 },
		Color = { 255, 130, 120 },
	},
	-- Badges
	{
		Id = "badge_rookie",
		DisplayName = "Night Shift Rookie",
		Slot = "Badge",
		Unlock = { Kind = "Default" },
	},
	{
		Id = "badge_survivor",
		DisplayName = "Survivor",
		Slot = "Badge",
		Unlock = { Kind = "Level", Level = 4 },
	},
	{
		Id = "badge_veteran",
		DisplayName = "Relay Veteran",
		Slot = "Badge",
		Unlock = { Kind = "Level", Level = 10 },
	},
	{
		Id = "badge_signal",
		DisplayName = "Signal Chaser",
		Slot = "Badge",
		Unlock = { Kind = "Credits", Price = 300 },
	},
}

local byId: { [string]: Cosmetic } = {}
local defaults: { [string]: string } = {} -- slot -> default cosmetic id
for _, item in items do
	byId[item.Id] = table.freeze(item)
	if item.Unlock.Kind == "Default" and defaults[item.Slot] == nil then
		defaults[item.Slot] = item.Id
	end
end

return table.freeze({
	Items = table.freeze(items),
	ById = table.freeze(byId),
	DefaultBySlot = table.freeze(defaults),
	Slots = table.freeze({ "Flashlight", "Badge" }),
})
