--!strict
-- Spawns The Echo when players enter the station and removes it when the round ends.
-- The round's anomaly profile retunes it; blackouts apply the profile's dark tuning.
-- One enemy per round in the MVP.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local EnemyConfig = require(Shared.Config.Enemy)
local AudioConfig = require(Shared.Config.Audio)
local Anomalies = require(Shared.Config.Anomalies)
local Tags = require(Shared.Config.Tags)
local Tuning = require(Shared.Logic.Tuning)
local EchoBrain = require(Shared.Logic.EchoBrain)
local Log = require(Shared.Util.Log)
local MapService = require(script.Parent.MapService)
local LightingService = require(script.Parent.LightingService)
local AudioEventService = require(script.Parent.AudioEventService)
local Echo = require(script.Parent.Parent.Enemy.Echo)

-- Audio cue each state announces to nearby players: the Echo's learnable "tells".
local STATE_CUES: { [string]: string } = {
	Listen = "EchoClick",
	Stalk = "EchoWhisper",
	Hunt = "EchoScreech",
	Attack = "EchoWindup",
}

local EnemyService = {}

local folder: Folder
local active: Echo.Echo? = nil
local getTargets: () -> { Player } = function()
	return {}
end
local getAudience: () -> { Player } = function()
	return {}
end

function EnemyService.Init()
	folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = Workspace
end

-- RoundService provides the players the Echo may target (alive, inside, not downed)
-- and those who can hear its cues (everyone still inside).
function EnemyService.setProviders(targets: () -> { Player }, audience: () -> { Player })
	getTargets = targets
	getAudience = audience
end

function EnemyService.beginRound(solo: boolean, profile: Anomalies.Profile)
	EnemyService.endRound()
	local patrolPoints: { Vector3 } = {}
	for _, marker in MapService.getTagged(Tags.EchoPatrol) do
		table.insert(patrolPoints, marker.Position)
	end
	local spawns = MapService.getTagged(Tags.EchoSpawn)
	if #patrolPoints == 0 or #spawns == 0 then
		Log.warn("Enemy", "No Echo this round: map needs %s and %s markers", Tags.EchoSpawn, Tags.EchoPatrol)
		return
	end

	local tuning = Tuning.apply(EnemyConfig, profile.EchoModifiers) :: Echo.Tuning
	local darkModifiers = profile.DarkModifiers
	local darkTuning = if darkModifiers then Tuning.apply(tuning, darkModifiers) :: Echo.Tuning else nil

	active = Echo.new({
		spawn = CFrame.new(spawns[1].Position),
		patrolPoints = patrolPoints,
		solo = solo,
		getTargets = function()
			return getTargets()
		end,
		rng = Random.new(),
		parent = folder,
		tuning = tuning,
		darkTuning = darkTuning,
		isDark = LightingService.isOutage,
		onStateChanged = function(state: EchoBrain.State, position: Vector3)
			local cue = STATE_CUES[state]
			if cue then
				AudioEventService.playNear(getAudience(), cue, position, AudioConfig.EchoCueRadius)
			end
		end,
	})
	Log.info("Enemy", "Echo spawned (%s), %d patrol points", if solo then "solo" else "team", #patrolPoints)
end

function EnemyService.endRound()
	local echo = active
	if echo then
		active = nil
		echo.destroy()
	end
end

-- Send the Echo to check a position (Mimic lures).
function EnemyService.lure(position: Vector3)
	local echo = active
	if echo then
		echo.lure(position)
	end
end

-- Extraction: the Echo is definitely awake now.
function EnemyService.escalate()
	local echo = active
	if echo then
		echo.wake()
	end
end

-- Studio-only: skip the Echo's dormant period.
function EnemyService.devWake()
	EnemyService.escalate()
end

return EnemyService
