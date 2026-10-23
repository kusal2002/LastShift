--!strict
-- Grants end-of-round rewards, at most once per player per round, and records them in the
-- player's saved profile (credits, XP, stats, casebook) through ProfileService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Rewards = require(Shared.Logic.Rewards)
local Log = require(Shared.Util.Log)
local ProfileService = require(script.Parent.ProfileService)

local KEEP_ROUNDS = 3 -- ledgers for older rounds are dropped

export type RoundContext = {
	anomalyId: string,
	evidenceIds: { string }, -- evidence the team recovered this round
}

local RewardService = {}

local ledgers: { [number]: Rewards.Ledger } = {}

function RewardService.grant(
	roundId: number,
	player: Player,
	input: Rewards.Input,
	context: RoundContext
): Rewards.Result
	for id in table.clone(ledgers) do
		if id < roundId - KEEP_ROUNDS then
			ledgers[id] = nil
		end
	end
	local ledger = ledgers[roundId]
	if ledger == nil then
		ledger = Rewards.newLedger()
		ledgers[roundId] = ledger
	end

	local result, isNew = Rewards.grantOnce(ledger, tostring(player.UserId), function()
		return Rewards.calculate(input, Economy)
	end)
	if not isNew then
		Log.warn("Rewards", "Duplicate reward request for %s in round %d ignored", player.Name, roundId)
		return result
	end

	Log.info(
		"Rewards",
		"%s earned %d credits and %d XP in round %d",
		player.Name,
		result.Credits,
		result.XP,
		roundId
	)
	ProfileService.applyRound(player, {
		credits = result.Credits,
		xp = result.XP,
		escaped = input.escaped,
		transmitted = input.ending == "Transmit" and input.transmitCompleted,
		anomalyId = context.anomalyId,
		correctReport = input.classification == "Correct",
		evidenceIds = context.evidenceIds,
	})
	return result
end

return RewardService
