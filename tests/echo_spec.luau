-- Unit tests for the Echo's decision rules.
local H = require("./harness")
local EchoBrain = require("../src/shared/Logic/EchoBrain")

local CONFIG = {
	HuntThreshold = 60,
	CloseDistance = 14,
	ListenDuration = 1.5,
	InvestigateMaxSeconds = 20,
	SearchDuration = 10,
	StalkDuration = 8,
	StalkBreakDistance = 18,
	LoseTrackSeconds = 4,
	ChaseDuration = 25,
	SoloChaseDuration = 20,
	RetreatMaxSeconds = 15,
	RecoverDuration = 3,
	AttackRange = 5.5,
	AttackWindup = 0.7,
	AttackRecovery = 0.8,
	AlertGainPerSecond = 40,
	AlertDecayPerSecond = 10,
}

-- A calm perception; tests override only what they need.
local function perceive(overrides: { [string]: any }?): any
	local p = {
		awake = true,
		stateTime = 0,
		canSeeTarget = false,
		targetDistance = nil,
		timeSinceSeen = math.huge,
		alert = 0,
		heardSound = false,
		arrived = false,
		pathFailed = false,
		attackReady = true,
		attackHit = false,
		solo = false,
	}
	for key, value in overrides or {} do
		p[key] = value
	end
	return p
end

local function decide(state: string, overrides: { [string]: any }?): string
	return EchoBrain.decide(state :: any, perceive(overrides), CONFIG)
end

H.test("dormant until awake, then patrols", function()
	H.eq(decide("Dormant", { awake = false }), "Dormant")
	H.eq(decide("Dormant"), "Patrol")
	H.eq(decide("Hunt", { awake = false }), "Dormant", "round end puts it to sleep from any state")
end)

H.test("patrol reacts to sound by listening first", function()
	H.eq(decide("Patrol"), "Patrol")
	H.eq(decide("Patrol", { heardSound = true }), "Listen")
	H.eq(decide("Listen", { stateTime = 1 }), "Listen", "listen pause is readable")
	H.eq(decide("Listen", { stateTime = 1.5 }), "Investigate")
end)

H.test("distant sighting stalks, close sighting hunts", function()
	H.eq(decide("Patrol", { canSeeTarget = true, targetDistance = 50 }), "Stalk")
	H.eq(decide("Patrol", { canSeeTarget = true, targetDistance = 10 }), "Hunt")
	H.eq(decide("Patrol", { canSeeTarget = true, targetDistance = 50, alert = 70 }), "Hunt")
end)

H.test("investigation ends in a search", function()
	H.eq(decide("Investigate", { arrived = true }), "Search")
	H.eq(decide("Investigate", { pathFailed = true }), "Search", "unreachable sound does not trap it")
	H.eq(decide("Investigate", { stateTime = 25 }), "Search")
	H.eq(decide("Investigate", { canSeeTarget = true, targetDistance = 8 }), "Hunt")
end)

H.test("stalking escalates, loses track, or withdraws", function()
	H.eq(
		decide("Stalk", { canSeeTarget = true, targetDistance = 30, alert = 30, timeSinceSeen = 0 }),
		"Stalk"
	)
	H.eq(decide("Stalk", { canSeeTarget = true, targetDistance = 15, timeSinceSeen = 0 }), "Hunt")
	H.eq(decide("Stalk", { canSeeTarget = true, targetDistance = 30, alert = 60, timeSinceSeen = 0 }), "Hunt")
	H.eq(decide("Stalk", { timeSinceSeen = 5 }), "Search")
	H.eq(
		decide("Stalk", { canSeeTarget = true, targetDistance = 30, timeSinceSeen = 0, stateTime = 9 }),
		"Retreat"
	)
end)

H.test("hunt attacks only in range with cooldown ready", function()
	H.eq(decide("Hunt", { canSeeTarget = true, timeSinceSeen = 0, targetDistance = 5 }), "Attack")
	H.eq(
		decide("Hunt", { canSeeTarget = true, timeSinceSeen = 0, targetDistance = 5, attackReady = false }),
		"Hunt"
	)
	H.eq(decide("Hunt", { canSeeTarget = true, timeSinceSeen = 0, targetDistance = 9 }), "Hunt")
end)

H.test("hunt loses the target when sight is broken", function()
	H.eq(decide("Hunt", { timeSinceSeen = 2 }), "Hunt", "keeps chasing the last known position briefly")
	H.eq(decide("Hunt", { timeSinceSeen = 4 }), "Search")
	H.eq(decide("Hunt", { timeSinceSeen = 1, pathFailed = true }), "Search")
end)

H.test("chases are time limited, shorter solo", function()
	local chasing = { canSeeTarget = true, timeSinceSeen = 0, targetDistance = 20 }
	chasing.stateTime = 21
	H.eq(decide("Hunt", chasing), "Hunt")
	chasing.solo = true
	H.eq(decide("Hunt", chasing), "Retreat")
end)

H.test("attack resolves after windup and recovery", function()
	H.eq(decide("Attack", { stateTime = 1 }), "Attack")
	H.eq(decide("Attack", { stateTime = 1.5, attackHit = true }), "Retreat", "backs off after a hit")
	H.eq(decide("Attack", { stateTime = 1.5, attackHit = false }), "Hunt")
end)

H.test("search, retreat and recover lead back to patrol", function()
	H.eq(decide("Search", { heardSound = true }), "Listen")
	H.eq(decide("Search", { stateTime = 10 }), "Recover")
	H.eq(decide("Retreat", { arrived = true }), "Recover")
	H.eq(decide("Retreat", { pathFailed = true }), "Recover")
	H.eq(decide("Retreat", { stateTime = 16 }), "Recover")
	H.eq(decide("Recover", { stateTime = 2 }), "Recover")
	H.eq(decide("Recover", { stateTime = 3 }), "Patrol")
end)

H.test("alert rises faster up close and decays out of sight", function()
	local far = EchoBrain.updateAlert(0, 1, true, 70, 70, CONFIG)
	local near = EchoBrain.updateAlert(0, 1, true, 7, 70, CONFIG)
	H.ok(near > far, "closer is more alarming")
	H.eq(EchoBrain.updateAlert(50, 1, false, nil, 70, CONFIG), 40)
	H.eq(EchoBrain.updateAlert(5, 1, false, nil, 70, CONFIG), 0)
	H.eq(EchoBrain.updateAlert(99, 10, true, 1, 70, CONFIG), 100)
end)

H.test("field of view", function()
	H.ok(EchoBrain.isInFieldOfView(0, -1, 0, -10, 110), "straight ahead")
	H.ok(EchoBrain.isInFieldOfView(0, -1, 5, -10, 110), "slightly to the side")
	H.eq(EchoBrain.isInFieldOfView(0, -1, 10, 0, 110), false, "directly beside")
	H.eq(EchoBrain.isInFieldOfView(0, -1, 0, 10, 110), false, "behind")
end)

H.test("hearing picks the loudest audible recent sound", function()
	local sounds = {
		{ distance = 50, loudness = 0.6, age = 0 }, -- out of reach (36)
		{ distance = 20, loudness = 0.6, age = 1 },
		{ distance = 30, loudness = 1.0, age = 0 },
		{ distance = 5, loudness = 0.2, age = 0 }, -- too quiet
		{ distance = 5, loudness = 1.0, age = 9 }, -- forgotten
	}
	H.eq(EchoBrain.pickSound(sounds, 60, 6, 0.3), 3)
	H.eq(EchoBrain.pickSound({ sounds[1], sounds[4] }, 60, 6, 0.3), nil)
end)

return H
