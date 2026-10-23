--!strict
-- Owns each player's survival state: stamina and sprinting, flashlight battery, health,
-- and downed/revive. Clients only send intents (sprint on/off, toggle light); the server
-- decides everything and publishes the result as attributes on the Player object
-- (attributes set by the server cannot be changed by clients).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local PlayerConfig = require(Shared.Config.Player)
local Remotes = require(Shared.Remotes)
local Stamina = require(Shared.Logic.Stamina)
local Damage = require(Shared.Logic.Damage)
local Log = require(Shared.Util.Log)
local EnemyConfig = require(Shared.Config.Enemy)
local RemoteService = require(script.Parent.RemoteService)
local InteractionService = require(script.Parent.InteractionService)
local NoiseService = require(script.Parent.NoiseService)

export type Hooks = {
	isActive: (player: Player) -> boolean, -- participant, alive, in an active round phase
	onChanged: () -> (), -- team-visible state changed (downed / revived)
}

type Entry = {
	wantsSprint: boolean,
	sprinting: boolean,
	stamina: Stamina.State,
	battery: number,
	flashlightOn: boolean,
	health: Damage.State,
	inRound: boolean,
	downedEndsAt: number?, -- bleed-out (team) or self-recovery (solo) time
	revivePrompt: ProximityPrompt?,
	light: SpotLight?,
	sprintNoiseTimer: number, -- seconds until the next sprint footstep noise
	published: { [string]: any },
}

local Names = Remotes.Names
local FLASHLIGHT_COLOR = Color3.fromRGB(255, 244, 214)

local PlayerStateService = {}

local entries: { [Player]: Entry } = {}
local soloMode = false
local hooks: Hooks = {
	isActive = function(_player: Player)
		return false
	end,
	onChanged = function() end,
}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function newEntry(): Entry
	return {
		wantsSprint = false,
		sprinting = false,
		stamina = Stamina.new(PlayerConfig.Stamina),
		battery = PlayerConfig.Flashlight.MaxBattery,
		flashlightOn = false,
		health = Damage.new(PlayerConfig.Health),
		inRound = false,
		downedEndsAt = nil,
		revivePrompt = nil,
		light = nil,
		sprintNoiseTimer = 0,
		published = {},
	}
end

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	if character == nil then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function setJumpEnabled(humanoid: Humanoid, enabled: boolean)
	humanoid.JumpPower = if enabled then StarterPlayer.CharacterJumpPower else 0
	humanoid.JumpHeight = if enabled then StarterPlayer.CharacterJumpHeight else 0
end

-- Sends only values that changed, to keep network traffic low.
local function publish(player: Player, entry: Entry)
	local values: { [string]: any } = {
		Stamina = math.floor(entry.stamina.value + 0.5),
		Battery = math.ceil(entry.battery),
		FlashlightOn = entry.flashlightOn,
		Sprinting = entry.sprinting,
		Downed = entry.health.downed,
		DownedEndsAt = entry.downedEndsAt or 0,
		SoloDowned = entry.health.downed and soloMode,
	}
	for key, value in values do
		if entry.published[key] ~= value then
			entry.published[key] = value
			player:SetAttribute(key, value)
		end
	end
end

local function setLight(entry: Entry, on: boolean)
	entry.flashlightOn = on
	local light = entry.light
	if light then
		light.Enabled = on
	end
end

-- The light lives on the server so every player sees each other's beams.
local function attachLight(entry: Entry, character: Model)
	local head = character:WaitForChild("Head", 10)
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "FlashlightAttachment"
	attachment.Position = Vector3.new(0, 0, -0.6)
	attachment.Parent = head
	local light = Instance.new("SpotLight")
	light.Name = "Flashlight"
	light.Face = Enum.NormalId.Front
	light.Range = PlayerConfig.Flashlight.Range
	light.Angle = PlayerConfig.Flashlight.Angle
	light.Brightness = PlayerConfig.Flashlight.Brightness
	light.Color = FLASHLIGHT_COLOR
	light.Shadows = true
	light.Enabled = entry.flashlightOn
	light.Parent = attachment
	entry.light = light
end

local function clearDowned(entry: Entry)
	entry.downedEndsAt = nil
	local prompt = entry.revivePrompt
	if prompt then
		prompt:Destroy()
		entry.revivePrompt = nil
	end
end

local function revive(player: Player, entry: Entry, reviver: Player?)
	entry.health = Damage.revive(entry.health, now(), PlayerConfig.Health)
	clearDowned(entry)
	local humanoid = getHumanoid(player)
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = entry.health.health
		setJumpEnabled(humanoid, true)
	end
	RemoteService.notify(player, "You're back on your feet.", "success")
	if reviver then
		RemoteService.notify(reviver, `You revived {player.DisplayName}.`, "success")
		local root = InteractionService.getRoot(player)
		if root then
			NoiseService.emit(root.Position, EnemyConfig.Noise.Revive, "Revive")
		end
	end
	publish(player, entry)
	hooks.onChanged()
end

local function kill(player: Player, entry: Entry)
	clearDowned(entry)
	entry.health = { health = 0, downed = false, downedUsed = true, protectedUntil = now() }
	local humanoid = getHumanoid(player)
	if humanoid then
		humanoid.Health = 0 -- RoundService marks the player Dead from Humanoid.Died
	end
	publish(player, entry)
	hooks.onChanged()
end

local function enterDowned(player: Player, entry: Entry)
	setLight(entry, false)
	entry.wantsSprint = false
	local humanoid = getHumanoid(player)
	if humanoid then
		humanoid.Health = 1 -- kept above zero so the character stays alive while downed
		setJumpEnabled(humanoid, false)
	end

	if soloMode then
		entry.downedEndsAt = now() + PlayerConfig.Downed.SoloRecoverSeconds
		RemoteService.notify(player, "You're down. Catch your breath.", "danger")
	else
		entry.downedEndsAt = now() + PlayerConfig.Downed.BleedOutSeconds
		local root = InteractionService.getRoot(player)
		if root then
			local prompt = InteractionService.createPrompt(root, {
				ActionText = "Revive",
				ObjectText = player.DisplayName,
				HoldDuration = PlayerConfig.Downed.ReviveHoldSeconds,
				MaxDistance = PlayerConfig.Downed.ReviveDistance,
			}, function(reviver: Player)
				if reviver == player or PlayerStateService.isDowned(reviver) then
					return
				end
				local current = entries[player]
				if current and current.health.downed then
					revive(player, current, reviver)
				end
			end)
			prompt.Name = "RevivePrompt"
			entry.revivePrompt = prompt
		end
		RemoteService.notify(player, "You're down! A teammate can revive you.", "danger")
	end
	publish(player, entry)
	hooks.onChanged()
end

-- Resets survival state. Only touches the humanoid if it is alive.
local function resetEntry(player: Player, entry: Entry, inRound: boolean)
	clearDowned(entry)
	entry.wantsSprint = false
	entry.sprinting = false
	entry.stamina = Stamina.new(PlayerConfig.Stamina)
	entry.battery = PlayerConfig.Flashlight.MaxBattery
	entry.health = Damage.new(PlayerConfig.Health)
	entry.inRound = inRound
	setLight(entry, false)
	local humanoid = getHumanoid(player)
	if humanoid and humanoid.Health > 0 then
		humanoid.MaxHealth = PlayerConfig.Health.Max
		humanoid.Health = PlayerConfig.Health.Max
		humanoid.WalkSpeed = PlayerConfig.WalkSpeed
		setJumpEnabled(humanoid, true)
	end
	publish(player, entry)
end

local function update(dt: number)
	local current = now()
	for player, entry in entries do
		local humanoid = getHumanoid(player)
		local root = InteractionService.getRoot(player)
		if humanoid and root then
			local velocity = root.AssemblyLinearVelocity
			local moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > PlayerConfig.Stamina.MovingSpeed
			local wantsSprint = entry.wantsSprint and not entry.health.downed
			entry.stamina, entry.sprinting =
				Stamina.step(entry.stamina, dt, wantsSprint, moving, PlayerConfig.Stamina)

			-- Sprinting is loud: the Echo can hear running footsteps. Walking is silent.
			if entry.sprinting and entry.inRound then
				entry.sprintNoiseTimer -= dt
				if entry.sprintNoiseTimer <= 0 then
					entry.sprintNoiseTimer = EnemyConfig.Noise.SprintInterval
					NoiseService.emit(root.Position, EnemyConfig.Noise.Sprint, "Sprint")
				end
			else
				entry.sprintNoiseTimer = 0
			end

			if entry.flashlightOn and entry.inRound then
				entry.battery = math.max(0, entry.battery - PlayerConfig.Flashlight.DrainPerSecond * dt)
				if entry.battery <= 0 then
					setLight(entry, false)
					RemoteService.notify(
						player,
						"Flashlight battery is dead. Find a charging station.",
						"warn"
					)
				end
			end

			local speed = if entry.health.downed
				then PlayerConfig.DownedSpeed
				elseif entry.sprinting then PlayerConfig.SprintSpeed
				else PlayerConfig.WalkSpeed
			if humanoid.WalkSpeed ~= speed then
				humanoid.WalkSpeed = speed
			end

			local endsAt = entry.downedEndsAt
			if entry.health.downed and endsAt ~= nil and current >= endsAt then
				if soloMode then
					revive(player, entry, nil)
				else
					RemoteService.notify(player, "You bled out.", "danger")
					kill(player, entry)
				end
			end
		end
		publish(player, entry)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local entry = entries[player]
	if entry == nil then
		return
	end
	-- A new character always starts healthy; the old one (and its revive prompt) is gone.
	clearDowned(entry)
	entry.health = Damage.new(PlayerConfig.Health)
	entry.light = nil
	setLight(entry, false)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.MaxHealth = PlayerConfig.Health.Max
		humanoid.Health = PlayerConfig.Health.Max
		humanoid.WalkSpeed = PlayerConfig.WalkSpeed
	end
	attachLight(entry, character)
	publish(player, entry)
end

local function onPlayerAdded(player: Player)
	entries[player] = newEntry()
	player.CharacterAdded:Connect(function(character: Model)
		onCharacterAdded(player, character)
	end)
	local character = player.Character
	if character then
		task.spawn(onCharacterAdded, player, character)
	end
end

function PlayerStateService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		local entry = entries[player]
		if entry then
			clearDowned(entry)
			entries[player] = nil
		end
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

function PlayerStateService.Start()
	RemoteService.listen(
		Names.SprintRequest,
		{ capacity = 10, perSecond = 5 },
		function(player: Player, wants: any)
			if typeof(wants) ~= "boolean" then
				return
			end
			local entry = entries[player]
			if entry then
				entry.wantsSprint = wants
			end
		end
	)

	RemoteService.listen(Names.FlashlightToggle, { capacity = 4, perSecond = 3 }, function(player: Player)
		local entry = entries[player]
		if entry == nil or entry.health.downed then
			return
		end
		if not entry.flashlightOn and entry.battery <= 0 then
			RemoteService.notify(player, "Flashlight battery is dead. Find a charging station.", "warn")
			return
		end
		setLight(entry, not entry.flashlightOn)
		publish(player, entry)
	end)

	-- Server-lifetime clock for survival state.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < PlayerConfig.TickInterval then
			return
		end
		local step = accumulator
		accumulator = 0
		update(step)
	end)
end

function PlayerStateService.setHooks(newHooks: Hooks)
	hooks = newHooks
end

-- Called when Investigation starts. Solo rounds get self-recovery instead of revives.
function PlayerStateService.beginRound(players: { Player })
	soloMode = #players == 1
	for _, player in players do
		local entry = entries[player]
		if entry then
			resetEntry(player, entry, true)
		end
	end
end

-- Player died, escaped or left the round.
function PlayerStateService.removeFromRound(player: Player)
	local entry = entries[player]
	if entry then
		resetEntry(player, entry, false)
	end
end

function PlayerStateService.endRound()
	for player, entry in entries do
		resetEntry(player, entry, false)
	end
end

-- The only way to hurt a player. Returns what happened.
function PlayerStateService.applyDamage(player: Player, amount: number, source: string): Damage.HitResult
	local entry = entries[player]
	if entry == nil or not entry.inRound or not hooks.isActive(player) then
		return "Ignored"
	end
	local result: Damage.HitResult, nextState =
		Damage.resolve(entry.health, amount, now(), PlayerConfig.Health)
	Log.debug("Player", "%s hit for %s by %s: %s", player.Name, tostring(amount), source, result)
	if result == "Damaged" then
		entry.health = nextState
		local humanoid = getHumanoid(player)
		if humanoid then
			humanoid.Health = nextState.health
		end
		return "Damaged"
	elseif result == "Downed" then
		entry.health = nextState
		enterDowned(player, entry)
		return "Downed"
	elseif result == "Killed" then
		kill(player, entry)
		return "Killed"
	end
	return "Ignored"
end

function PlayerStateService.isDowned(player: Player): boolean
	local entry = entries[player]
	return entry ~= nil and entry.health.downed
end

function PlayerStateService.isSprinting(player: Player): boolean
	local entry = entries[player]
	return entry ~= nil and entry.sprinting
end

-- A lit flashlight makes the player easier for the Echo to spot.
function PlayerStateService.isFlashlightOn(player: Player): boolean
	local entry = entries[player]
	return entry ~= nil and entry.flashlightOn
end

function PlayerStateService.getBattery(player: Player): number
	local entry = entries[player]
	return if entry then entry.battery else 0
end

function PlayerStateService.setBattery(player: Player, value: number)
	local entry = entries[player]
	if entry then
		entry.battery = math.clamp(value, 0, PlayerConfig.Flashlight.MaxBattery)
		publish(player, entry)
	end
end

return PlayerStateService
