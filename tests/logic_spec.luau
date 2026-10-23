-- Unit tests for the pure logic modules (no Roblox APIs needed).
local H = require("./harness")
local RoundTransitions = require("../src/shared/Logic/RoundTransitions")
local RoundOutcome = require("../src/shared/Logic/RoundOutcome")
local Calibration = require("../src/shared/Logic/Calibration")
local Selection = require("../src/shared/Logic/Selection")
local MapGrid = require("../src/shared/Logic/MapGrid")
local RateLimiter = require("../src/shared/Util/RateLimiter")
local StationLayout = require("../src/server/Map/StationLayout")

-- RoundTransitions ---------------------------------------------------------
H.test("normal round path is allowed", function()
	H.ok(RoundTransitions.canTransition("Lobby", "Briefing"))
	H.ok(RoundTransitions.canTransition("Briefing", "Investigation"))
	H.ok(RoundTransitions.canTransition("Investigation", "Extraction"))
	H.ok(RoundTransitions.canTransition("Extraction", "Results"))
	H.ok(RoundTransitions.canTransition("Results", "Lobby"))
end)

H.test("skipping phases is rejected", function()
	H.eq(RoundTransitions.canTransition("Lobby", "Investigation"), false)
	H.eq(RoundTransitions.canTransition("Lobby", "Results"), false)
	H.eq(RoundTransitions.canTransition("Briefing", "Extraction"), false)
	H.eq(RoundTransitions.canTransition("Results", "Briefing"), false)
	H.eq(RoundTransitions.canTransition("Lobby", "Lobby"), false)
end)

H.test("rounds can be cancelled back to the lobby", function()
	H.ok(RoundTransitions.canTransition("Briefing", "Lobby"))
	H.ok(RoundTransitions.canTransition("Investigation", "Lobby"))
	H.ok(RoundTransitions.canTransition("Extraction", "Lobby"))
end)

H.test("time-up goes straight from investigation to results", function()
	H.ok(RoundTransitions.canTransition("Investigation", "Results"))
end)

H.test("active round phases", function()
	H.ok(RoundTransitions.isActiveRound("Investigation"))
	H.ok(RoundTransitions.isActiveRound("Extraction"))
	H.eq(RoundTransitions.isActiveRound("Briefing"), false)
	H.eq(RoundTransitions.isActiveRound("Results"), false)
end)

-- RoundOutcome -------------------------------------------------------------
H.test("round continues while someone is alive and time remains", function()
	local shouldEnd = RoundOutcome.decideEnd("Investigation", { a = "Alive", b = "Dead" }, false)
	H.eq(shouldEnd, false)
end)

H.test("everyone escaped or dead ends the round", function()
	local shouldEnd, reason = RoundOutcome.decideEnd("Extraction", { a = "Escaped", b = "Dead" }, false)
	H.eq(shouldEnd, true)
	H.eq(reason, "Extracted")
	local _, wiped = RoundOutcome.decideEnd("Investigation", { a = "Dead", b = "Left" }, false)
	H.eq(wiped, "AllLost")
end)

H.test("timers expiring", function()
	local _, investigation = RoundOutcome.decideEnd("Investigation", { a = "Alive" }, true)
	H.eq(investigation, "TimeUp")
	local _, missed = RoundOutcome.decideEnd("Extraction", { a = "Alive" }, true)
	H.eq(missed, "ExtractionMissed")
	local _, partial = RoundOutcome.decideEnd("Extraction", { a = "Alive", b = "Escaped" }, true)
	H.eq(partial, "Extracted")
end)

H.test("abandoned only when every participant left", function()
	H.ok(RoundOutcome.isAbandoned({ a = "Left", b = "Left" }))
	H.eq(RoundOutcome.isAbandoned({ a = "Left", b = "Dead" }), false)
end)

H.test("finalize marks players still inside as lost", function()
	local statuses = { a = "Alive", b = "Escaped" }
	RoundOutcome.finalize(statuses :: any)
	H.eq(statuses.a, "Lost")
	H.eq(statuses.b, "Escaped")
	H.ok(RoundOutcome.isSuccess(statuses :: any))
	H.eq(RoundOutcome.isSuccess({ a = "Lost" }), false)
end)

-- Calibration --------------------------------------------------------------
H.test("frequency matching ignores floating-point noise", function()
	H.ok(Calibration.isMatch(97.3, 973 * 0.1, 0.1))
	H.ok(Calibration.isMatch(97.30000001, 97.3, 0.1))
	H.eq(Calibration.isMatch(97.4, 97.3, 0.1), false)
end)

H.test("rejects bad client input", function()
	H.eq(Calibration.isValidInput("97.3", 88, 108), false)
	H.eq(Calibration.isValidInput(0 / 0, 88, 108), false)
	H.eq(Calibration.isValidInput(math.huge, 88, 108), false)
	H.eq(Calibration.isValidInput(87.9, 88, 108), false)
	H.eq(Calibration.isValidInput(108.1, 88, 108), false)
	H.ok(Calibration.isValidInput(88.0, 88, 108))
	H.ok(Calibration.isValidInput(108.0, 88, 108))
end)

H.test("random target stays in range and away from the start", function()
	local low = Calibration.randomTarget(function(a, _b)
		return a
	end, 88, 108, 0.1)
	local high = Calibration.randomTarget(function(_a, b)
		return b
	end, 88, 108, 0.1)
	H.ok(low >= 88.9 and low <= 108, `low target {low}`)
	H.ok(high <= 108.0001, `high target {high}`)
	H.ok(Calibration.isValidInput(low, 88, 108))
	H.ok(Calibration.isValidInput(high, 88, 108))
end)

H.test("format pads to three digits", function()
	H.eq(Calibration.format(97.30000000001), "097.3 MHz")
	H.eq(Calibration.format(104.9), "104.9 MHz")
end)

-- Selection ----------------------------------------------------------------
H.test("pickN returns distinct items", function()
	local picked = Selection.pickN({ "a", "b", "c", "d" }, 3, function(_a, b)
		return b
	end)
	H.eq(#picked, 3)
	local seen = {}
	for _, item in picked do
		H.eq(seen[item], nil, "duplicate pick")
		seen[item] = true
	end
end)

H.test("pickN never exceeds the pool and pickOne handles empty lists", function()
	H.eq(#Selection.pickN({ 1, 2 }, 5, function(a, _b)
		return a
	end), 2)
	H.eq(
		Selection.pickOne({}, function(a, _b)
			return a
		end),
		nil
	)
end)

-- RateLimiter --------------------------------------------------------------
H.test("rate limiter allows a burst then refills over time", function()
	local now = 0
	local limiter = RateLimiter.new(2, 1, function()
		return now
	end)
	H.ok(limiter:check("p"))
	H.ok(limiter:check("p"))
	H.eq(limiter:check("p"), false)
	now = 1
	H.ok(limiter:check("p"))
	H.ok(limiter:check("other"), "keys are independent")
end)

-- Station layout -----------------------------------------------------------
H.test("station layout is valid and fully reachable", function()
	local problems = MapGrid.validate(StationLayout.Rows, StationLayout.MountedChars)
	H.eq(#problems, 0, table.concat(problems, "; "))
end)

H.test("station layout has every required marker", function()
	local counts: { [string]: number } = {}
	for _, marker in MapGrid.markers(StationLayout.Rows) do
		counts[marker.char] = (counts[marker.char] or 0) + 1
	end
	H.ok((counts.S or 0) >= 4, "needs 4 spawns")
	H.ok((counts.F or 0) >= 2, "needs several fuse spots")
	H.ok((counts.E or 0) >= 2, "needs several evidence spots")
	H.ok((counts.P or 0) >= 1, "needs a breaker panel")
	H.ok((counts.R or 0) >= 1, "needs a radio console")
	H.ok((counts.B or 0) >= 1, "needs a frequency board")
	H.ok((counts.D or 0) >= 1, "needs an exit door")
	H.ok((counts.X or 0) >= 1, "needs an extraction zone")
	H.ok((counts.Q or 0) >= 1, "needs a charging station")
end)

H.test("validator catches broken layouts", function()
	local unreachable = MapGrid.validate({ "#####", "#S#E#", "#####" })
	H.ok(#unreachable > 0, "isolated evidence should be reported")
	local openBorder = MapGrid.validate({ "#####", "#S...", "#####" })
	H.ok(#openBorder > 0, "open border should be reported")
	local floating = MapGrid.validate({ "#####", "#...#", "#.P.#", "#S..#", "#####" }, { P = true })
	H.ok(#floating > 0, "panel without a wall should be reported")
end)

H.test("wall runs merge horizontal walls", function()
	local runs = MapGrid.wallRuns({ "####", "#..#" })
	H.eq(#runs, 3)
	H.eq(runs[1].colStart, 0)
	H.eq(runs[1].colEnd, 3)
end)

return H
