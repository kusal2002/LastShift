--!strict
-- Flashlight charging stations. Each station has a limited number of refills per round,
-- so light is a resource the team has to manage.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local PlayerConfig = require(Shared.Config.Player)
local Tags = require(Shared.Config.Tags)
local Maid = require(Shared.Util.Maid)
local MapService = require(script.Parent.MapService)
local InteractionService = require(script.Parent.InteractionService)
local PlayerStateService = require(script.Parent.PlayerStateService)
local RemoteService = require(script.Parent.RemoteService)

local ChargingService = {}

local maid = Maid.new()

local function usesText(uses: number): string
	return if uses == 1 then "Charger (1 charge left)" else `Charger ({uses} charges left)`
end

function ChargingService.reset()
	maid:clean()
end

function ChargingService.beginRound()
	ChargingService.reset()
	local config = PlayerConfig.Charging
	for _, station in MapService.getTagged(Tags.ChargingStation) do
		local uses = config.UsesPerStation
		local prompt: ProximityPrompt
		prompt = InteractionService.createPrompt(station, {
			ActionText = "Recharge flashlight",
			ObjectText = usesText(uses),
			HoldDuration = config.HoldDuration,
			MaxDistance = config.InteractDistance,
		}, function(player: Player)
			if uses <= 0 then
				RemoteService.notify(player, "This charger is spent.", "warn")
				return
			end
			if PlayerStateService.getBattery(player) >= PlayerConfig.Flashlight.MaxBattery - 1 then
				RemoteService.notify(player, "Your battery is already full.", "info")
				return
			end
			uses -= 1
			PlayerStateService.setBattery(player, PlayerConfig.Flashlight.MaxBattery)
			prompt.ObjectText = usesText(uses)
			if uses <= 0 then
				prompt.Enabled = false
			end
			RemoteService.notify(player, "Flashlight recharged.", "success")
		end)
		maid:give(prompt)
	end
end

return ChargingService
