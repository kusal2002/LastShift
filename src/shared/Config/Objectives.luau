--!strict
-- Tuning for the Phase 1 objectives. Distances are in studs.
export type EvidenceDef = {
	Id: string,
	DisplayName: string,
	Description: string,
}

local evidenceItems: { EvidenceDef } = {
	-- Placeholder pool. Phase 5 replaces this with evidence linked to each anomaly.
	{
		Id = "log_maintenance_07",
		DisplayName = "Damaged Maintenance Log",
		Description = "The last entry repeats the same sentence until the ink runs out.",
	},
	{
		Id = "tape_relay_night",
		DisplayName = "Unlabeled Relay Tape",
		Description = "A recording of the operations room. Someone answers a call that never comes.",
	},
	{
		Id = "reading_power_spike",
		DisplayName = "Power Draw Printout",
		Description = "The station drew full power for six minutes while the generator was offline.",
	},
}

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
	Evidence = table.freeze({
		InteractDistance = 8,
		HoldDuration = 1,
		Items = table.freeze(evidenceItems),
	}),
})

return Objectives
