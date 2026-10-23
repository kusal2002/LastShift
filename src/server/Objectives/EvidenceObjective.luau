--!strict
-- Objective C: find and examine one piece of evidence placed at a random evidence spot.
-- Phase 1 uses a placeholder pool; Phase 5 links evidence to the active anomaly.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Objectives).Evidence
local Tags = require(Shared.Config.Tags)
local Types = require(Shared.Types)
local Selection = require(Shared.Logic.Selection)
local Log = require(Shared.Util.Log)

local Services = script.Parent.Parent.Services
local MapService = require(Services.MapService)
local InteractionService = require(Services.InteractionService)
local ObjectiveTypes = require(script.Parent.ObjectiveTypes)

local ID = "evidence"
local LABEL = "Recover evidence of the signal"

local EvidenceObjective = {}

function EvidenceObjective.new(ctx: ObjectiveTypes.Context): ObjectiveTypes.Objective
	local foundSpot = Selection.pickOne(MapService.getTagged(Tags.EvidenceSpawn), ctx.nextInt)
	local foundItem = Selection.pickOne(Config.Items, ctx.nextInt)
	if foundSpot == nil or foundItem == nil then
		Log.warn("Objective", "Evidence skipped: map needs %s parts", Tags.EvidenceSpawn)
		return ObjectiveTypes.skipped(ID, "Evidence", LABEL)
	end
	local spot: BasePart = foundSpot
	local item = foundItem
	local complete = false

	local part = Instance.new("Part")
	part.Name = "Evidence"
	part.Size = Vector3.new(1.2, 0.2, 1.6)
	part.Color = Color3.fromRGB(214, 206, 180)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CFrame = spot.CFrame
	part.Parent = ctx.roundFolder
	-- A faint glow so the item is findable in the dark.
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(126, 205, 140)
	glow.Range = 5
	glow.Brightness = 0.6
	glow.Parent = part

	InteractionService.createPrompt(part, {
		ActionText = "Examine",
		ObjectText = item.DisplayName,
		HoldDuration = Config.HoldDuration,
		MaxDistance = Config.InteractDistance,
	}, function(player: Player)
		if complete then
			return
		end
		complete = true
		ctx.recordEvidence(item)
		part:Destroy()
		ctx.notify(player, `Evidence logged: {item.DisplayName}. "{item.Description}"`, "success")
		ctx.markChanged()
	end)

	return {
		Id = ID,
		getView = function(): Types.ObjectiveView
			return {
				Id = ID,
				Kind = "Evidence",
				Label = LABEL,
				Detail = if complete then item.DisplayName else "Search the station",
				Complete = complete,
			}
		end,
		isComplete = function()
			return complete
		end,
		onPlayerRemoved = function(_player: Player) end,
		destroy = function()
			part:Destroy()
		end,
	}
end

return EvidenceObjective
