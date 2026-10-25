--!strict
-- Studio-only test commands: F6 damage, F7 skip phase timer, F8 drain battery, F9 wake the Echo,
-- F10 trigger the next scare event, F11 validate the map (structure + navigation).
-- Nothing is connected on live servers, and every command re-checks RunService:IsStudio().
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local DebugConfig = require(Shared.Config.Debug)
local MapRules = require(Shared.Logic.MapRules)
local Log = require(Shared.Util.Log)
local MapValidator = require(script.Parent.Parent.Map.MapValidator)
local RemoteService = require(script.Parent.RemoteService)
local MapService = require(script.Parent.MapService)
local PlayerStateService = require(script.Parent.PlayerStateService)
local RoundService = require(script.Parent.RoundService)
local EnemyService = require(script.Parent.EnemyService)
local DirectorService = require(script.Parent.DirectorService)

local DevCommandService = {}

local validating = false

-- Full map check; results go to Output. Returns (errors, warnings).
local function validateMap(): (number, number)
	local issues = MapValidator.check(MapService.getStation())
	for _, issue in MapService.validateNavigation() do
		table.insert(issues, issue)
	end
	MapValidator.report("Map validation (structure + navigation)", issues)
	local errors = MapRules.errorCount(issues)
	return errors, #issues - errors
end

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
			elseif command == "TriggerEvent" then
				DirectorService.devTrigger()
				RemoteService.notify(player, "[DEV] Director event triggered", "info")
			elseif command == "WakeEcho" then
				EnemyService.devWake()
				RemoteService.notify(player, "[DEV] Echo awake", "info")
			elseif command == "DrainBattery" then
				PlayerStateService.setBattery(player, 5)
				RemoteService.notify(player, "[DEV] Battery set to 5%", "info")
			elseif command == "ValidateMap" and not validating then
				validating = true
				RemoteService.notify(player, "[DEV] Validating map...", "info")
				task.spawn(function()
					local errors, warnings = validateMap()
					validating = false
					RemoteService.notify(
						player,
						`[DEV] Map: {errors} error(s), {warnings} warning(s). Details in Output.`,
						if errors > 0 then "danger" else "success"
					)
				end)
			end
		end
	)
	if DebugConfig.ValidateNavigationOnStart then
		task.delay(3, function()
			if not validating then
				validating = true
				validateMap()
				validating = false
			end
		end)
	end
	Log.info(
		"Dev",
		"Studio dev commands on: F6 damage, F7 skip timer, F8 drain battery, F9 wake Echo, F10 next scare event, F11 validate map"
	)
end

return DevCommandService
