-- Unit tests for the bodycam camera rules: when first person is used, sway and field of view.
local H = require("./harness")
local CameraMotion = require("../src/shared/Logic/CameraMotion")
local CameraConfig = require("../src/shared/Config/Camera")

local MOTION = CameraConfig.Motion

local WALK = { speed = 12, sprinting = false, downed = false, grounded = true }
local SPRINT = { speed = 19, sprinting = true, downed = false, grounded = true }
local STILL = { speed = 0, sprinting = false, downed = false, grounded = true }

local function near(actual: number, expected: number, message: string?)
	H.ok(math.abs(actual - expected) < 1e-6, `{message or "value"}: expected {expected}, got {actual}`)
end

-- Runs `seconds` of frames and returns the largest absolute value of each offset field.
local function peak(input: any, seconds: number, intensity: number): { [string]: number }
	local state = CameraMotion.new()
	local most = { x = 0, y = 0, pitch = 0, yaw = 0, roll = 0 }
	local dt = 1 / 60
	for _ = 1, math.floor(seconds / dt) do
		local offset
		state, offset = CameraMotion.step(state, dt, input, MOTION, intensity)
		for key, value in offset :: any do
			most[key] = math.max(most[key], math.abs(value))
		end
	end
	return most
end

H.test("first person only for a living participant in an active round", function()
	H.ok(CameraMotion.wantsFirstPerson(true, true, "Alive", true))
	H.eq(CameraMotion.wantsFirstPerson(false, true, "Alive", true), false, "lobby / briefing / results")
	H.eq(CameraMotion.wantsFirstPerson(true, false, "Alive", true), false, "not in this round")
	H.eq(CameraMotion.wantsFirstPerson(true, true, "Dead", true), false, "spectating")
	H.eq(CameraMotion.wantsFirstPerson(true, true, "Escaped", true), false)
	H.eq(CameraMotion.wantsFirstPerson(true, true, nil, true), false)
	H.eq(CameraMotion.wantsFirstPerson(true, true, "Alive", false), false, "character dead or missing")
end)

H.test("camera motion 0 turns every offset off", function()
	local most = peak(SPRINT, 3, 0)
	for key, value in most do
		H.eq(value, 0, key)
	end
	near(CameraMotion.targetFov(80, 1, MOTION, 0), 80, "no sprint widening")
end)

H.test("walking sway stays within the configured limits", function()
	local most = peak(WALK, 4, 1)
	H.ok(most.y > 0, "walking bobs")
	H.ok(most.y <= MOTION.BobHeight + 1e-9, "bob height")
	H.ok(most.x <= MOTION.BobSide + 1e-9, "side sway")
	H.ok(most.roll <= math.rad(MOTION.RollDegrees) + 1e-9, "roll")
	H.ok(math.deg(most.roll) < 1, "roll stays under one degree")
end)

H.test("sprinting sways more than walking, crawling less", function()
	local walk = peak(WALK, 4, 1)
	local sprint = peak(SPRINT, 4, 1)
	local crawl = peak({ speed = 3, sprinting = false, downed = true, grounded = true }, 4, 1)
	H.ok(sprint.y > walk.y, "sprint bob is stronger")
	H.ok(crawl.y < walk.y, "downed bob is weaker")
	H.ok(sprint.y <= MOTION.BobHeight * MOTION.SprintMultiplier + 1e-9, "sprint bob capped")
end)

H.test("standing still only drifts gently", function()
	local most = peak(STILL, 6, 1)
	H.eq(most.y, 0, "no footstep bob")
	H.eq(most.x, 0, "no side sway")
	H.ok(most.pitch > 0, "idle breathing drift")
	H.ok(most.pitch <= math.rad(MOTION.BreathPitchDegrees) + 1e-9, "breathing stays small")
end)

H.test("airborne or stopping fades the sway out", function()
	local state = CameraMotion.new()
	for _ = 1, 120 do
		state = CameraMotion.step(state, 1 / 60, WALK, MOTION, 1)
	end
	H.ok(state.moving > 0.9, "sway faded in")
	local falling = { speed = 12, sprinting = false, downed = false, grounded = false }
	for _ = 1, 120 do
		state = CameraMotion.step(state, 1 / 60, falling, MOTION, 1)
	end
	H.ok(state.moving < 0.01, "no footstep sway in the air")
end)

H.test("a lag spike can't jolt the camera", function()
	local a = CameraMotion.step(CameraMotion.new(), MOTION.MaxStep, WALK, MOTION, 1)
	local b = CameraMotion.step(CameraMotion.new(), 5, WALK, MOTION, 1)
	near(a.cycle, b.cycle, "cycle")
	near(a.moving, b.moving, "fade")
end)

H.test("sprinting widens the field of view slightly", function()
	near(CameraMotion.targetFov(80, 0, MOTION, 1), 80)
	near(CameraMotion.targetFov(80, 1, MOTION, 1), 80 + MOTION.SprintFovBoost)
	near(CameraMotion.targetFov(80, 1, MOTION, 0.5), 80 + MOTION.SprintFovBoost / 2)
	H.ok(MOTION.SprintFovBoost <= 6, "kept restrained")
end)

H.test("approach eases toward the target without overshooting", function()
	local value = 70
	for _ = 1, 600 do
		value = CameraMotion.approach(value, 80, 1 / 60, 6)
		H.ok(value <= 80, "no overshoot")
	end
	H.ok(math.abs(value - 80) < 0.01, "arrives")
end)
