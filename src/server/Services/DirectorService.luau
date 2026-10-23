--!strict
-- The event director. Once a second it may start one scare event, chosen by ScareDirector
-- from the round's anomaly profile, with a quiet start, gaps between events and cooldowns.
-- Events never block objectives: fake cues and outages are optional to engage with.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local DirectorConfig = require(Shared.Config.Director)
local RoundConfig = require(Shared.Config.Round)
local AudioConfig = require(Shared.Config.Audio)
local ObjectivesConfig = require(Shared.Config.Objectives)
local Tags = require(Shared.Config.Tags)
local Anomalies = require(Shared.Config.Anomalies)
local ScareDirector = require(Shared.Logic.ScareDirector)
local Selection = require(Shared.Logic.Selection)
local Maid = require(Shared.Util.Maid)
local Log = require(Shared.Util.Log)

local MapService = require(script.Parent.MapService)
local InteractionService = require(script.Parent.InteractionService)
local NoiseService = require(script.Parent.NoiseService)
local RemoteService = require(script.Parent.RemoteService)
local AudioEventService = require(script.Parent.AudioEventService)
local LightingService = require(script.Parent.LightingService)
local EnemyService = require(script.Parent.EnemyService)

export type BeginParams = {
	profile: Anomalies.Profile,
	getPlayers: () -> { Player }, -- participants still inside
	rng: Random,
}

local OUTAGE_EXCLUDED_ROOMS = { ["Loading Bay"] = true }
local FAKE_CUE_RADIUS = 80

local DirectorService = {}

local running = false
local roundToken = 0
local profile: Anomalies.Profile? = nil
local state = ScareDirector.new(0)
local rng = Random.new()
local extracting = false
local outageWarning = false
local falseCueActive = false
local getPlayers: () -> { Player } = function()
	return {}
end
local eventMaid = Maid.new()

local function nextInt(low: number, high: number): number
	return rng:NextInteger(low, high)
end

local function roomOf(player: Player): string
	local root = InteractionService.getRoot(player)
	return if root then MapService.roomAt(root.Position) else ""
end

local function fill(line: string, name: string, room: string): string
	local safeName = string.gsub(name, "%%", "%%%%")
	local filled = string.gsub(line, "{name}", safeName)
	filled = string.gsub(filled, "{room}", room)
	return filled
end

-- A room other than the excluded ones, chosen at random.
local function otherRoom(excluded: { [string]: boolean }): string?
	local options = {}
	for _, name in MapService.getRoomNames() do
		if not excluded[name] and not OUTAGE_EXCLUDED_ROOMS[name] then
			table.insert(options, name)
		end
	end
	return Selection.pickOne(options, nextInt)
end

local function onPowerRestored(byPlayer: Player?)
	AudioEventService.play(getPlayers(), "PowerRestored")
	if byPlayer then
		RemoteService.notify(byPlayer, "Backup power restored. That was loud.", "success")
	end
end

-- Mimic: a radio call in a teammate's name (your own, if solo) naming a room they are NOT in.
-- The HUD team list shows where everyone really is, so careful players can catch the lie.
local function mimicCall(lines: { string }, cue: string)
	local players = getPlayers()
	local speaker = Selection.pickOne(players, nextInt)
	if speaker == nil then
		return
	end
	local room = otherRoom({ [roomOf(speaker)] = true })
	local line = Selection.pickOne(lines, nextInt)
	if room == nil or line == nil then
		return
	end
	AudioEventService.play(players, cue, fill(line, speaker.DisplayName, room))
	if rng:NextNumber() < DirectorConfig.MimicLureChance then
		local point = Selection.pickOne(MapService.getRoomPoints(room), nextInt)
		if point then
			EnemyService.lure(point)
		end
	end
end

-- Mimic: something that looks like evidence. Touching it only makes noise; real objectives
-- are never affected.
local function spawnFalseCue()
	local spots = MapService.getTagged(Tags.EvidenceSpawn)
	local free = {}
	for _, spot in spots do
		local occupied = false
		for _, child in MapService.getRoundFolder():GetChildren() do
			if child:IsA("BasePart") and (child.Position - spot.Position).Magnitude < 1.5 then
				occupied = true
				break
			end
		end
		if not occupied then
			table.insert(free, spot)
		end
	end
	local spot = Selection.pickOne(free, nextInt)
	local disguise = Selection.pickOne(ObjectivesConfig.Evidence.Items, nextInt)
	if spot == nil or disguise == nil then
		return
	end
	falseCueActive = true
	local part = Instance.new("Part")
	part.Name = "FalseCue"
	part.Size = Vector3.new(1.2, 0.2, 1.6)
	part.Color = Color3.fromRGB(214, 206, 180)
	part.Anchored = true
	part.CanCollide = false
	part.CFrame = spot.CFrame
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(126, 205, 140)
	glow.Range = 5
	glow.Brightness = 0.6
	glow.Parent = part
	part.Parent = MapService.getRoundFolder()
	eventMaid:give(part)

	local position = spot.Position
	InteractionService.createPrompt(part, {
		ActionText = "Examine",
		ObjectText = disguise.DisplayName,
		HoldDuration = ObjectivesConfig.Evidence.HoldDuration,
		MaxDistance = ObjectivesConfig.Evidence.InteractDistance,
	}, function(player: Player)
		if part.Parent == nil then
			return
		end
		part:Destroy()
		falseCueActive = false
		NoiseService.emit(position, 0.9, "FalseCue")
		AudioEventService.playNear(getPlayers(), "GhostStatic", position, FAKE_CUE_RADIUS)
		RemoteService.notify(player, "It dissolves into static. Something heard that.", "warn")
	end)
	local token = roundToken
	eventMaid:give(task.delay(DirectorConfig.FalseCueLifetime, function()
		if token == roundToken and part.Parent ~= nil then
			part:Destroy()
			falseCueActive = false
		end
	end))
end

-- Blackout: warn, flicker, then cut the lights in a couple of rooms (usually where someone is).
local function startOutage()
	local config = DirectorConfig.Outage
	local players = getPlayers()
	local rooms: { string } = {}
	local chosen: { [string]: boolean } = {}
	local victim = Selection.pickOne(players, nextInt)
	if victim then
		local room = roomOf(victim)
		if room ~= "" and not OUTAGE_EXCLUDED_ROOMS[room] then
			table.insert(rooms, room)
			chosen[room] = true
		end
	end
	while #rooms < config.Rooms do
		local room = otherRoom(chosen)
		if room == nil then
			break
		end
		table.insert(rooms, room)
		chosen[room] = true
	end
	if not chosen.Corridor and rng:NextNumber() < 0.5 then
		table.insert(rooms, "Corridor")
	end
	if #rooms == 0 then
		return
	end

	outageWarning = true
	AudioEventService.play(players, "PowerFailing")
	for _, room in rooms do
		LightingService.flicker(players, room, config.WarningSeconds)
	end
	local token = roundToken
	eventMaid:give(task.delay(config.WarningSeconds, function()
		outageWarning = false
		if token ~= roundToken or not running then
			return
		end
		LightingService.startOutage(rooms, config.Duration)
		AudioEventService.play(getPlayers(), "PowerDown")
	end))
end

local function runEvent(id: string)
	Log.debug("Director", "Event %s", id)
	local players = getPlayers()
	if id == "DistantFootsteps" then
		AudioEventService.play(players, "DistantFootsteps")
	elseif id == "RadioInterference" then
		AudioEventService.play(players, "RadioStatic")
		LightingService.flicker(players, "Operations", 1.2)
	elseif id == "LightFlicker" then
		local target = Selection.pickOne(players, nextInt)
		local room = if target then roomOf(target) else ""
		if room ~= "" then
			LightingService.flicker(players, room, DirectorConfig.FlickerSeconds)
			AudioEventService.play(players, "ElectricalBuzz")
		end
	elseif id == "PAAnnouncement" then
		local line = Selection.pickOne(AudioConfig.PALines, nextInt)
		if line then
			AudioEventService.play(players, "PAChime", line)
		end
	elseif id == "MimicCall" then
		mimicCall(AudioConfig.MimicCallLines, "RadioCall")
	elseif id == "MimicPA" then
		mimicCall(AudioConfig.MimicPALines, "PAChime")
	elseif id == "MimicFalseCue" then
		spawnFalseCue()
	elseif id == "PowerOutage" then
		startOutage()
	end
end

local function tick()
	LightingService.update()
	local current = profile
	if current == nil then
		return
	end
	local now = os.clock()
	local intensity =
		ScareDirector.intensity(now - state.startedAt, RoundConfig.InvestigationDuration, extracting)
	local blocked = {
		PowerOutage = outageWarning or LightingService.isOutage(),
		MimicFalseCue = falseCueActive,
	}
	local id = ScareDirector.pick(
		state,
		now,
		intensity,
		DirectorConfig.Events,
		current.EventWeights,
		blocked,
		DirectorConfig,
		function()
			return rng:NextNumber()
		end
	)
	if id then
		ScareDirector.record(state, id, now)
		runEvent(id)
	end
end

function DirectorService.Start()
	-- Server-lifetime clock; does nothing between rounds.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < DirectorConfig.TickInterval then
			return
		end
		accumulator = 0
		if running then
			tick()
		end
	end)
end

function DirectorService.beginRound(params: BeginParams)
	DirectorService.endRound()
	roundToken += 1
	running = true
	profile = params.profile
	getPlayers = params.getPlayers
	rng = params.rng
	state = ScareDirector.new(os.clock())
	extracting = false
	LightingService.beginRound(onPowerRestored)
end

-- Extraction: full intensity and an alarm.
function DirectorService.setExtracting()
	extracting = true
	AudioEventService.play(getPlayers(), "ExtractionAlarm")
end

function DirectorService.endRound()
	running = false
	roundToken += 1
	profile = nil
	outageWarning = false
	falseCueActive = false
	eventMaid:clean()
	LightingService.endRound()
end

-- Studio-only: run the next event now, ignoring the quiet start and the gap.
function DirectorService.devTrigger()
	if not running then
		return
	end
	state.startedAt = -math.huge
	state.lastEventAt = -math.huge
	tick()
end

return DirectorService
