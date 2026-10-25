--!strict
-- Bodycam camera tuning. Client presentation only: nothing here changes gameplay.
-- Angles in degrees, distances in studs, frequencies in cycles per second.
local Camera = table.freeze({
	DefaultFieldOfView = 70, -- Roblox's default, restored outside rounds
	ExitZoomDistance = 10, -- zoom the camera back out to this when leaving first person
	FovResponse = 6, -- how quickly the field of view eases to its target
	AimFlashlight = true, -- your own flashlight beam follows the camera up and down (your view only)

	-- Restrained walking sway. Scaled by the player's "Camera motion" setting (0 turns it all off).
	Motion = table.freeze({
		WalkSpeedReference = 12, -- matches Config/Player.WalkSpeed
		MovingSpeed = 1, -- below this horizontal speed the player counts as standing still
		CycleHz = 0.85, -- full left-right cycles per second at walking speed (two footsteps each)
		MaxSpeedScale = 1.8, -- cap on how much faster the cycle runs when sprinting
		Response = 8, -- how quickly sway fades in and out when starting or stopping

		BobHeight = 0.06, -- downward dip per footstep
		BobSide = 0.04, -- side-to-side shift per cycle
		RollDegrees = 0.35,
		PitchDegrees = 0.25,

		SprintMultiplier = 1.6, -- sway is stronger while sprinting
		DownedMultiplier = 0.4, -- and weaker while crawling
		SprintFovBoost = 4, -- extra field of view while sprinting

		BreathHz = 0.22, -- slow idle drift while standing still
		BreathPitchDegrees = 0.12,
		BreathYawDegrees = 0.08,

		MaxStep = 0.1, -- frame times above this are clamped so a lag spike doesn't jolt the camera
	}),

	-- ScreenGuis (by name) that need a free mouse cursor while they are enabled.
	CursorScreens = table.freeze({
		"Calibration",
		"Decision",
		"Settings",
		"HowToPlay",
		"Casebook",
		"Locker",
		"Results",
		"Lobby",
	}),
	-- Panels inside an always-on ScreenGui that need the cursor while visible: { [gui] = panel }.
	CursorPanels = table.freeze({
		Notebook = "NotesPanel",
	}),
})

return Camera
