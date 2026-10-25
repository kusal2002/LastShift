--!strict
-- Judges a summary of a station map against the requirements. Pure: the map validator builds
-- the summary from real instances; tests build it by hand.
export type Requirement = { tag: string, min: number, recommended: number?, what: string }

export type Summary = {
	tagCounts: { [string]: number }, -- tagged BaseParts found inside the station
	roomNames: { string }, -- RoomName of every RoomVolume, in any order ("" if missing)
	nonParts: { string }, -- tagged instances that are not BaseParts (they are ignored by the game)
	unanchored: { string }, -- tagged parts that are not anchored
	outsideRooms: { string }, -- important markers not inside any RoomVolume
}

export type Issue = { level: "Error" | "Warning", message: string }

local MapRules = {}

function MapRules.check(summary: Summary, requirements: { Requirement }): { Issue }
	local issues: { Issue } = {}
	local function add(level: "Error" | "Warning", message: string)
		table.insert(issues, { level = level, message = message })
	end

	for _, requirement in requirements do
		local count = summary.tagCounts[requirement.tag] or 0
		local recommended = requirement.recommended
		if count < requirement.min then
			add(
				"Error",
				`{requirement.tag}: found {count}, need at least {requirement.min} ({requirement.what})`
			)
		elseif recommended ~= nil and count < recommended then
			add("Warning", `{requirement.tag}: found {count}, {recommended} recommended ({requirement.what})`)
		end
	end

	local seen: { [string]: boolean } = {}
	for _, name in summary.roomNames do
		if name == "" then
			add("Error", "a RoomVolume has no RoomName attribute")
		elseif seen[name] then
			add("Error", `two RoomVolumes are both named "{name}"`)
		end
		seen[name] = true
	end

	for _, path in summary.nonParts do
		add("Error", `{path} is tagged but is not a part (tag the part itself, not a Model)`)
	end
	for _, path in summary.unanchored do
		add("Warning", `{path} is tagged but not anchored`)
	end
	for _, path in summary.outsideRooms do
		add("Warning", `{path} is not inside any RoomVolume (HUD will show no room there)`)
	end
	return issues
end

function MapRules.errorCount(issues: { Issue }): number
	local count = 0
	for _, issue in issues do
		if issue.level == "Error" then
			count += 1
		end
	end
	return count
end

return MapRules
