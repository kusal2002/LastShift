--!strict
-- The shape every objective module returns, and the context ObjectiveService gives it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local ObjectivesConfig = require(Shared.Config.Objectives)

export type NotifyKind = "info" | "success" | "warn" | "danger"

export type Context = {
	nextInt: (number, number) -> number, -- seeded random whole number in [a, b]
	roundFolder: Folder, -- parent for per-round objects; cleared on reset
	markChanged: () -> (), -- call after any state change players should see
	notify: (player: Player, text: string, kind: NotifyKind?) -> (),
	recordEvidence: (item: ObjectivesConfig.EvidenceDef) -> (),
}

export type Objective = {
	Id: string,
	getView: () -> Types.ObjectiveView,
	isComplete: () -> boolean,
	onPlayerRemoved: (player: Player) -> (), -- died, left or escaped
	destroy: () -> (),
}

local ObjectiveTypes = {}

-- Used when the map lacks the parts an objective needs: it counts as done so the round
-- can never get stuck, and the problem is logged.
function ObjectiveTypes.skipped(id: string, kind: string, label: string): Objective
	return {
		Id = id,
		getView = function(): Types.ObjectiveView
			return { Id = id, Kind = kind, Label = label, Detail = "Unavailable on this map", Complete = true }
		end,
		isComplete = function()
			return true
		end,
		onPlayerRemoved = function(_player: Player) end,
		destroy = function() end,
	}
end

return ObjectiveTypes
