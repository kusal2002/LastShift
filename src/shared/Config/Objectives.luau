--!strict
-- Tuning for the objectives. Distances are in studs. Evidence lives in Config/Evidence.
local Objectives = table.freeze({
	Interaction = table.freeze({
		DistanceTolerance = 4, -- extra studs allowed for network latency
		RateCapacity = 6, -- burst of prompt triggers allowed per player
		RatePerSecond = 3,
	}),
	Fuse = table.freeze({
		PickupDistance = 8,
		InsertDistance = 8,
		InsertHoldDuration = 1.5,
	}),
	Calibration = table.freeze({
		MinFrequency = 88.0,
		MaxFrequency = 108.0,
		Step = 0.1,
		MaxMistakes = 3, -- wrong submissions before the console overloads
		LockoutSeconds = 10,
		InteractDistance = 8,
		SubmitDistance = 14, -- player may step back slightly while the UI is open
	}),
	Transmitter = table.freeze({
		InteractDistance = 8,
		SubmitDistance = 14,
	}),
})

return Objectives
