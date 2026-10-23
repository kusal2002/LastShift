--!strict
-- Grants end-of-round rewards, at most once per player per round.
-- Phase 6 will persist credits and XP to the player's profile; until then they are kept as a
-- session total in Player attributes (SessionCredits, SessionXP) and shown on the results screen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Rewards = require(Shared.Logic.Rewards)
local Log = require(Shared.Util.Log)

local KEEP_ROUNDS = 3 -- ledgers for older rounds are dropped

local RewardService = {}

local ledgers: { [number]: Rewards.Ledger } = {}

function RewardService.grant(roundId: number, player: Player, input: Rewards.Input): Rewards.Result
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
	if isNew then
		local credits = tonumber(player:GetAttribute("SessionCredits")) or 0
		local xp = tonumber(player:GetAttribute("SessionXP")) or 0
		player:SetAttribute("SessionCredits", credits + result.Credits)
		player:SetAttribute("SessionXP", xp + result.XP)
		Log.info(
			"Rewards",
			"%s earned %d credits and %d XP in round %d",
			player.Name,
			result.Credits,
			result.XP,
			roundId
		)
	else
		Log.warn("Rewards", "Duplicate reward request for %s in round %d ignored", player.Name, roundId)
	end
	return result
end

return RewardService
