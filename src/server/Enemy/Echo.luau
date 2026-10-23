--!strict
-- One Echo instance. Each AI tick it perceives (sight, hearing), asks EchoBrain for the next
-- state, then acts: patrol, stalk at a distance, chase, wind up and strike, search, retreat.
-- Server only. Destroy it to stop the AI thread and remove the model.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local EnemyConfig = require(Shared.Config.Enemy)
local DebugConfig = require(Shared.Config.Debug)
local EchoBrain = require(Shared.Logic.EchoBrain)
local Maid = require(Shared.Util.Maid)
local Log = require(Shared.Util.Log)

local Services = script.Parent.Parent.Services
local PlayerStateService = require(Services.PlayerStateService)
local InteractionService = require(Services.InteractionService)
local NoiseService = require(Services.NoiseService)
local RemoteService = require(Services.RemoteService)
local EchoRig = require(script.Parent.EchoRig)
local EchoMover = require(script.Parent.EchoMover)

type State = EchoBrain.State

export type Params = {
	spawn: CFrame, -- floor point to stand on
	patrolPoints: { Vector3 },
	solo: boolean,
	getTargets: () -> { Player }, -- players it may see and attack
	rng: Random,
	parent: Instance,
}

export type Echo = {
	destroy: () -> (),
	wake: () -> (),
	getState: () -> State,
}

-- Eye colour is the Echo's readable state cue until audio arrives in Phase 4.
local EYES = {
	Calm = Color3.fromRGB(200, 205, 210),
	Alert = Color3.fromRGB(255, 214, 150),
	Hunt = Color3.fromRGB(230, 60, 50),
	Strike = Color3.fromRGB(255, 20, 20),
}

local MAX_TICK_ERRORS = 20
local PLAYER_ROOT_HEIGHT = 2.5 -- roughly how far a player's root part sits above the floor

local Echo = {}

local function eyeColorFor(state: State): Color3
	if state == "Attack" then
		return EYES.Strike
	elseif state == "Hunt" then
		return EYES.Hunt
	elseif state == "Stalk" or state == "Listen" or state == "Investigate" or state == "Search" then
		return EYES.Alert
	end
	return EYES.Calm
end

function Echo.new(params: Params): Echo
	local cfg = EnemyConfig
	local rig = EchoRig.build(params.spawn, params.parent)
	local root = rig.root
	local mover = EchoMover.new(rig.humanoid, root)
	local maid = Maid.new()
	maid:give(rig.model)
	maid:give(mover.destroy)

	local state: State = "Dormant"
	local stateStarted = os.clock()
	local awakeAt = os.clock() + cfg.DormantSeconds
	local alert = 0
	local target: Player? = nil
	local lastSeenPosition: Vector3? = nil
	local lastSeenTime = -math.huge
	local sounds: { NoiseService.Noise } = {}
	local soundGoal: Vector3? = nil
	local searchCenter = root.Position
	local attackReadyAt = 0
	local attackResolved = false
	local attackHit = false
	local lastStatus: EchoMover.Status = "Idle"
	local failureStreak = 0
	local running = true
	local chaseSpeed = if params.solo then cfg.Speeds.Chase else cfg.Speeds.ChaseMultiplayer
	local attackCooldown = if params.solo then cfg.SoloAttackCooldown else cfg.AttackCooldown

	local sightParams = RaycastParams.new()
	sightParams.FilterType = Enum.RaycastFilterType.Exclude
	sightParams.FilterDescendantsInstances = { rig.model }

	-- Studio-only label above the Echo showing its state and alert level.
	local debugLabel: TextLabel? = nil
	if DebugConfig.Enabled and RunService:IsStudio() then
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(180, 36)
		billboard.StudsOffset = Vector3.new(0, 2.5, 0)
		billboard.AlwaysOnTop = true
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 0.4
		label.BackgroundColor3 = Color3.new(0, 0, 0)
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Font = Enum.Font.RobotoMono
		label.TextScaled = true
		label.Parent = billboard
		billboard.Parent = rig.head
		debugLabel = label
	end

	local function setEyes(color: Color3)
		for _, eye in rig.eyes do
			eye.Color = color
		end
	end

	-- True if nothing but `targetModel` (or nothing at all) blocks the line from `from` to `to`.
	local function hasLineOfSight(from: Vector3, to: Vector3, targetModel: Instance?): boolean
		local result = Workspace:Raycast(from, to - from, sightParams)
		if result == nil then
			return true
		end
		return targetModel ~= nil and result.Instance:IsDescendantOf(targetModel)
	end

	local function faceTowards(position: Vector3)
		local from = root.Position
		local flatTarget = Vector3.new(position.X, from.Y, position.Z)
		if (flatTarget - from).Magnitude > 0.1 then
			root.CFrame = CFrame.lookAt(from, flatTarget)
		end
	end

	-- Nearest target it can actually see: in range, in its field of view (or very close), unobstructed.
	local function perceive(): (Player?, number?, Vector3?)
		local eye = rig.head.Position
		local forward = root.CFrame.LookVector
		local best: Player? = nil
		local bestDistance = math.huge
		local bestPosition: Vector3? = nil
		for _, player in params.getTargets() do
			local character = player.Character
			local targetRoot = InteractionService.getRoot(player)
			if character and targetRoot then
				local offset = targetRoot.Position - root.Position
				local distance = offset.Magnitude
				local range = cfg.SightRange
					* (if PlayerStateService.isFlashlightOn(player) then cfg.FlashlightSightMultiplier else 1)
				if distance <= range and distance < bestDistance then
					local inView = distance <= cfg.AwarenessRadius
						or EchoBrain.isInFieldOfView(
							forward.X,
							forward.Z,
							offset.X,
							offset.Z,
							cfg.FieldOfView
						)
					local head = character:FindFirstChild("Head")
					local aim = if head and head:IsA("BasePart") then head.Position else targetRoot.Position
					if inView and hasLineOfSight(eye, aim, character) then
						best = player
						bestDistance = distance
						bestPosition = targetRoot.Position
					end
				end
			end
		end
		return best, if best then bestDistance else nil, bestPosition
	end

	maid:give(NoiseService.subscribe(function(noise: NoiseService.Noise)
		table.insert(sounds, noise)
		if #sounds > cfg.MaxRememberedSounds then
			table.remove(sounds, 1)
		end
	end))

	local function pickSound(): number?
		local now = os.clock()
		local heard: { EchoBrain.HeardSound } = {}
		for index, sound in sounds do
			heard[index] = {
				distance = (sound.position - root.Position).Magnitude,
				loudness = sound.loudness,
				age = now - sound.time,
			}
		end
		return EchoBrain.pickSound(heard, cfg.HearingRadius, cfg.SoundMemorySeconds, cfg.MinAudibleLoudness)
	end

	local function randomPatrolPoint(): Vector3
		return params.patrolPoints[params.rng:NextInteger(1, #params.patrolPoints)]
	end

	local function nearestTargetDistance(point: Vector3): number
		local nearest = math.huge
		for _, player in params.getTargets() do
			local targetRoot = InteractionService.getRoot(player)
			if targetRoot then
				nearest = math.min(nearest, (targetRoot.Position - point).Magnitude)
			end
		end
		return nearest
	end

	local function farthestPatrolPoint(): Vector3
		local best = randomPatrolPoint()
		local bestDistance = -1
		for _, point in params.patrolPoints do
			local distance = nearestTargetDistance(point)
			if distance > bestDistance then
				best, bestDistance = point, distance
			end
		end
		return best
	end

	local function searchPoint(): Vector3
		local nearby = {}
		for _, point in params.patrolPoints do
			if (point - searchCenter).Magnitude <= cfg.SearchRadius then
				table.insert(nearby, point)
			end
		end
		if #nearby == 0 then
			return searchCenter
		end
		return nearby[params.rng:NextInteger(1, #nearby)]
	end

	-- Recovery for a hopelessly stuck Echo: move it to a patrol point no player can see.
	-- Never used to appear near players.
	local function relocateUnseen()
		local playerParams = RaycastParams.new()
		playerParams.FilterType = Enum.RaycastFilterType.Exclude
		local excluded: { Instance } = { rig.model }
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(excluded, player.Character)
			end
		end
		playerParams.FilterDescendantsInstances = excluded
		for _ = 1, 10 do
			local point = randomPatrolPoint()
			local hidden = nearestTargetDistance(point) > 40
			if hidden then
				for _, player in params.getTargets() do
					local character = player.Character
					local head = character and character:FindFirstChild("Head")
					if head and head:IsA("BasePart") then
						local up = point + Vector3.new(0, 6, 0)
						if Workspace:Raycast(head.Position, up - head.Position, playerParams) == nil then
							hidden = false
							break
						end
					end
				end
			end
			if hidden then
				mover.stop()
				rig.model:PivotTo(CFrame.new(point) * CFrame.new(0, EchoRig.RootAboveGround, 0))
				Log.warn("Echo", "Stuck repeatedly; relocated out of sight")
				return
			end
		end
		Log.warn("Echo", "Stuck repeatedly and no hidden relocation point found")
	end

	local function setState(nextState: State)
		if nextState == state then
			return
		end
		Log.debug("Echo", "%s -> %s (alert %d)", state, nextState, math.floor(alert))
		state = nextState
		stateStarted = os.clock()
		setEyes(eyeColorFor(nextState))

		if nextState == "Patrol" then
			mover.setGoal(randomPatrolPoint(), cfg.Speeds.Patrol, cfg.Path.RepathIdle)
		elseif nextState == "Listen" then
			mover.stop()
			local index = pickSound()
			if index then
				soundGoal = sounds[index].position
				table.remove(sounds, index)
			end
		elseif nextState == "Investigate" then
			local goal = soundGoal or root.Position
			mover.setGoal(goal, cfg.Speeds.Investigate, cfg.Path.RepathIdle)
		elseif nextState == "Search" then
			searchCenter = lastSeenPosition or soundGoal or root.Position
			mover.setGoal(searchCenter, cfg.Speeds.Investigate, cfg.Path.RepathIdle)
		elseif nextState == "Attack" then
			mover.stop()
			attackResolved = false
			attackHit = false
		elseif nextState == "Retreat" then
			mover.setGoal(farthestPatrolPoint(), cfg.Speeds.Retreat, cfg.Path.RepathIdle)
		elseif nextState == "Recover" or nextState == "Dormant" then
			mover.stop()
			alert = 0
			target = nil
			lastSeenPosition = nil
			soundGoal = nil
			table.clear(sounds)
		end
	end

	-- The hit lands only if the target is still close, visible and standing when the windup ends.
	local function resolveAttack()
		attackResolved = true
		attackReadyAt = os.clock() + attackCooldown
		local victim = target
		if victim == nil then
			return
		end
		local victimRoot = InteractionService.getRoot(victim)
		if victimRoot == nil or PlayerStateService.isDowned(victim) then
			return
		end
		local distance = (victimRoot.Position - root.Position).Magnitude
		if distance > cfg.AttackRange + cfg.AttackReachTolerance then
			return
		end
		if not hasLineOfSight(rig.head.Position, victimRoot.Position, victim.Character) then
			return
		end
		local result = PlayerStateService.applyDamage(victim, cfg.AttackDamage, "Echo")
		attackHit = result ~= "Ignored"
		if result == "Damaged" then
			RemoteService.notify(victim, "Something struck you. Run!", "danger")
		end
	end

	local function tick(dt: number)
		local now = os.clock()
		for index = #sounds, 1, -1 do
			if now - sounds[index].time > cfg.SoundMemorySeconds then
				table.remove(sounds, index)
			end
		end

		local seen, distance, seenPosition = perceive()
		if seen and seenPosition then
			target = seen
			-- Store a point near the floor so it makes a valid pathfinding goal.
			lastSeenPosition = seenPosition - Vector3.new(0, PLAYER_ROOT_HEIGHT, 0)
			lastSeenTime = now
		end
		alert = EchoBrain.updateAlert(alert, dt, seen ~= nil, distance, cfg.SightRange, cfg)

		local status = mover.getStatus()
		if status == "Failed" and lastStatus ~= "Failed" then
			failureStreak += 1
		elseif status == "Arrived" then
			failureStreak = 0
		end
		lastStatus = mover.getStatus()
		if failureStreak >= cfg.Path.FailuresBeforeTeleport then
			failureStreak = 0
			relocateUnseen()
		end

		local perception: EchoBrain.Perception = {
			awake = now >= awakeAt,
			stateTime = now - stateStarted,
			canSeeTarget = seen ~= nil,
			targetDistance = distance,
			timeSinceSeen = now - lastSeenTime,
			alert = alert,
			heardSound = pickSound() ~= nil,
			arrived = status == "Arrived",
			pathFailed = status == "Failed",
			attackReady = now >= attackReadyAt,
			attackHit = attackHit,
			solo = params.solo,
		}
		setState(EchoBrain.decide(state, perception, cfg))

		local lastSeen = lastSeenPosition
		if state == "Patrol" then
			if mover.getStatus() ~= "Moving" then
				mover.setGoal(randomPatrolPoint(), cfg.Speeds.Patrol, cfg.Path.RepathIdle)
			end
		elseif state == "Listen" then
			local goal = soundGoal
			if goal then
				faceTowards(goal)
			end
		elseif state == "Stalk" then
			if lastSeen then
				-- Keep its distance and watch.
				if distance == nil or distance > cfg.StalkDistance then
					mover.setGoal(lastSeen, cfg.Speeds.Stalk, cfg.Path.RepathIdle)
				else
					mover.stop()
					faceTowards(lastSeen)
				end
			end
		elseif state == "Hunt" then
			if lastSeen then
				mover.setGoal(lastSeen, chaseSpeed, cfg.Path.RepathChase)
			end
		elseif state == "Attack" then
			if lastSeen then
				faceTowards(lastSeen)
			end
			if not attackResolved and now - stateStarted >= cfg.AttackWindup then
				resolveAttack()
			end
		elseif state == "Search" then
			if mover.getStatus() ~= "Moving" then
				mover.setGoal(searchPoint(), cfg.Speeds.Investigate, cfg.Path.RepathIdle)
			end
		end

		mover.update()

		local label = debugLabel
		if label then
			label.Text = `{state}  alert {math.floor(alert)}`
		end
	end

	-- AI thread. Lives exactly as long as this Echo; destroy() stops it.
	local thread = task.spawn(function()
		local last = os.clock()
		local errors = 0
		while running do
			task.wait(cfg.AITick)
			if not running then
				break
			end
			local now = os.clock()
			local message = ""
			local ok = xpcall(tick, function(err: any)
				message = tostring(err)
			end, now - last)
			last = now
			if not ok then
				errors += 1
				Log.warn("Echo", "AI tick error: %s", message)
				if errors >= MAX_TICK_ERRORS then
					Log.warn("Echo", "Too many AI errors; stopping the Echo")
					running = false
				end
			end
		end
	end)

	local echo = {}

	function echo.destroy()
		if not running and rig.model.Parent == nil then
			return
		end
		running = false
		if coroutine.status(thread) == "suspended" then
			pcall(task.cancel, thread)
		end
		maid:clean()
	end

	function echo.wake()
		awakeAt = os.clock()
	end

	function echo.getState(): State
		return state
	end

	setEyes(EYES.Calm)
	return echo
end

return Echo
