--!strict
-- Studio-only test commands (F6 damage, F7 skip phase timer, F8 drain battery).
-- Nothing is connected on live servers, and every command re-checks RunService:IsStudio().
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Log = require(Shared.Util.Log)
local RemoteService = require(script.Parent.RemoteService)
local PlayerStateService = require(script.Parent.PlayerStateService)
local RoundService = require(script.Parent.RoundService)

local DevCommandService = {}

function DevCommandService.Start()
	if not RunService:IsStudio() then
		return
	end
	RemoteService.listen(
		Remotes.Names.DevCommand,
		{ capacity = 5, perSecond = 2 },
		function(player: Player, command: any)
			if not RunService:IsStudio() or type(command) ~= "string" then
				return
			end
			if command == "Damage" then
				local result = PlayerStateService.applyDamage(player, 40, "DevCommand")
				RemoteService.notify(player, `[DEV] 40 damage: {result}`, "info")
			elseif command == "SkipTimer" then
				RoundService.devSkipTimer()
				RemoteService.notify(player, "[DEV] Phase timer skipped", "info")
			elseif command == "DrainBattery" then
				PlayerStateService.setBattery(player, 5)
				RemoteService.notify(player, "[DEV] Battery set to 5%", "info")
			end
		end
	)
	Log.info("Dev", "Studio dev commands on: F6 damage, F7 skip timer, F8 drain battery")
end

return DevCommandService
