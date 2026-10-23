-- Unit tests for stamina and damage/downed rules.
local H = require("./harness")
local Stamina = require("../src/shared/Logic/Stamina")
local Damage = require("../src/shared/Logic/Damage")

local STAMINA = {
	Max = 100,
	DrainPerSecond = 20,
	RegenPerSecond = 10,
	RegenDelay = 1,
	ExhaustedThreshold = 25,
}

local HEALTH = {
	Max = 100,
	HitProtectionSeconds = 1.5,
	ReviveProtectionSeconds = 3,
	ReviveHealth = 50,
}

-- Stamina ------------------------------------------------------------------
H.test("sprinting drains stamina only while moving", function()
	local state = Stamina.new(STAMINA)
	local moving, sprinting = Stamina.step(state, 1, true, true, STAMINA)
	H.ok(sprinting)
	H.eq(moving.value, 80)
	local still, sprintingStill = Stamina.step(state, 1, true, false, STAMINA)
	H.eq(sprintingStill, false, "standing still is not sprinting")
	H.eq(still.value, 100)
end)

H.test("running dry exhausts until the threshold is recovered", function()
	local state = Stamina.new(STAMINA)
	state = Stamina.step(state, 5, true, true, STAMINA)
	H.eq(state.value, 0)
	H.ok(state.exhausted)
	local _, sprinting = Stamina.step(state, 0.1, true, true, STAMINA)
	H.eq(sprinting, false, "can't sprint while exhausted")
	-- Regen waits for the delay, then refills.
	state = Stamina.step(state, 0.5, false, true, STAMINA)
	H.eq(state.value, 0, "no regen during the delay")
	state = Stamina.step(state, 1, false, true, STAMINA)
	H.eq(state.value, 10)
	H.ok(state.exhausted, "still exhausted below threshold")
	state = Stamina.step(state, 2, false, true, STAMINA)
	H.eq(state.value, 30)
	H.eq(state.exhausted, false)
end)

H.test("stamina never exceeds the maximum", function()
	local state = Stamina.step(Stamina.new(STAMINA), 100, false, false, STAMINA)
	H.eq(state.value, 100)
end)

H.test("regen waits for the delay after sprinting", function()
	local state = Stamina.new(STAMINA)
	state = Stamina.step(state, 1, true, true, STAMINA)
	state = Stamina.step(state, 0.5, false, true, STAMINA)
	H.eq(state.value, 80, "no regen during the delay")
end)

-- Damage -------------------------------------------------------------------
H.test("a normal hit damages and grants brief protection", function()
	local state = Damage.new(HEALTH)
	local result, after = Damage.resolve(state, 30, 10, HEALTH)
	H.eq(result, "Damaged")
	H.eq(after.health, 70)
	local again = Damage.resolve(after, 30, 11, HEALTH)
	H.eq(again, "Ignored", "protected right after a hit")
	local later = Damage.resolve(after, 30, 12, HEALTH)
	H.eq(later, "Damaged")
end)

H.test("first lethal hit downs, second eliminates", function()
	local state = Damage.new(HEALTH)
	local result, downed = Damage.resolve(state, 150, 0, HEALTH)
	H.eq(result, "Downed")
	H.ok(downed.downed)
	local revived = Damage.revive(downed, 5, HEALTH)
	H.eq(revived.health, 50)
	H.eq(revived.downed, false)
	H.eq(Damage.resolve(revived, 10, 6, HEALTH), "Ignored", "revive protection")
	local final = Damage.resolve(revived, 100, 9, HEALTH)
	H.eq(final, "Killed", "downed already used this round")
end)

H.test("any hit while downed eliminates", function()
	local _, downed = Damage.resolve(Damage.new(HEALTH), 100, 0, HEALTH)
	H.eq(Damage.resolve(downed, 1, 5, HEALTH), "Killed")
end)

H.test("invalid damage amounts are ignored", function()
	local state = Damage.new(HEALTH)
	H.eq(Damage.resolve(state, -5, 0, HEALTH), "Ignored")
	H.eq(Damage.resolve(state, 0 / 0, 0, HEALTH), "Ignored")
	H.eq(Damage.resolve(state, math.huge, 0, HEALTH), "Ignored")
	H.eq(Damage.resolve(state, 0, 0, HEALTH), "Ignored")
end)

return H
