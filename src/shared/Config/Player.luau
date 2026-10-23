--!strict
-- Player movement, survival and flashlight tuning. Times in seconds, speeds in studs/second.
local Player = table.freeze({
	TickInterval = 0.1, -- how often the server updates stamina, battery and downed timers

	WalkSpeed = 12,
	SprintSpeed = 19,
	DownedSpeed = 3,

	Stamina = table.freeze({
		Max = 100,
		DrainPerSecond = 18, -- about 5.5 s of sprinting from full
		RegenPerSecond = 14,
		RegenDelay = 1.5, -- pause after sprinting before stamina recovers
		ExhaustedThreshold = 25, -- after running dry, must recover this much before sprinting again
		MovingSpeed = 1, -- horizontal speed above which a player counts as moving
	}),

	Flashlight = table.freeze({
		MaxBattery = 100,
		DrainPerSecond = 100 / 300, -- 5 minutes of light from full
		Range = 40,
		Angle = 55,
		Brightness = 2.5,
	}),

	Health = table.freeze({
		Max = 100,
		HitProtectionSeconds = 1.5, -- no further damage right after a hit
		ReviveProtectionSeconds = 3,
		ReviveHealth = 50,
	}),

	Downed = table.freeze({
		BleedOutSeconds = 30, -- multiplayer: time teammates have to revive
		ReviveHoldSeconds = 4,
		ReviveDistance = 7,
		SoloRecoverSeconds = 10, -- solo: get back up on your own, once per round
	}),

	Charging = table.freeze({
		UsesPerStation = 2, -- per round
		HoldDuration = 2,
		InteractDistance = 8,
	}),
})

return Player
