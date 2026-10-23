--!strict
-- Objective A: pick up a fuse from one of several spots and insert it into the breaker panel.
-- The server alone tracks who carries the fuse. If the carrier dies or leaves, the fuse
-- returns to where it was found.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Objectives).Fuse
local Tags = require(Shared.Config.Tags)
local Types = require(Shared.Types)
local Selection = require(Shared.Logic.Selection)
local Maid = require(Shared.Util.Maid)
local Log = require(Shared.Util.Log)

local Services = script.Parent.Parent.Services
local MapService = require(Services.MapService)
local InteractionService = require(Services.InteractionService)
local NoiseService = require(Services.NoiseService)
local EnemyConfig = require(Shared.Config.Enemy)
local ObjectiveTypes = require(script.Parent.ObjectiveTypes)

local ID = "fuse"
local LABEL = "Replace the blown fuse"
local FUSE_COLOR = Color3.fromRGB(255, 176, 59)
local BROKEN_PANEL_COLOR = Color3.fromRGB(120, 44, 38)

local FuseObjective = {}

function FuseObjective.new(ctx: ObjectiveTypes.Context): ObjectiveTypes.Objective
	local foundSpawn = Selection.pickOne(MapService.getTagged(Tags.FuseSpawn), ctx.nextInt)
	local foundPanel = Selection.pickOne(MapService.getTagged(Tags.FusePanel), ctx.nextInt)
	if foundSpawn == nil or foundPanel == nil then
		Log.warn(
			"Objective",
			"Fuse objective skipped: map needs %s and %s parts",
			Tags.FuseSpawn,
			Tags.FusePanel
		)
		return ObjectiveTypes.skipped(ID, "Fuse", LABEL)
	end
	local spawnPoint: BasePart = foundSpawn
	local panel: BasePart = foundPanel

	local maid = Maid.new()
	local complete = false
	local carrier: Player? = nil
	local carriedVisual: BasePart? = nil
	local fusePart: BasePart? = nil
	local originalPanelColor = panel.Color
	panel.Color = BROKEN_PANEL_COLOR

	local function clearVisual()
		if carriedVisual then
			carriedVisual:Destroy()
			carriedVisual = nil
		end
	end

	-- Cosmetic only: a small glowing fuse welded to the carrier.
	local function attachVisual(player: Player)
		clearVisual()
		local character = player.Character
		local root = InteractionService.getRoot(player)
		if character == nil or root == nil then
			return
		end
		local visual = Instance.new("Part")
		visual.Name = "CarriedFuse"
		visual.Size = Vector3.new(0.5, 1, 0.5)
		visual.Color = FUSE_COLOR
		visual.Material = Enum.Material.Neon
		visual.CanCollide = false
		visual.CanQuery = false
		visual.CanTouch = false
		visual.Massless = true
		visual.CFrame = root.CFrame * CFrame.new(0.9, -0.4, -0.6)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = visual
		weld.Parent = visual
		visual.Parent = character
		carriedVisual = visual
	end

	local function spawnFuse()
		if fusePart ~= nil or complete then
			return
		end
		local part = Instance.new("Part")
		part.Name = "Fuse"
		part.Size = Vector3.new(0.8, 1.6, 0.8)
		part.Color = FUSE_COLOR
		part.Material = Enum.Material.Neon
		part.Anchored = true
		part.CanCollide = false
		part.CFrame = spawnPoint.CFrame
		part.Parent = ctx.roundFolder
		fusePart = part

		InteractionService.createPrompt(part, {
			ActionText = "Pick up",
			ObjectText = "Fuse",
			MaxDistance = Config.PickupDistance,
		}, function(player: Player)
			if complete or carrier ~= nil or fusePart ~= part then
				return
			end
			carrier = player
			fusePart = nil
			part:Destroy()
			attachVisual(player)
			ctx.notify(player, "Fuse acquired. Find the breaker panel.", "info")
			ctx.markChanged()
		end)
	end

	local panelPrompt: ProximityPrompt
	panelPrompt = InteractionService.createPrompt(panel, {
		ActionText = "Insert fuse",
		ObjectText = "Breaker Panel",
		HoldDuration = Config.InsertHoldDuration,
		MaxDistance = Config.InsertDistance,
	}, function(player: Player)
		if complete then
			return
		end
		if carrier ~= player then
			ctx.notify(player, "The breaker panel needs a fuse.", "warn")
			return
		end
		complete = true
		carrier = nil
		clearVisual()
		panelPrompt.Enabled = false
		panel.Color = FUSE_COLOR
		NoiseService.emit(panel.Position, EnemyConfig.Noise.FuseInsert, "FuseInsert") -- the breaker slams on
		ctx.notify(player, "Breaker restored. Relay power is back.", "success")
		ctx.markChanged()
	end)
	maid:give(panelPrompt)

	spawnFuse()

	return {
		Id = ID,
		getView = function(): Types.ObjectiveView
			local holder = carrier
			local detail = if complete
				then "Breaker restored"
				elseif holder then `Carried by {holder.DisplayName}`
				else "Find a spare fuse"
			return { Id = ID, Kind = "Fuse", Label = LABEL, Detail = detail, Complete = complete }
		end,
		isComplete = function()
			return complete
		end,
		onPlayerRemoved = function(player: Player)
			if carrier == player then
				carrier = nil
				clearVisual()
				spawnFuse()
				ctx.markChanged()
			end
		end,
		destroy = function()
			maid:clean()
			clearVisual()
			if fusePart then
				fusePart:Destroy()
				fusePart = nil
			end
			panel.Color = originalPanelColor
		end,
	}
end

return FuseObjective
