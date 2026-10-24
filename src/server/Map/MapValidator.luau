--!strict
-- Checks that a station map has everything the game needs.
-- check(): instant structural check (required tags, room volumes, anchoring). Runs at every
--   server start; a hand-built map with errors is replaced by the generated graybox.
-- checkNavigation(): test-paths the Echo between its patrol points and a player to every
--   objective and the exit. Yields; run on demand (Studio dev key F11) or after start in Studio.
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Tags = require(Shared.Config.Tags)
local Requirements = require(Shared.Config.MapRequirements)
local EnemyConfig = require(Shared.Config.Enemy)
local MapRules = require(Shared.Logic.MapRules)
local Log = require(Shared.Util.Log)
local RoomVolumes = require(script.Parent.RoomVolumes)

local MapValidator = {}

-- Markers that should sit inside a named room.
local ROOM_CHECKED: { [string]: boolean } = {
	[Tags.StationSpawn] = true,
	[Tags.FuseSpawn] = true,
	[Tags.FusePanel] = true,
	[Tags.RadioConsole] = true,
	[Tags.FrequencyBoard] = true,
	[Tags.EvidenceSpawn] = true,
	[Tags.RiskyEvidenceSpawn] = true,
	[Tags.EchoSpawn] = true,
	[Tags.EchoPatrol] = true,
	[Tags.ChargingStation] = true,
	[Tags.PowerSwitch] = true,
	[Tags.DecoySpawn] = true,
	[Tags.StationLight] = true,
}

local REACH_TOLERANCE = 7 -- a player within this distance can use a prompt

local function tagged(tag: string, container: Instance): { Instance }
	local list = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsDescendantOf(container) then
			table.insert(list, instance)
		end
	end
	return list
end

local function taggedParts(tag: string, container: Instance): { BasePart }
	local list: { BasePart } = {}
	for _, instance in tagged(tag, container) do
		if instance:IsA("BasePart") then
			table.insert(list, instance)
		end
	end
	table.sort(list, function(a: BasePart, b: BasePart)
		return a:GetFullName() < b:GetFullName()
	end)
	return list
end

function MapValidator.summarize(station: Instance): MapRules.Summary
	local volumes = RoomVolumes.collect(station)
	local tagCounts: { [string]: number } = {}
	local nonParts: { string } = {}
	local unanchored: { string } = {}
	local outside: { string } = {}
	for _, requirement in Requirements do
		local count = 0
		for _, instance in tagged(requirement.tag, station) do
			if instance:IsA("BasePart") then
				count += 1
				if not instance.Anchored then
					table.insert(unanchored, instance:GetFullName())
				end
				if
					ROOM_CHECKED[requirement.tag]
					and RoomVolumes.nameAt(volumes, instance.Position) == nil
				then
					table.insert(outside, `{instance:GetFullName()} ({requirement.tag})`)
				end
			else
				table.insert(nonParts, `{instance:GetFullName()} ({requirement.tag})`)
			end
		end
		tagCounts[requirement.tag] = count
	end
	local roomNames: { string } = {}
	for _, volume in volumes do
		table.insert(roomNames, RoomVolumes.nameOf(volume))
	end
	return {
		tagCounts = tagCounts,
		roomNames = roomNames,
		nonParts = nonParts,
		unanchored = unanchored,
		outsideRooms = outside,
	}
end

function MapValidator.check(station: Instance): { MapRules.Issue }
	return MapRules.check(MapValidator.summarize(station), Requirements)
end

-- Logs issues: errors always, warnings as info lines.
function MapValidator.report(label: string, issues: { MapRules.Issue })
	local errors = MapRules.errorCount(issues)
	for _, issue in issues do
		if issue.level == "Error" then
			Log.warn("Map", "ERROR: %s", issue.message)
		else
			Log.info("Map", "warning: %s", issue.message)
		end
	end
	Log.info("Map", "%s: %d error(s), %d warning(s)", label, errors, #issues - errors)
end

-- Where a player would stand to use a part: in front of solid wall-mounted parts, at markers.
local function approachPoint(part: BasePart): Vector3
	if part.CanCollide then
		return part.Position + part.CFrame.LookVector * (part.Size.Z / 2 + 2.5)
	end
	return part.Position
end

local function computeReach(path: Path, from: Vector3, to: Vector3): (boolean, string)
	local ok, err = pcall(function()
		path:ComputeAsync(from, to)
	end)
	if not ok then
		return false, `pathfinding error ({err})`
	end
	if path.Status == Enum.PathStatus.Success then
		return true, ""
	end
	if path.Status == Enum.PathStatus.ClosestNoPath then
		local waypoints = path:GetWaypoints()
		local last = waypoints[#waypoints]
		if last and (last.Position - to).Magnitude <= REACH_TOLERANCE then
			return true, ""
		end
	end
	return false, path.Status.Name
end

-- Test-paths the map. Exit doors are opened during the test so the exit counts as reachable.
function MapValidator.checkNavigation(station: Instance): { MapRules.Issue }
	local issues: { MapRules.Issue } = {}
	local function fail(message: string)
		table.insert(issues, { level = "Error", message = message })
	end

	local doors = taggedParts(Tags.ExitDoor, station)
	local doorCollide: { [BasePart]: boolean } = {}
	for _, door in doors do
		doorCollide[door] = door.CanCollide
		door.CanCollide = false
	end

	local echoPath = PathfindingService:CreatePath({
		AgentRadius = EnemyConfig.Path.AgentRadius,
		AgentHeight = EnemyConfig.Path.AgentHeight,
		AgentCanJump = false,
		AgentCanClimb = false,
	})
	local playerPath =
		PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })

	local echoSpawn = taggedParts(Tags.EchoSpawn, station)[1]
	if echoSpawn then
		for _, patrol in taggedParts(Tags.EchoPatrol, station) do
			local reachable, why = computeReach(echoPath, echoSpawn.Position, patrol.Position)
			if not reachable then
				fail(`Echo can't reach patrol point {patrol:GetFullName()} ({why})`)
			end
		end
	else
		fail("no EchoSpawn to test from")
	end

	local start = taggedParts(Tags.StationSpawn, station)[1]
	if start then
		local targets = {
			Tags.FuseSpawn,
			Tags.FusePanel,
			Tags.RadioConsole,
			Tags.FrequencyBoard,
			Tags.EvidenceSpawn,
			Tags.RiskyEvidenceSpawn,
			Tags.ChargingStation,
			Tags.PowerSwitch,
			Tags.DecoySpawn,
		}
		for _, tag in targets do
			for _, part in taggedParts(tag, station) do
				local reachable, why = computeReach(playerPath, start.Position, approachPoint(part))
				if not reachable then
					fail(`players can't reach {part:GetFullName()} ({tag}, {why})`)
				end
			end
		end
		for _, zone in taggedParts(Tags.ExtractionZone, station) do
			local floor = zone.Position - Vector3.new(0, zone.Size.Y / 2 - 2, 0)
			local reachable, why = computeReach(playerPath, start.Position, floor)
			if not reachable then
				fail(`players can't reach the exit {zone:GetFullName()} ({why})`)
			end
		end
	else
		fail("no StationSpawn to test from")
	end

	for door, collide in doorCollide do
		door.CanCollide = collide
	end
	echoPath:Destroy()
	playerPath:Destroy()
	return issues
end

return MapValidator
