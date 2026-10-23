--!strict
-- Creates the round's objectives, tracks completion and collected evidence, and tears
-- everything down between rounds. RoundService decides what happens when all are done.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local ObjectivesConfig = require(Shared.Config.Objectives)

local Objectives = script.Parent.Parent.Objectives
local ObjectiveTypes = require(Objectives.ObjectiveTypes)
local MapService = require(script.Parent.MapService)
local RemoteService = require(script.Parent.RemoteService)

type Factory = { new: (ObjectiveTypes.Context) -> ObjectiveTypes.Objective }

-- Phase 1 always uses all three. Later phases pick from a larger pool.
local FACTORIES: { Factory } = {
	require(Objectives.FuseObjective) :: any,
	require(Objectives.CalibrationObjective) :: any,
	require(Objectives.EvidenceObjective) :: any,
}

export type BeginParams = {
	rng: Random,
	onChanged: () -> (),
	onAllComplete: () -> (),
}

local ObjectiveService = {}

local active: { ObjectiveTypes.Objective } = {}
local evidence: { ObjectivesConfig.EvidenceDef } = {}
local allDoneReported = false

function ObjectiveService.allComplete(): boolean
	if #active == 0 then
		return false
	end
	for _, objective in active do
		if not objective.isComplete() then
			return false
		end
	end
	return true
end

function ObjectiveService.reset()
	for _, objective in active do
		objective.destroy()
	end
	table.clear(active)
	table.clear(evidence)
	allDoneReported = false
	MapService.clearRoundObjects()
end

function ObjectiveService.begin(params: BeginParams)
	ObjectiveService.reset()
	local context: ObjectiveTypes.Context = {
		nextInt = function(low: number, high: number): number
			return params.rng:NextInteger(low, high)
		end,
		roundFolder = MapService.getRoundFolder(),
		markChanged = function()
			params.onChanged()
			if not allDoneReported and ObjectiveService.allComplete() then
				allDoneReported = true
				task.defer(params.onAllComplete)
			end
		end,
		notify = RemoteService.notify,
		recordEvidence = function(item: ObjectivesConfig.EvidenceDef)
			table.insert(evidence, item)
		end,
	}
	for _, factory in FACTORIES do
		table.insert(active, factory.new(context))
	end
end

function ObjectiveService.getViews(): { Types.ObjectiveView }
	local views = {}
	for _, objective in active do
		table.insert(views, objective.getView())
	end
	return views
end

function ObjectiveService.completedCount(): number
	local count = 0
	for _, objective in active do
		if objective.isComplete() then
			count += 1
		end
	end
	return count
end

function ObjectiveService.total(): number
	return #active
end

function ObjectiveService.getEvidenceNames(): { string }
	local names = {}
	for _, item in evidence do
		table.insert(names, item.DisplayName)
	end
	return names
end

function ObjectiveService.onPlayerRemoved(player: Player)
	for _, objective in active do
		objective.onPlayerRemoved(player)
	end
end

return ObjectiveService
