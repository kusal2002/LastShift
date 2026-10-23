--!strict
-- Objective C: recover evidence of what is in the station.
-- Places Evidence.SpawnCount items, all linked to this round's anomaly, at random evidence
-- spots; Evidence.Required of them complete the objective. One optional risky item sits near
-- the Echo's lair: worth more, and loud to take.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Evidence = require(Shared.Config.Evidence)
local Tags = require(Shared.Config.Tags)
local Types = require(Shared.Types)
local Selection = require(Shared.Logic.Selection)
local Maid = require(Shared.Util.Maid)
local Log = require(Shared.Util.Log)

local Services = script.Parent.Parent.Services
local MapService = require(Services.MapService)
local InteractionService = require(Services.InteractionService)
local NoiseService = require(Services.NoiseService)
local ObjectiveTypes = require(script.Parent.ObjectiveTypes)

local ID = "evidence"
local LABEL = "Recover evidence"
local PAPER_COLOR = Color3.fromRGB(214, 206, 180)
local GLOW_COLOR = Color3.fromRGB(126, 205, 140)
local RISKY_GLOW_COLOR = Color3.fromRGB(230, 90, 70)

local EvidenceObjective = {}

local function itemsFor(anomalyId: string, risky: boolean): { Evidence.EvidenceDef }
	local list = {}
	for _, item in Evidence.Items do
		if item.Anomaly == anomalyId and item.Risky == risky then
			table.insert(list, item)
		end
	end
	return list
end

function EvidenceObjective.new(ctx: ObjectiveTypes.Context): ObjectiveTypes.Objective
	local spots = Selection.pickN(MapService.getTagged(Tags.EvidenceSpawn), Evidence.SpawnCount, ctx.nextInt)
	local items = Selection.pickN(itemsFor(ctx.anomalyId, false), Evidence.SpawnCount, ctx.nextInt)
	local placed = math.min(#spots, #items)
	if placed == 0 then
		Log.warn(
			"Objective",
			"Evidence skipped: no %s spots or no evidence for %s",
			Tags.EvidenceSpawn,
			ctx.anomalyId
		)
		return ObjectiveTypes.skipped(ID, "Evidence", LABEL)
	end
	-- Never require more than can actually be found.
	local required = math.min(Evidence.Required, placed)
	local collected = 0
	local maid = Maid.new()

	local function place(spot: BasePart, item: Evidence.EvidenceDef)
		local part = Instance.new("Part")
		part.Name = "Evidence"
		part.Size = Vector3.new(1.2, 0.2, 1.6)
		part.Color = PAPER_COLOR
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CFrame = spot.CFrame
		part.Parent = ctx.roundFolder
		maid:give(part)
		local glow = Instance.new("PointLight")
		glow.Color = if item.Risky then RISKY_GLOW_COLOR else GLOW_COLOR
		glow.Range = 5
		glow.Brightness = 0.6
		glow.Parent = part

		InteractionService.createPrompt(part, {
			ActionText = "Examine",
			ObjectText = item.DisplayName,
			HoldDuration = Evidence.HoldDuration,
			MaxDistance = Evidence.InteractDistance,
		}, function(player: Player)
			if part.Parent == nil then
				return
			end
			part:Destroy()
			collected += 1
			ctx.recordEvidence(item)
			if item.Risky then
				NoiseService.emit(spot.Position, Evidence.RiskyNoise, "RiskyEvidence")
				ctx.notify(player, `Recovered {item.DisplayName}. That was loud.`, "warn")
			else
				ctx.notify(player, `Evidence logged: {item.DisplayName}. Check your notebook.`, "success")
			end
			ctx.markChanged()
		end)
	end

	for index = 1, placed do
		place(spots[index], items[index])
	end

	local riskySpot = MapService.getTagged(Tags.RiskyEvidenceSpawn)[1]
	local riskyItem = Selection.pickOne(itemsFor(ctx.anomalyId, true), ctx.nextInt)
	if riskySpot and riskyItem then
		place(riskySpot, riskyItem)
	end

	return {
		Id = ID,
		getView = function(): Types.ObjectiveView
			local complete = collected >= required
			return {
				Id = ID,
				Kind = "Evidence",
				Label = `{LABEL} ({math.min(collected, required)}/{required})`,
				Detail = if complete then "Enough to file a report" else "Search the station",
				Complete = complete,
			}
		end,
		isComplete = function()
			return collected >= required
		end,
		onPlayerRemoved = function(_player: Player) end,
		destroy = function()
			maid:clean()
		end,
	}
end

return EvidenceObjective
