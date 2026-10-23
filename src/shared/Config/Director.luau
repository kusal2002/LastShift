--!strict
-- Pacing for the event director: ambient scares and anomaly events, with a global gap
-- between events that shrinks as the round goes on, plus per-event cooldowns.
export type EventDef = { Id: string, Cooldown: number, MinIntensity: number }

local events: { EventDef } = {
	{ Id = "DistantFootsteps", Cooldown = 30, MinIntensity = 0 },
	{ Id = "RadioInterference", Cooldown = 40, MinIntensity = 0 },
	{ Id = "LightFlicker", Cooldown = 25, MinIntensity = 0 },
	{ Id = "PAAnnouncement", Cooldown = 60, MinIntensity = 0 },
	{ Id = "MimicCall", Cooldown = 45, MinIntensity = 0.1 },
	{ Id = "MimicFalseCue", Cooldown = 90, MinIntensity = 0.2 },
	{ Id = "MimicPA", Cooldown = 70, MinIntensity = 0.3 },
	{ Id = "PowerOutage", Cooldown = 75, MinIntensity = 0.15 },
}

return table.freeze({
	TickInterval = 1,
	StartDelay = 25, -- quiet period after players enter
	MinGapStart = 25, -- seconds between events early in the round
	MinGapEnd = 12, -- ...and at full intensity
	Events = table.freeze(events),

	Outage = table.freeze({
		WarningSeconds = 3, -- flicker + warning cue before the lights go
		Duration = 40,
		Rooms = 2, -- rooms affected (plus the corridor half the time)
		SwitchHoldSeconds = 3,
		SwitchInteractDistance = 8,
	}),

	MimicLureChance = 0.6, -- chance the Echo heads to the room a fake call names
	FalseCueLifetime = 60,
	FlickerSeconds = 1.6,

	Decoy = table.freeze({
		PickupDistance = 8,
		ArmSeconds = 2,
		Pulses = 3,
		PulseInterval = 1,
		Loudness = 1,
	}),
})
