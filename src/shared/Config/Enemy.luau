--!strict
-- Tuning for The Echo. Distances in studs, times in seconds, speeds in studs/second.
-- For reference: players walk at 12 and sprint at 19 (Config/Player).
local Enemy = table.freeze({
	AITick = 0.2, -- how often the Echo thinks
	DormantSeconds = 40, -- grace period after players enter the station

	Speeds = table.freeze({
		Patrol = 8,
		Investigate = 11,
		Stalk = 7,
		Chase = 16, -- solo: sprinting (19) outruns it, walking (12) does not
		ChaseMultiplayer = 17,
		Retreat = 14,
	}),

	-- Sight
	SightRange = 70,
	FlashlightSightMultiplier = 1.3, -- a lit flashlight is easier to spot
	FieldOfView = 110, -- degrees, full cone
	CloseDistance = 14, -- seen this close: hunt immediately
	AwarenessRadius = 6, -- notices players this close even outside its field of view

	-- Hearing
	HearingRadius = 60, -- a sound of loudness 1 is heard this far away
	SoundMemorySeconds = 6,
	MaxRememberedSounds = 5,
	MinAudibleLoudness = 0.3, -- quieter sounds are ignored

	-- Alert: rises while a player is in sight (faster when close), decays otherwise
	AlertGainPerSecond = 40,
	AlertDecayPerSecond = 10,
	HuntThreshold = 60,

	-- State timings
	ListenDuration = 1.5, -- readable pause before investigating a sound
	InvestigateMaxSeconds = 20,
	SearchDuration = 10,
	SearchRadius = 30,
	StalkDuration = 8,
	StalkDistance = 30,
	StalkBreakDistance = 18, -- a player closer than this turns stalking into a hunt
	LoseTrackSeconds = 4, -- out of sight this long during a hunt: go search
	ChaseDuration = 25,
	SoloChaseDuration = 20,
	RetreatMaxSeconds = 15,
	RecoverDuration = 3,

	-- Attack
	AttackRange = 5.5,
	AttackReachTolerance = 1.5, -- extra distance allowed when the windup ends
	AttackWindup = 0.7, -- the readable warning before the hit lands
	AttackRecovery = 0.8,
	AttackCooldown = 2.5,
	SoloAttackCooldown = 3.5,
	AttackDamage = 55, -- two hits down a healthy player

	Path = table.freeze({
		AgentRadius = 2,
		AgentHeight = 10,
		WaypointReach = 3,
		RepathChase = 0.5,
		RepathIdle = 2,
		DirectWalkDistance = 12, -- if pathing fails this close, walk straight at the goal
		StuckSeconds = 2,
		StuckDistance = 1,
		StuckLimit = 3, -- stuck checks before the current move counts as failed
		FailuresBeforeTeleport = 4, -- failed moves in a row before an unseen relocation
	}),

	-- Noise loudness (0..1) for gameplay sounds the Echo can hear
	Noise = table.freeze({
		SprintInterval = 0.5,
		Sprint = 0.6,
		FailedCalibration = 1.0,
		FuseInsert = 0.8,
		Charging = 0.5,
		Revive = 0.6,
	}),
})

return Enemy
