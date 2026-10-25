-- Tests for the saved profile: defaults, migration, repair, session locking, round results,
-- unlocks, purchases, equips and settings.
local H = require("./harness")
local Profile = require("../src/shared/Logic/Profile")
local Progression = require("../src/shared/Logic/Progression")
local Cosmetics = require("../src/shared/Config/Cosmetics")

local JOB = "server-A"
local OTHER = "server-B"
local STALE = 180

local function record(overrides: { [string]: any }?): any
	local base = {
		credits = 100,
		xp = 50,
		escaped = true,
		transmitted = false,
		anomalyId = "Listener",
		correctReport = true,
		evidenceIds = { "listener_muffled_tape", "listener_mic_readout" },
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

-- Defaults ----------------------------------------------------------------------
H.test("new profiles own and equip the default cosmetics", function()
	local data = Profile.new(Cosmetics)
	H.eq(data.version, Profile.CurrentVersion)
	H.eq(data.credits, 0)
	H.ok(data.owned.flashlight_standard)
	H.ok(data.owned.badge_rookie)
	H.eq(data.equipped.Flashlight, "flashlight_standard")
	H.eq(data.equipped.Badge, "badge_rookie")
	H.eq(data.settings.Subtitles, true)
end)

H.test("new profiles never share tables", function()
	local a = Profile.new(Cosmetics)
	local b = Profile.new(Cosmetics)
	a.casebook.x = true
	a.settings.Subtitles = false
	H.eq(b.casebook.x, nil)
	H.eq(b.settings.Subtitles, true)
end)

-- Migration and repair ------------------------------------------------------------
H.test("unversioned data migrates all the way to the current version", function()
	local migrated = Profile.migrate({ credits = 5 })
	H.eq(migrated.version, Profile.CurrentVersion)
	H.eq(migrated.credits, 5)
end)

H.test("v1 saves gain volume and text-size settings without losing old ones", function()
	local v1 = { version = 1, credits = 120, settings = { Subtitles = false } }
	local data = Profile.sanitize(Profile.migrate(v1), Cosmetics)
	H.eq(data.version, 2)
	H.eq(data.credits, 120)
	H.eq(data.settings.Subtitles, false, "kept")
	H.eq(data.settings.MasterVolume, 1)
	H.eq(data.settings.AmbientVolume, 0.8)
	H.eq(data.settings.TextScale, 1)
end)

H.test("sanitize keeps valid values and repairs bad ones", function()
	local data = Profile.sanitize({
		credits = 250,
		xp = -40,
		stats = { rounds = 3, escapes = "lots" },
		casebook = { listener_muffled_tape = true, junk = 5 },
		owned = { flashlight_sodium = true, not_a_real_item = true },
		equipped = { Flashlight = "flashlight_sodium", Badge = "badge_veteran" },
		settings = { ReducedFlashes = true, Hacks = true },
	}, Cosmetics)
	H.eq(data.credits, 250)
	H.eq(data.xp, 0, "negative xp repaired")
	H.eq(data.stats.rounds, 3)
	H.eq(data.stats.escapes, 0, "non-number repaired")
	H.ok(data.casebook.listener_muffled_tape)
	H.eq(data.casebook.junk, nil)
	H.ok(data.owned.flashlight_sodium)
	H.eq(data.owned.not_a_real_item, nil, "unknown cosmetics dropped")
	H.eq(data.equipped.Flashlight, "flashlight_sodium")
	H.eq(data.equipped.Badge, "badge_rookie", "can't equip what you don't own")
	H.eq(data.settings.ReducedFlashes, true)
	H.eq(data.settings.Hacks, nil)
end)

H.test("garbage stored data becomes a fresh profile rather than an error", function()
	local data = Profile.sanitize("not a table", Cosmetics)
	H.eq(data.credits, 0)
	H.ok(data.owned.flashlight_standard)
end)

-- Session locking -------------------------------------------------------------------
H.test("a new player is claimed with our lock", function()
	local data, status = Profile.claim(nil, JOB, 1000, STALE, Cosmetics)
	H.eq(status, "Claimed")
	H.ok(data ~= nil)
	local claimed = data :: any
	H.eq(claimed.lock.jobId, JOB)
	H.eq(claimed.lock.at, 1000)
end)

H.test("a fresh lock held by another server blocks loading", function()
	local stored = { version = 1, credits = 500, lock = { jobId = OTHER, at = 990 } }
	local data, status = Profile.claim(stored, JOB, 1000, STALE, Cosmetics)
	H.eq(status, "Locked")
	H.eq(data, nil, "store must not be written")
end)

H.test("a stale lock from a crashed server can be taken, keeping the data", function()
	local stored = { version = 1, credits = 500, lock = { jobId = OTHER, at = 100 } }
	local data, status = Profile.claim(stored, JOB, 1000, STALE, Cosmetics)
	H.eq(status, "Claimed")
	local claimed = data :: any
	H.eq(claimed.credits, 500)
	H.eq(claimed.lock.jobId, JOB)
end)

H.test("our own lock can be re-claimed", function()
	H.ok(Profile.canClaim({ jobId = JOB, at = 999 }, JOB, 1000, STALE))
end)

H.test("saving refreshes the lock, releasing clears it", function()
	local current = Profile.new(Cosmetics)
	current.credits = 42
	local stored = { lock = { jobId = JOB, at = 1 } }
	local kept = Profile.prepareSave(current, stored, JOB, 2000, false) :: any
	H.eq(kept.credits, 42)
	H.eq(kept.lock.at, 2000)
	local released = Profile.prepareSave(current, stored, JOB, 2000, true) :: any
	H.eq(released.lock, nil)
end)

H.test("never overwrite data another server has taken over", function()
	local current = Profile.new(Cosmetics)
	local stored = { credits = 900, lock = { jobId = OTHER, at = 1999 } }
	H.eq(Profile.prepareSave(current, stored, JOB, 2000, true), nil)
end)

H.test("saves are copies, not live references", function()
	local current = Profile.new(Cosmetics)
	local saved = Profile.prepareSave(current, nil, JOB, 1, false) :: any
	current.casebook.later = true
	H.eq(saved.casebook.later, nil)
end)

-- Round results ------------------------------------------------------------------------
H.test("escaping adds credits, xp, stats and casebook entries", function()
	local data = Profile.new(Cosmetics)
	local added = Profile.applyRound(data, record())
	H.eq(data.credits, 100)
	H.eq(data.xp, 50)
	H.eq(data.stats.rounds, 1)
	H.eq(data.stats.escapes, 1)
	H.eq(data.stats.correctReports, 1)
	H.eq(#added, 2)
	H.ok(data.casebook.listener_muffled_tape)
	H.eq(data.anomalies.Listener.encounters, 1)
	H.eq(data.anomalies.Listener.identified, 1)
end)

H.test("evidence only enters the casebook if you escaped", function()
	local data = Profile.new(Cosmetics)
	local added = Profile.applyRound(data, record({ escaped = false, correctReport = false }))
	H.eq(#added, 0)
	H.eq(data.casebook.listener_muffled_tape, nil)
	H.eq(data.anomalies.Listener.identified, 0)
end)

H.test("casebook entries are only reported once", function()
	local data = Profile.new(Cosmetics)
	Profile.applyRound(data, record())
	local again = Profile.applyRound(data, record())
	H.eq(#again, 0)
end)

-- Levels, unlocks, purchases --------------------------------------------------------------
H.test("level curve", function()
	H.eq(Progression.levelFor(0).level, 1)
	H.eq(Progression.levelFor(99).level, 1)
	H.eq(Progression.levelFor(100).level, 2)
	H.eq(Progression.levelFor(100 + 150).level, 3)
	H.eq(Progression.levelFor(100 + 150).intoLevel, 0)
	H.eq(Progression.levelFor(10 ^ 9).level, Progression.MaxLevel)
	H.eq(Progression.levelFor(10 ^ 9).toNext, 0)
end)

H.test("reaching a level unlocks its cosmetics once", function()
	local data = Profile.new(Cosmetics)
	local first = Profile.grantLevelUnlocks(data, 4, Cosmetics)
	H.ok(data.owned.flashlight_sodium)
	H.ok(data.owned.badge_survivor)
	H.eq(data.owned.flashlight_cathode, nil, "level 6 item still locked")
	H.eq(#first, 2)
	H.eq(#Profile.grantLevelUnlocks(data, 4, Cosmetics), 0)
end)

H.test("buying with credits checks price and ownership", function()
	local data = Profile.new(Cosmetics)
	data.credits = 350
	H.eq(Profile.buyWithCredits(data, "flashlight_phosphor", Cosmetics), "TooPoor")
	H.eq(Profile.buyWithCredits(data, "badge_signal", Cosmetics), "Bought")
	H.eq(data.credits, 50)
	H.eq(Profile.buyWithCredits(data, "badge_signal", Cosmetics), "Owned")
	H.eq(Profile.buyWithCredits(data, "flashlight_cathode", Cosmetics), "NotForSale", "level unlock")
	H.eq(Profile.buyWithCredits(data, "made_up", Cosmetics), "Unknown")
end)

H.test("equip only owned items into their own slot", function()
	local data = Profile.new(Cosmetics)
	H.eq(Profile.equip(data, "Flashlight", "flashlight_darkroom", Cosmetics), false, "not owned")
	data.owned.flashlight_darkroom = true
	H.eq(Profile.equip(data, "Badge", "flashlight_darkroom", Cosmetics), false, "wrong slot")
	H.ok(Profile.equip(data, "Flashlight", "flashlight_darkroom", Cosmetics))
	H.eq(data.equipped.Flashlight, "flashlight_darkroom")
end)

H.test("only known settings of the right type are saved", function()
	local data = Profile.new(Cosmetics)
	H.ok(Profile.setSetting(data, "ReducedFlashes", true))
	H.eq(Profile.setSetting(data, "ReducedFlashes", "yes"), false)
	H.eq(Profile.setSetting(data, "Credits", true), false)
	H.eq(Profile.setSetting(data, "MasterVolume", true), false, "volume must be a number")
	H.eq(Profile.setSetting(data, "MasterVolume", 0 / 0), false)
end)

H.test("number settings are clamped and rounded", function()
	local data = Profile.new(Cosmetics)
	H.ok(Profile.setSetting(data, "MasterVolume", 5))
	H.eq(data.settings.MasterVolume, 1)
	H.ok(Profile.setSetting(data, "EffectsVolume", -2))
	H.eq(data.settings.EffectsVolume, 0)
	H.ok(Profile.setSetting(data, "AmbientVolume", 0.4321))
	H.eq(data.settings.AmbientVolume, 0.45)
	H.ok(Profile.setSetting(data, "TextScale", 9))
	H.eq(data.settings.TextScale, 1.3)
end)

H.test("camera settings are clamped, and old saves get camera defaults", function()
	local data = Profile.new(Cosmetics)
	H.eq(data.settings.MouseSensitivity, 1)
	H.eq(data.settings.FieldOfView, 80)
	H.eq(data.settings.CameraMotion, 1)
	H.ok(Profile.setSetting(data, "MouseSensitivity", 50))
	H.eq(data.settings.MouseSensitivity, 2)
	H.ok(Profile.setSetting(data, "FieldOfView", 10))
	H.eq(data.settings.FieldOfView, 70)
	H.ok(Profile.setSetting(data, "CameraMotion", -1))
	H.eq(data.settings.CameraMotion, 0)
	H.eq(Profile.setSetting(data, "CameraMotion", false), false, "motion must be a number")

	-- A v2 save from before the camera settings existed.
	local old = Profile.sanitize({ version = 2, settings = { MasterVolume = 0.5 } }, Cosmetics)
	H.eq(old.settings.MasterVolume, 0.5)
	H.eq(old.settings.FieldOfView, 80)
	H.eq(old.settings.CameraMotion, 1)
end)

H.test("cosmetics never change gameplay numbers", function()
	for _, item in Cosmetics.Items do
		for key in item do
			H.ok(
				key == "Id" or key == "DisplayName" or key == "Slot" or key == "Unlock" or key == "Color",
				`{item.Id}.{key}`
			)
		end
	end
end)

return H
