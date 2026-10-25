-- Tests for the map rules, and that the generated fallback station passes them.
local H = require("./harness")
local MapRules = require("../src/shared/Logic/MapRules")
local MapGrid = require("../src/shared/Logic/MapGrid")
local Requirements = require("../src/shared/Config/MapRequirements")
local Evidence = require("../src/shared/Config/Evidence")
local Anomalies = require("../src/shared/Config/Anomalies")
local StationLayout = require("../src/server/Map/StationLayout")

local function summary(overrides: { [string]: any }?): any
	local base = { tagCounts = {}, roomNames = {}, nonParts = {}, unanchored = {}, outsideRooms = {} }
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

local function levels(issues: { any }, level: string): number
	local count = 0
	for _, issue in issues do
		if issue.level == level then
			count += 1
		end
	end
	return count
end

H.test("missing required objects are errors, thin ones are warnings", function()
	local rules = {
		{ tag = "A", min = 1, what = "a" },
		{ tag = "B", min = 1, recommended = 3, what = "b" },
	}
	local issues = MapRules.check(summary({ tagCounts = { B = 2 } }), rules)
	H.eq(levels(issues, "Error"), 1, "A missing")
	H.eq(levels(issues, "Warning"), 1, "B below recommended")
	H.eq(MapRules.errorCount(issues), 1)
	H.eq(#MapRules.check(summary({ tagCounts = { A = 1, B = 3 } }), rules), 0)
end)

H.test("room names must exist and be unique", function()
	local issues = MapRules.check(summary({ roomNames = { "Storage", "", "Storage" } }), {})
	H.eq(levels(issues, "Error"), 2)
end)

H.test("tagged models, loose parts and markers outside rooms are reported", function()
	local issues = MapRules.check(
		summary({
			nonParts = { "Station.Desk" },
			unanchored = { "Station.Panel" },
			outsideRooms = { "Station.Spawn" },
		}),
		{}
	)
	H.eq(levels(issues, "Error"), 1)
	H.eq(levels(issues, "Warning"), 2)
end)

H.test("requirements stay in step with evidence and noise maker counts", function()
	local byTag = {}
	for _, requirement in Requirements do
		byTag[requirement.tag] = requirement
	end
	H.ok(byTag.EvidenceSpawn.min >= Evidence.SpawnCount, "enough evidence spots for a round")
	local mostDecoys = 0
	for _, profile in Anomalies.List do
		mostDecoys = math.max(mostDecoys, profile.DecoyCount)
	end
	H.ok((byTag.DecoySpawn.recommended or 0) >= mostDecoys)
end)

-- The generated graybox is the fallback map, so it must always pass.
local MARKER_TAGS = {
	S = { "StationSpawn" },
	F = { "FuseSpawn" },
	P = { "FusePanel" },
	R = { "RadioConsole" },
	B = { "FrequencyBoard" },
	E = { "EvidenceSpawn" },
	K = { "RiskyEvidenceSpawn" },
	X = { "ExtractionZone" },
	D = { "ExitDoor" },
	Z = { "EchoSpawn", "EchoPatrol" },
	L = { "StationLight", "EchoPatrol" },
	C = { "StationLight", "EchoPatrol" },
	Q = { "ChargingStation" },
	G = { "PowerSwitch" },
	N = { "DecoySpawn" },
}

H.test("the generated fallback station meets every requirement", function()
	local counts = { RoomVolume = #StationLayout.Rooms }
	for _, marker in MapGrid.markers(StationLayout.Rows) do
		for _, tag in MARKER_TAGS[marker.char] or {} do
			counts[tag] = (counts[tag] or 0) + 1
		end
	end
	local names = {}
	for _, room in StationLayout.Rooms do
		table.insert(names, room.Name)
	end
	local issues = MapRules.check(summary({ tagCounts = counts, roomNames = names }), Requirements)
	H.eq(MapRules.errorCount(issues), 0, issues[1] and issues[1].message or "")
end)

return H
