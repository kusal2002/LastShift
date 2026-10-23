--!strict
-- Opens the exit and decides who has escaped. A player escapes by staying inside an
-- ExtractionZone for ExtractionHoldSeconds while extraction is open.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local RoundConfig = require(Shared.Config.Round)
local Tags = require(Shared.Config.Tags)
local MapService = require(script.Parent.MapService)
local InteractionService = require(script.Parent.InteractionService)

type DoorState = { CanCollide: boolean, Transparency: number, Color: Color3 }

local OPEN_DOOR_COLOR = Color3.fromRGB(96, 200, 124)

local ExtractionService = {}

local open = false
local holdTimes: { [Player]: number } = {}
local savedDoors: { [BasePart]: DoorState } = {}

local function isInside(position: Vector3, zone: BasePart): boolean
	local localPoint = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(localPoint.X) <= half.X
		and math.abs(localPoint.Y) <= half.Y
		and math.abs(localPoint.Z) <= half.Z
end

function ExtractionService.isOpen(): boolean
	return open
end

function ExtractionService.open()
	open = true
	for _, door in MapService.getTagged(Tags.ExitDoor) do
		if savedDoors[door] == nil then
			savedDoors[door] =
				{ CanCollide = door.CanCollide, Transparency = door.Transparency, Color = door.Color }
		end
		door.CanCollide = false
		door.Transparency = 0.8
		door.Color = OPEN_DOOR_COLOR
	end
	for _, zone in MapService.getTagged(Tags.ExtractionZone) do
		zone.Transparency = 0.9
	end
end

function ExtractionService.close()
	open = false
	table.clear(holdTimes)
	for door, state in savedDoors do
		door.CanCollide = state.CanCollide
		door.Transparency = state.Transparency
		door.Color = state.Color
	end
	table.clear(savedDoors)
	for _, zone in MapService.getTagged(Tags.ExtractionZone) do
		zone.Transparency = 1
	end
end

-- Advances hold timers. Returns players who escaped this tick, and players who just entered a zone.
function ExtractionService.update(dt: number, candidates: { Player }): ({ Player }, { Player })
	local escaped: { Player } = {}
	local entered: { Player } = {}
	if not open then
		return escaped, entered
	end
	local zones = MapService.getTagged(Tags.ExtractionZone)
	for _, player in candidates do
		local root = InteractionService.getRoot(player)
		local inZone = false
		if root then
			for _, zone in zones do
				if isInside(root.Position, zone) then
					inZone = true
					break
				end
			end
		end
		if inZone then
			local previous = holdTimes[player]
			if previous == nil then
				table.insert(entered, player)
			end
			local held = (previous or 0) + dt
			if held >= RoundConfig.ExtractionHoldSeconds then
				holdTimes[player] = nil
				table.insert(escaped, player)
			else
				holdTimes[player] = held
			end
		else
			holdTimes[player] = nil
		end
	end
	return escaped, entered
end

function ExtractionService.forget(player: Player)
	holdTimes[player] = nil
end

return ExtractionService
