--!strict
-- The single authority over round phases: Lobby -> Briefing -> Investigation -> Extraction -> Results.
-- Owns the ready list, participants and their status, phase timers, and the round clock.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local RoundConfig = require(Shared.Config.Round)
local Tags = require(Shared.Config.Tags)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local RoundTransitions = require(Shared.Logic.RoundTransitions)
local RoundOutcome = require(Shared.Logic.RoundOutcome)
local Log = require(Shared.Util.Log)

local RemoteService = require(script.Parent.RemoteService)
local MapService = require(script.Parent.MapService)
local InteractionService = require(script.Parent.InteractionService)
local ObjectiveService = require(script.Parent.ObjectiveService)
local ExtractionService = require(script.Parent.ExtractionService)
local PlayerStateService = require(script.Parent.PlayerStateService)
local ChargingService = require(script.Parent.ChargingService)
local EnemyService = require(script.Parent.EnemyService)

type Phase = Types.Phase
type Status = Types.PlayerStatus

local Names = Remotes.Names

local RoundService = {}

local phase: Phase = "Lobby"
local phaseEndsAt: number? = nil
local roundId = 0
local roundStartedAt = 0
local ready: { [Player]: boolean } = {}
local participants: { [Player]: Status } = {}
local deathConnections: { [Player]: RBXScriptConnection } = {}
local spawnCursor = 0
local broadcastQueued = false

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function timeUp(): boolean
	local endsAt = phaseEndsAt
	return endsAt ~= nil and now() >= endsAt
end

local function countReady(): number
	local total = 0
	for player in ready do
		if player.Parent == Players then
			total += 1
		end
	end
	return total
end

local function alivePlayers(): { Player }
	local list = {}
	for player, status in participants do
		if status == "Alive" then
			table.insert(list, player)
		end
	end
	return list
end

-- Alive players who can act (not downed). Downed players can't extract.
local function ablePlayers(): { Player }
	local list = {}
	for _, player in alivePlayers() do
		if not PlayerStateService.isDowned(player) then
			table.insert(list, player)
		end
	end
	return list
end

local function buildTeam(): { Types.TeamMemberView }
	local team: { Types.TeamMemberView } = {}
	for player in participants do
		table.insert(team, {
			UserId = player.UserId,
			Name = player.DisplayName,
			Status = participants[player],
			Downed = PlayerStateService.isDowned(player),
		})
	end
	table.sort(team, function(a: Types.TeamMemberView, b: Types.TeamMemberView)
		return a.Name < b.Name
	end)
	return team
end

local function buildSnapshot(player: Player): Types.Snapshot
	local status = participants[player]
	local isParticipant = status ~= nil and status ~= "Left"
	local briefing: Types.BriefingView? = nil
	if phase == "Briefing" then
		briefing = {
			Location = RoundConfig.Briefing.Location,
			Objective = RoundConfig.Briefing.Objective,
			Controls = RoundConfig.Briefing.Controls,
		}
	end
	return {
		RoundId = roundId,
		Phase = phase,
		PhaseEndsAt = phaseEndsAt,
		PlayerCount = #Players:GetPlayers(),
		ReadyCount = countReady(),
		MinPlayers = RoundConfig.MinPlayers,
		IsReady = ready[player] == true,
		IsParticipant = isParticipant,
		Status = participants[player],
		Objectives = if isParticipant then ObjectiveService.getViews() else {},
		ExitOpen = ExtractionService.isOpen(),
		Briefing = briefing,
		Team = if isParticipant then buildTeam() else {},
	}
end

-- Sends every player their snapshot once at the end of this frame, however many changes happened.
local function broadcast()
	if broadcastQueued then
		return
	end
	broadcastQueued = true
	task.defer(function()
		broadcastQueued = false
		for _, player in Players:GetPlayers() do
			RemoteService.fire(player, Names.RoundSnapshot, buildSnapshot(player))
		end
	end)
end

local function pivotCharacter(player: Player, target: CFrame)
	local character = player.Character
	if character then
		character:PivotTo(target)
	end
end

local function sendToLobby(player: Player)
	local offset = Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
	pivotCharacter(player, MapService.getLobbySpawnCFrame() + offset)
end

local function sendToStation(player: Player)
	local spawns = MapService.getTagged(Tags.StationSpawn)
	if #spawns == 0 then
		Log.warn("Round", "No %s markers; cannot place %s", Tags.StationSpawn, player.Name)
		return
	end
	spawnCursor = spawnCursor % #spawns + 1
	pivotCharacter(player, spawns[spawnCursor].CFrame)
end

local setPhase: (nextPhase: Phase) -> ()

local function resetRound()
	ObjectiveService.reset()
	ExtractionService.close()
	ChargingService.reset()
	EnemyService.endRound()
	PlayerStateService.endRound()
	for player, status in participants do
		if player.Parent == Players and (status == "Alive" or status == "Lost") then
			sendToLobby(player)
		end
	end
	table.clear(participants)
end

local function endRound(reason: string)
	RoundOutcome.finalize(participants)
	local success = RoundOutcome.isSuccess(participants)
	local team: { Types.TeamMemberResult } = {}
	for player, status in participants do
		table.insert(team, { Name = player.DisplayName, Status = status :: Status })
	end
	local evidence = ObjectiveService.getEvidenceNames()
	local completed = ObjectiveService.completedCount()
	local total = ObjectiveService.total()
	local duration = math.floor(math.max(0, now() - roundStartedAt))

	for player, status in participants do
		if player.Parent == Players then
			local results: Types.Results = {
				RoundId = roundId,
				Success = success,
				Reason = reason,
				YourStatus = status :: Status,
				ObjectivesCompleted = completed,
				ObjectivesTotal = total,
				Evidence = evidence,
				DurationSeconds = duration,
				Team = team,
			}
			RemoteService.fire(player, Names.Results, results)
		end
	end
	Log.info(
		"Round",
		"Round %d ended: %s (success=%s, objectives %d/%d)",
		roundId,
		reason,
		tostring(success),
		completed,
		total
	)
	setPhase("Results")
end

local function checkEnd(timeExpired: boolean)
	if phase ~= "Briefing" and not RoundTransitions.isActiveRound(phase) then
		return
	end
	if RoundOutcome.isAbandoned(participants) then
		Log.info("Round", "Round %d cancelled: every participant left", roundId)
		setPhase("Lobby")
		return
	end
	if phase == "Briefing" then
		return
	end
	local shouldEnd, reason = RoundOutcome.decideEnd(phase, participants, timeExpired)
	if shouldEnd then
		endRound(reason)
	end
end

local function startRound()
	local chosen: { Player } = {}
	for player in ready do
		if player.Parent == Players and #chosen < RoundConfig.MaxPlayers then
			table.insert(chosen, player)
		end
	end
	if #chosen < RoundConfig.MinPlayers then
		return
	end

	roundId += 1
	-- The seed is logged so a round's random choices can be reproduced when debugging.
	local seed = Random.new():NextInteger(1, 2 ^ 30)
	table.clear(participants)
	for _, player in chosen do
		participants[player] = "Alive"
		ready[player] = nil
	end
	ObjectiveService.begin({
		rng = Random.new(seed),
		onChanged = broadcast,
		onAllComplete = function()
			if phase == "Investigation" then
				setPhase("Extraction")
			end
		end,
	})
	Log.info("Round", "Round %d starting with %d player(s), seed %d", roundId, #chosen, seed)
	setPhase("Briefing")
end

setPhase = function(nextPhase: Phase)
	if not RoundTransitions.canTransition(phase, nextPhase) then
		Log.warn("Round", "Rejected phase change %s -> %s", phase, nextPhase)
		return
	end
	Log.debug("Round", "Phase %s -> %s", phase, nextPhase)
	phase = nextPhase

	if nextPhase == "Lobby" then
		resetRound()
		phaseEndsAt = nil
	elseif nextPhase == "Briefing" then
		phaseEndsAt = now() + RoundConfig.BriefingDuration
	elseif nextPhase == "Investigation" then
		roundStartedAt = now()
		phaseEndsAt = roundStartedAt + RoundConfig.InvestigationDuration
		for player, status in participants do
			if status == "Alive" then
				sendToStation(player)
			end
		end
		local entering = alivePlayers()
		PlayerStateService.beginRound(entering)
		ChargingService.beginRound()
		EnemyService.beginRound(#entering == 1)
		-- If the map lacked objective parts, everything may already count as done.
		if ObjectiveService.allComplete() then
			task.defer(function()
				if phase == "Investigation" then
					setPhase("Extraction")
				end
			end)
		end
	elseif nextPhase == "Extraction" then
		ExtractionService.open()
		phaseEndsAt = now() + RoundConfig.ExtractionDuration
		for _, player in alivePlayers() do
			RemoteService.notify(
				player,
				"All systems restored. The exit is open. Get to the loading bay!",
				"success"
			)
		end
	elseif nextPhase == "Results" then
		phaseEndsAt = now() + RoundConfig.ResultsDuration
	end
	broadcast()
end

local function updateLobby()
	local readyCount = countReady()
	if readyCount < RoundConfig.MinPlayers then
		if phaseEndsAt ~= nil then
			phaseEndsAt = nil
			broadcast()
		end
		return
	end
	local current = now()
	local endsAt = phaseEndsAt or (current + RoundConfig.LobbyCountdown)
	if readyCount >= #Players:GetPlayers() then
		endsAt = math.min(endsAt, current + RoundConfig.AllReadyCountdown)
	end
	if endsAt ~= phaseEndsAt then
		phaseEndsAt = endsAt
		broadcast()
	end
	if current >= endsAt then
		startRound()
	end
end

local function updateExtraction(dt: number)
	local escaped, entered = ExtractionService.update(dt, ablePlayers())
	for _, player in entered do
		RemoteService.notify(player, "Hold position. Extracting...", "info")
	end
	for _, player in escaped do
		participants[player] = "Escaped"
		ObjectiveService.onPlayerRemoved(player)
		PlayerStateService.removeFromRound(player)
		sendToLobby(player)
		RemoteService.notify(player, "You made it out.", "success")
	end
	if #escaped > 0 then
		broadcast()
	end
end

local function tick(dt: number)
	if phase == "Lobby" then
		updateLobby()
	elseif phase == "Briefing" then
		if timeUp() then
			setPhase("Investigation")
		end
	elseif phase == "Investigation" then
		checkEnd(timeUp())
	elseif phase == "Extraction" then
		updateExtraction(dt)
		checkEnd(timeUp())
	elseif phase == "Results" then
		if timeUp() then
			setPhase("Lobby")
		end
	end
end

local function onDied(player: Player)
	if not RoundTransitions.isActiveRound(phase) or participants[player] ~= "Alive" then
		return
	end
	participants[player] = "Dead"
	ObjectiveService.onPlayerRemoved(player)
	ExtractionService.forget(player)
	PlayerStateService.removeFromRound(player)
	RemoteService.notify(player, "You didn't make it. Waiting for the shift to end.", "danger")
	broadcast()
	checkEnd(false)
end

local function onCharacterAdded(player: Player, character: Model)
	local previous = deathConnections[player]
	if previous then
		previous:Disconnect()
		deathConnections[player] = nil
	end
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		deathConnections[player] = humanoid.Died:Connect(function()
			onDied(player)
		end)
	end
	-- A participant who respawned before reaching the station (e.g. reset during the
	-- briefing) is placed inside once their character is ready.
	if participants[player] == "Alive" and RoundTransitions.isActiveRound(phase) then
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root and participants[player] == "Alive" and RoundTransitions.isActiveRound(phase) then
			sendToStation(player)
		end
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		onCharacterAdded(player, character)
	end)
	local character = player.Character
	if character then
		task.spawn(onCharacterAdded, player, character)
	end
	broadcast()
end

local function onPlayerRemoving(player: Player)
	ready[player] = nil
	local connection = deathConnections[player]
	if connection then
		connection:Disconnect()
		deathConnections[player] = nil
	end
	local status = participants[player]
	if status ~= nil then
		if status == "Alive" then
			participants[player] = "Left"
		end
		ObjectiveService.onPlayerRemoved(player)
		ExtractionService.forget(player)
		checkEnd(false)
	end
	broadcast()
end

function RoundService.Init()
	InteractionService.setGate(function(player: Player): (boolean, string?)
		if not RoundTransitions.isActiveRound(phase) then
			return false, nil
		end
		if participants[player] ~= "Alive" then
			return false, nil
		end
		if PlayerStateService.isDowned(player) then
			return false, "You can't do that while down."
		end
		return true, nil
	end)
	-- The Echo only targets players who are inside, alive and not downed.
	EnemyService.setTargetProvider(ablePlayers)
	PlayerStateService.setHooks({
		isActive = function(player: Player): boolean
			return RoundTransitions.isActiveRound(phase) and participants[player] == "Alive"
		end,
		onChanged = broadcast,
	})
end

-- Studio-only (called by DevCommandService): end the current phase timer now.
function RoundService.devSkipTimer()
	if phaseEndsAt ~= nil then
		phaseEndsAt = now()
		broadcast()
	end
end

function RoundService.Start()
	RemoteService.listen(
		Names.PlayRequest,
		{ capacity = 4, perSecond = 2 },
		function(player: Player, wantsReady: any)
			if typeof(wantsReady) ~= "boolean" then
				return
			end
			-- Players inside the station can't queue; everyone else (lobby, escaped, dead) can.
			if participants[player] == "Alive" then
				return
			end
			if wantsReady then
				ready[player] = true
			else
				ready[player] = nil
			end
			broadcast()
		end
	)
	RemoteService.listen(Names.SnapshotRequest, { capacity = 2, perSecond = 0.2 }, function(player: Player)
		RemoteService.fire(player, Names.RoundSnapshot, buildSnapshot(player))
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- The round clock. One connection for the server's lifetime; ticks every TickInterval.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < RoundConfig.TickInterval then
			return
		end
		local step = accumulator
		accumulator = 0
		tick(step)
	end)
	Log.info("Round", "RoundService ready")
end

return RoundService
