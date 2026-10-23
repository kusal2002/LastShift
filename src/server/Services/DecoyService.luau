--!strict
-- Noise makers: a pickup that a player can set down to beep loudly a few seconds later,
-- pulling the Echo away. The Listener is the most sensitive to them. Carrying is tracked on
-- the server (Player attribute "HasDecoy"); clients only ask to place it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local DirectorConfig = require(Shared.Config.Director)
local Tags = require(Shared.Config.Tags)
local Remotes = require(Shared.Remotes)
local Selection = require(Shared.Logic.Selection)
local Maid = require(Shared.Util.Maid)
local MapService = require(script.Parent.MapService)
local InteractionService = require(script.Parent.InteractionService)
local NoiseService = require(script.Parent.NoiseService)
local RemoteService = require(script.Parent.RemoteService)
local AudioEventService = require(script.Parent.AudioEventService)

local DECOY_COLOR = Color3.fromRGB(40, 44, 40)
local LIGHT_COLOR = Color3.fromRGB(255, 120, 60)
local BEEP_RADIUS = 80

local DecoyService = {}

local maid = Maid.new()
local getPlayers: () -> { Player } = function()
	return {}
end

local function makeDevice(cframe: CFrame): Part
	local part = Instance.new("Part")
	part.Name = "NoiseMaker"
	part.Size = Vector3.new(0.8, 0.5, 0.8)
	part.Color = DECOY_COLOR
	part.Material = Enum.Material.Metal
	part.Anchored = true
	part.CanCollide = false
	part.CFrame = cframe
	local light = Instance.new("PointLight")
	light.Color = LIGHT_COLOR
	light.Range = 4
	light.Brightness = 0.8
	light.Parent = part
	part.Parent = MapService.getRoundFolder()
	return part
end

local function setCarrying(player: Player, carrying: boolean)
	player:SetAttribute("HasDecoy", carrying)
end

local function place(player: Player)
	if player:GetAttribute("HasDecoy") ~= true then
		return
	end
	local allowed = InteractionService.checkGate(player)
	local root = InteractionService.getRoot(player)
	local character = player.Character
	if not allowed or root == nil or character == nil then
		return
	end
	-- Find the floor under the player.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -10, 0), params)
	local floor = if hit then hit.Position else root.Position - Vector3.new(0, 3, 0)
	setCarrying(player, false)

	local position = floor + Vector3.new(0, 0.25, 0)
	local device = makeDevice(CFrame.new(position))
	RemoteService.notify(player, "Noise maker set. Get clear before it goes off.", "info")

	local config = DirectorConfig.Decoy
	maid:give(task.delay(config.ArmSeconds, function()
		for pulse = 1, config.Pulses do
			if device.Parent == nil then
				return
			end
			NoiseService.emit(position, config.Loudness, "Decoy")
			AudioEventService.playNear(getPlayers(), "DecoyBeep", position, BEEP_RADIUS)
			if pulse < config.Pulses then
				task.wait(config.PulseInterval)
			end
		end
		device:Destroy()
	end))
end

function DecoyService.Start()
	RemoteService.listen(Remotes.Names.DecoyUse, { capacity = 2, perSecond = 1 }, function(player: Player)
		place(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		setCarrying(player, false)
	end)
end

function DecoyService.beginRound(
	count: number,
	nextInt: (number, number) -> number,
	players: () -> { Player }
)
	DecoyService.endRound()
	getPlayers = players
	for _, spot in Selection.pickN(MapService.getTagged(Tags.DecoySpawn), count, nextInt) do
		local device = makeDevice(spot.CFrame)
		maid:give(device)
		local prompt = InteractionService.createPrompt(device, {
			ActionText = "Take",
			ObjectText = "Noise Maker",
			MaxDistance = DirectorConfig.Decoy.PickupDistance,
		}, function(player: Player)
			if device.Parent == nil then
				return
			end
			if player:GetAttribute("HasDecoy") == true then
				RemoteService.notify(player, "You can only carry one noise maker.", "warn")
				return
			end
			device:Destroy()
			setCarrying(player, true)
			RemoteService.notify(
				player,
				"Noise maker taken. Press G (or DECOY) to set it down as a distraction.",
				"info"
			)
		end)
		maid:give(prompt)
	end
end

-- Player died, escaped or left: anything they carried is lost.
function DecoyService.removePlayer(player: Player)
	setCarrying(player, false)
end

function DecoyService.endRound()
	maid:clean()
	for _, player in Players:GetPlayers() do
		setCarrying(player, false)
	end
end

return DecoyService
