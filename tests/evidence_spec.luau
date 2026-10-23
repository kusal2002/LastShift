-- Tests for evidence data, rewards and the grant-once ledger.
local H = require("./harness")
local Evidence = require("../src/shared/Config/Evidence")
local Anomalies = require("../src/shared/Config/Anomalies")
local Economy = require("../src/shared/Config/Economy")
local Rewards = require("../src/shared/Logic/Rewards")

-- Evidence data -------------------------------------------------------------
H.test("evidence ids are unique and point at real anomalies", function()
	local seen = {}
	for _, item in Evidence.Items do
		H.eq(seen[item.Id], nil, `duplicate id {item.Id}`)
		seen[item.Id] = true
		H.ok(Anomalies.ById[item.Anomaly] ~= nil, `{item.Id} names unknown anomaly {item.Anomaly}`)
		H.ok(item.Reward > 0, `{item.Id} has no reward`)
		H.ok(#item.Description > 0, `{item.Id} has no description`)
		H.eq(Evidence.ById[item.Id], item)
	end
end)

H.test("every anomaly has enough evidence for a round", function()
	for _, profile in Anomalies.List do
		local standard, risky = 0, 0
		for _, item in Evidence.Items do
			if item.Anomaly == profile.Id then
				if item.Risky then
					risky += 1
				else
					standard += 1
				end
			end
		end
		H.ok(standard >= Evidence.SpawnCount, `{profile.Id} needs {Evidence.SpawnCount} standard items`)
		H.ok(risky >= 1, `{profile.Id} needs a risky item`)
	end
	H.ok(Evidence.Required <= Evidence.SpawnCount, "required evidence must be findable")
end)

H.test("evidence descriptions never name the anomaly", function()
	for _, item in Evidence.Items do
		for _, profile in Anomalies.List do
			H.eq(string.find(string.lower(item.Description), string.lower(profile.Id), 1, true), nil, item.Id)
		end
	end
end)

-- Rewards -------------------------------------------------------------------
local function input(overrides: { [string]: any }?): any
	local base = {
		objectivesCompleted = 3,
		evidenceRewards = { 10, 10 },
		classification = "None",
		ending = "Abort",
		transmitCompleted = false,
		escaped = true,
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

H.test("abort and escape pays objectives, evidence and extraction", function()
	local result = Rewards.calculate(input(), Economy)
	H.eq(result.Credits, 3 * 20 + 20 + 50)
end)

H.test("correct classification multiplies objective and evidence credits", function()
	local correct = Rewards.calculate(input({ classification = "Correct" }), Economy)
	local wrong = Rewards.calculate(input({ classification = "Incorrect" }), Economy)
	H.eq(correct.Credits, math.floor(80 * 1.5) + 50)
	H.eq(wrong.Credits, math.floor(80 * 0.75) + 50)
	H.ok(correct.XP > wrong.XP)
end)

H.test("a completed transmission pays more than aborting", function()
	local transmit = Rewards.calculate(input({ ending = "Transmit", transmitCompleted = true }), Economy)
	local abort = Rewards.calculate(input({ ending = "Abort" }), Economy)
	H.ok(transmit.Credits > abort.Credits)
	local cutShort = Rewards.calculate(input({ ending = "Transmit", transmitCompleted = false }), Economy)
	H.eq(cutShort.Credits, abort.Credits, "no transmit bonus unless it finished")
end)

H.test("players who didn't escape keep a share", function()
	local result = Rewards.calculate(input({ escaped = false }), Economy)
	H.eq(result.Credits, math.floor(80 * 0.3))
	H.ok(result.XP >= Economy.XP.Participation)
end)

H.test("breakdown lines add up to the total", function()
	for _, overrides in
		{
			{},
			{ classification = "Correct", ending = "Transmit", transmitCompleted = true },
			{ classification = "Incorrect", escaped = false },
		}
	do
		local result = Rewards.calculate(input(overrides), Economy)
		local sum = 0
		for _, line in result.Breakdown do
			sum += line.Amount
		end
		H.eq(sum, result.Credits)
	end
end)

H.test("rewards are granted at most once per key", function()
	local ledger = Rewards.newLedger()
	local calls = 0
	local function compute()
		calls += 1
		return { Credits = 100, XP = 10, Breakdown = {} }
	end
	local first, isNew = Rewards.grantOnce(ledger, "7:123", compute)
	local second, isNewAgain = Rewards.grantOnce(ledger, "7:123", compute)
	H.ok(isNew)
	H.eq(isNewAgain, false)
	H.eq(first, second)
	H.eq(calls, 1)
	local _, otherNew = Rewards.grantOnce(ledger, "8:123", compute)
	H.ok(otherNew, "a new round is a new key")
end)

return H
