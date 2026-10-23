--!strict
-- Reward tuning. All credits and XP are calculated on the server (Logic/Rewards.luau).
-- Phase 6 persists them; Phase 8 adds cosmetic prices.
return table.freeze({
	Credits = table.freeze({
		PerObjective = 20,
		Extraction = 50, -- you personally escaped
		TransmitCompleted = 75, -- the team survived the transmission
		Abort = 0,
		NotEscapedFactor = 0.3, -- share of objective and evidence credits kept if you didn't escape
	}),
	-- Multiplies objective + evidence credits.
	ClassificationMultiplier = table.freeze({
		Correct = 1.5,
		Incorrect = 0.75,
		None = 1, -- "unsure", or no decision reached
	}),
	XP = table.freeze({
		Participation = 25,
		PerObjective = 15,
		PerEvidence = 5,
		Extraction = 40,
		CorrectClassification = 30,
		TransmitCompleted = 30,
	}),
})
