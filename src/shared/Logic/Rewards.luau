--!strict
-- Reward calculation and an idempotent ledger. Pure: no Roblox APIs.
export type Classification = "Correct" | "Incorrect" | "None"
export type Ending = "Transmit" | "Abort" | "None"

export type Input = {
	objectivesCompleted: number,
	evidenceRewards: { number }, -- reward value of each recovered evidence item
	classification: Classification,
	ending: Ending,
	transmitCompleted: boolean,
	escaped: boolean,
}

export type Config = {
	Credits: {
		PerObjective: number,
		Extraction: number,
		TransmitCompleted: number,
		Abort: number,
		NotEscapedFactor: number,
	},
	ClassificationMultiplier: { Correct: number, Incorrect: number, None: number },
	XP: {
		Participation: number,
		PerObjective: number,
		PerEvidence: number,
		Extraction: number,
		CorrectClassification: number,
		TransmitCompleted: number,
	},
}

export type Line = { Label: string, Amount: number }
export type Result = { Credits: number, XP: number, Breakdown: { Line } }

local Rewards = {}

function Rewards.calculate(input: Input, config: Config): Result
	local breakdown: { Line } = {}
	local function add(label: string, amount: number)
		if amount ~= 0 then
			table.insert(breakdown, { Label = label, Amount = amount })
		end
	end

	local objectiveCredits = input.objectivesCompleted * config.Credits.PerObjective
	local evidenceCredits = 0
	for _, value in input.evidenceRewards do
		evidenceCredits += value
	end
	add("Objectives", objectiveCredits)
	add("Evidence", evidenceCredits)

	local multiplier = config.ClassificationMultiplier[input.classification]
	local subtotal = (objectiveCredits + evidenceCredits) * multiplier
	if multiplier ~= 1 then
		add(`Classification x{multiplier}`, math.floor(subtotal - (objectiveCredits + evidenceCredits)))
	end

	if not input.escaped then
		local kept = math.floor(subtotal * config.Credits.NotEscapedFactor)
		add("Didn't escape", kept - math.floor(subtotal))
		subtotal = kept
	end

	local bonus = 0
	if input.ending == "Transmit" and input.transmitCompleted then
		bonus += config.Credits.TransmitCompleted
		add("Transmission sent", config.Credits.TransmitCompleted)
	elseif input.ending == "Abort" then
		bonus += config.Credits.Abort
		add("Aborted", config.Credits.Abort)
	end
	if input.escaped then
		bonus += config.Credits.Extraction
		add("Extraction", config.Credits.Extraction)
	end

	local xp = config.XP.Participation
		+ input.objectivesCompleted * config.XP.PerObjective
		+ #input.evidenceRewards * config.XP.PerEvidence
		+ (if input.escaped then config.XP.Extraction else 0)
		+ (if input.classification == "Correct" then config.XP.CorrectClassification else 0)
		+ (if input.ending == "Transmit" and input.transmitCompleted then config.XP.TransmitCompleted else 0)

	return { Credits = math.max(0, math.floor(subtotal) + bonus), XP = xp, Breakdown = breakdown }
end

-- A ledger remembers what was granted per key (e.g. "roundId:userId") so the same reward
-- can never be granted twice.
export type Ledger = { [string]: Result }

function Rewards.newLedger(): Ledger
	return {}
end

-- Returns the result for `key` and whether it was newly granted by this call.
function Rewards.grantOnce(ledger: Ledger, key: string, compute: () -> Result): (Result, boolean)
	local existing = ledger[key]
	if existing then
		return existing, false
	end
	local result = compute()
	ledger[key] = result
	return result, true
end

return Rewards
