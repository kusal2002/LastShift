--!strict
-- Room volumes: invisible boxes tagged "RoomVolume" with a RoomName attribute. They tell the
-- game which room a position is in (HUD team list, Mimic calls, blackouts, lamp rooms).
-- The generated graybox creates them from StationLayout.Rooms; a hand-built map places them
-- in Studio.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Config.Tags)

local RoomVolumes = {}

function RoomVolumes.nameOf(volume: BasePart): string
	local name = volume:GetAttribute("RoomName")
	return if type(name) == "string" then name else ""
end

function RoomVolumes.contains(volume: BasePart, position: Vector3): boolean
	local localPoint = volume.CFrame:PointToObjectSpace(position)
	local half = volume.Size / 2
	return math.abs(localPoint.X) <= half.X
		and math.abs(localPoint.Y) <= half.Y
		and math.abs(localPoint.Z) <= half.Z
end

-- Every RoomVolume part inside `container`.
function RoomVolumes.collect(container: Instance): { BasePart }
	local volumes: { BasePart } = {}
	for _, instance in CollectionService:GetTagged(Tags.RoomVolume) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(container) then
			table.insert(volumes, instance)
		end
	end
	return volumes
end

-- Name of the first room containing `position`, or nil.
function RoomVolumes.nameAt(volumes: { BasePart }, position: Vector3): string?
	for _, volume in volumes do
		if RoomVolumes.contains(volume, position) then
			local name = RoomVolumes.nameOf(volume)
			if name ~= "" then
				return name
			end
		end
	end
	return nil
end

return RoomVolumes
