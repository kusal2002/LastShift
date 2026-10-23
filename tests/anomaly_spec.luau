-- Tests for anomaly profiles, tuning, the scare director and room lookup.
local H = require("./harness")
local Tuning = require("../src/shared/Logic/Tuning")
local ScareDirector = require("../src/shared/Logic/ScareDirector")
local MapGrid = require("../src/shared/Logic/MapGrid")
local Anomalies = require("../src/shared/Config/Anomalies")
local EnemyConfig = require("../src/shared/Config/Enemy")
local PlayerConfig = require("../src/shared/Config/Player")
local DirectorConfig = require("../src/shared/Config/Director")
local AudioConfig = require("../src/shared/Config/Audio")
local StationLayout = require("../src/server/Map/StationLayout")

-- Tuning -------------------------------------------------------------------
H.test("tuning multiplies nested keys without touching the base", function()
	local base = table.freeze({ SightRange = 70, Speeds = table.freeze({ Chase = 16 }) })
	local tuned = Tuning.apply(base, { SightRange = 0.5, ["Speeds.Chase"] = 1.5 })
	H.eq(tuned.SightRange, 35)
	H.eq(tuned.Speeds.Chase, 24)
	H.eq(base.SightRange, 70, "base unchanged")
end)

H.test("tuning rejects unknown keys", function()
	local ok = pcall(Tuning.apply, { A = 1 }, { B = 2 })
	H.eq(ok, false)
end)

-- Anomaly profiles ---------------------------------------------------------
H.test("every anomaly applies cleanly to the Echo config", function()
	for _, profile in Anomalies.List do
		local tuned = Tuning.apply(EnemyConfig, profile.EchoModifiers)
		if profile.DarkModifiers then
			Tuning.apply(tuned, profile.DarkModifiers)
		end
		H.ok(tuned.SightRange > 0, profile.Id)
	end
end)

H.test("a sprinting player can always outrun the Echo", function()
	for _, profile in Anomalies.List do
		local tuned = Tuning.apply(EnemyConfig, profile.EchoModifiers)
		if profile.DarkModifiers then
			tuned = Tuning.apply(tuned, profile.DarkModifiers)
		end
		H.ok(tuned.Speeds.Chase < PlayerConfig.SprintSpeed, `{profile.Id} solo chase too fast`)
		H.ok(tuned.Speeds.ChaseMultiplayer < PlayerConfig.SprintSpeed, `{profile.Id} team chase too fast`)
		H.ok(tuned.AttackWindup >= 0.5, `{profile.Id} windup too short to react`)
	end
end)

H.test("anomaly event weights only name real director events", function()
	local known = {}
	for _, event in DirectorConfig.Events do
		known[event.Id] = true
	end
	for _, profile in Anomalies.List do
		for id in profile.EventWeights do
			H.ok(known[id], `{profile.Id} uses unknown event {id}`)
		end
	end
end)

H.test("anomaly ids are unique and indexed", function()
	H.eq(#Anomalies.List, 3)
	for _, profile in Anomalies.List do
		H.eq(Anomalies.ById[profile.Id], profile)
	end
end)

H.test("every audio cue has a subtitle", function()
	for id, cue in AudioConfig.Cues do
		H.ok(#cue.Subtitle > 0, id)
	end
end)

-- Scare director -----------------------------------------------------------
local CONFIG = { StartDelay = 25, MinGapStart = 25, MinGapEnd = 12 }
local EVENTS = {
	{ Id = "A", Cooldown = 30, MinIntensity = 0 },
	{ Id = "B", Cooldown = 30, MinIntensity = 0.5 },
}
local function first()
	return 0
end

H.test("director stays quiet at the start", function()
	local state = ScareDirector.new(0)
	H.eq(ScareDirector.pick(state, 10, 0, EVENTS, { A = 1 }, {}, CONFIG, first), nil)
	H.eq(ScareDirector.pick(state, 26, 0, EVENTS, { A = 1 }, {}, CONFIG, first), "A")
end)

H.test("director keeps a gap between events and respects cooldowns", function()
	local state = ScareDirector.new(0)
	ScareDirector.record(state, "A", 30)
	H.eq(ScareDirector.pick(state, 40, 0, EVENTS, { A = 1 }, {}, CONFIG, first), nil, "gap")
	H.eq(ScareDirector.pick(state, 56, 0, EVENTS, { A = 1 }, {}, CONFIG, first), nil, "A cooling down")
	H.eq(ScareDirector.pick(state, 61, 0, EVENTS, { A = 1 }, {}, CONFIG, first), "A")
end)

H.test("director gap shrinks with intensity", function()
	H.eq(ScareDirector.minGap(0, CONFIG), 25)
	H.eq(ScareDirector.minGap(1, CONFIG), 12)
	H.eq(ScareDirector.intensity(240, 480, false), 0.5)
	H.eq(ScareDirector.intensity(10, 480, true), 1)
end)

H.test("director honours minimum intensity, weights and blocks", function()
	local state = ScareDirector.new(0)
	H.eq(ScareDirector.pick(state, 100, 0.2, EVENTS, { B = 1 }, {}, CONFIG, first), nil, "B needs 0.5")
	H.eq(ScareDirector.pick(state, 100, 0.6, EVENTS, { B = 1 }, {}, CONFIG, first), "B")
	H.eq(ScareDirector.pick(state, 100, 0.6, EVENTS, { A = 1, B = 1 }, { A = true }, CONFIG, first), "B")
	H.eq(ScareDirector.pick(state, 100, 0.6, EVENTS, { A = 0 }, {}, CONFIG, first), nil, "zero weight")
	local last = function()
		return 0.99
	end
	H.eq(ScareDirector.pick(state, 100, 0.6, EVENTS, { A = 1, B = 1 }, {}, CONFIG, last), "B")
end)

-- Rooms --------------------------------------------------------------------
H.test("every walkable cell belongs to a named room", function()
	for rowIndex, line in StationLayout.Rows do
		for col = 0, #line - 1 do
			local row = rowIndex - 1
			if MapGrid.isWalkable(MapGrid.charAt(StationLayout.Rows, row, col)) then
				H.ok(MapGrid.roomAt(StationLayout.Rooms, row, col) ~= nil, `cell ({row}, {col}) has no room`)
			end
		end
	end
end)

H.test("room lookup", function()
	H.eq(MapGrid.roomAt(StationLayout.Rooms, 1, 1), "Storage")
	H.eq(MapGrid.roomAt(StationLayout.Rooms, 7, 11), "Corridor")
	H.eq(MapGrid.roomAt(StationLayout.Rooms, 16, 11), "Loading Bay")
	H.eq(MapGrid.roomAt(StationLayout.Rooms, 0, 0), nil)
end)

H.test("layout has a power switch and noise makers", function()
	local counts: { [string]: number } = {}
	for _, marker in MapGrid.markers(StationLayout.Rows) do
		counts[marker.char] = (counts[marker.char] or 0) + 1
	end
	H.ok((counts.G or 0) >= 1, "needs a power switch")
	H.ok((counts.N or 0) >= 2, "needs noise maker spots")
end)

H.test("room signs sit on walls and name the room the HUD shows there", function()
	H.ok(#StationLayout.Signs >= 7, "every main room has a sign")
	for _, sign in StationLayout.Signs do
		local dRow = MapGrid.adjacentWall(StationLayout.Rows, sign.Row, sign.Col)
		H.ok(dRow ~= nil, `sign {sign.Text} has no wall`)
		local room = MapGrid.roomAt(StationLayout.Rooms, sign.Row, sign.Col)
		H.ok(room ~= nil, `sign {sign.Text} is outside every room`)
		local firstLine = string.split(sign.Text, "\n")[1]
		H.eq(firstLine, string.upper(room :: string), "sign must match the HUD room name")
	end
end)

return H
