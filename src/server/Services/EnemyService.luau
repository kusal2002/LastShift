--!strict
-- Spawns The Echo when players enter the station and removes it when the round ends.
-- One enemy per round in the MVP.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Tags = require(Shared.Config.Tags)
local Log = require(Shared.Util.Log)
local MapService = require(script.Parent.MapService)
local Echo = require(script.Parent.Parent.Enemy.Echo)

local EnemyService = {}

local folder: Folder
local active: Echo.Echo? = nil
local getTargets: () -> { Player } = function()
	return {}
end

function EnemyService.Init()
	folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = Workspace
end

-- RoundService provides the players the Echo may target (alive, inside, not downed).
function EnemyService.setTargetProvider(provider: () -> { Player })
	getTargets = provider
end

function EnemyService.beginRound(solo: boolean)
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
	active = Echo.new({
		spawn = CFrame.new(spawns[1].Position),
		patrolPoints = patrolPoints,
		solo = solo,
		getTargets = function()
			return getTargets()
		end,
		rng = Random.new(),
		parent = folder,
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

-- Studio-only: skip the Echo's dormant period.
function EnemyService.devWake()
	local echo = active
	if echo then
		echo.wake()
	end
end

return EnemyService
