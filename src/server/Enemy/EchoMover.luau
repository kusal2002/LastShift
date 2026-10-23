--!strict
-- Moves the Echo along PathfindingService paths. Handles failed computations, blocked paths,
-- rate-limited re-pathing, and stuck detection. Must be updated from a thread that may yield
-- (ComputeAsync yields).
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyConfig = require(ReplicatedStorage.Shared.Config.Enemy)

export type Status = "Idle" | "Moving" | "Arrived" | "Failed"

export type Mover = {
	setGoal: (position: Vector3, speed: number, repathInterval: number) -> (),
	stop: () -> (),
	getStatus: () -> Status,
	update: () -> (),
	destroy: () -> (),
}

local config = EnemyConfig.Path

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local EchoMover = {}

function EchoMover.new(humanoid: Humanoid, root: BasePart): Mover
	local path = PathfindingService:CreatePath({
		AgentRadius = config.AgentRadius,
		AgentHeight = config.AgentHeight,
		AgentCanJump = false,
		AgentCanClimb = false,
		WaypointSpacing = 4,
	})

	local goal: Vector3? = nil
	local computedFor: Vector3? = nil
	local waypoints: { PathWaypoint } = {}
	local index = 1
	local repathInterval = config.RepathIdle
	local lastCompute = -math.huge
	local forceRepath = false
	local status: Status = "Idle"
	local lastPosition = root.Position
	local lastProgress = os.clock()
	local stuckCount = 0

	local blockedConnection = path.Blocked:Connect(function(blockedIndex: number)
		if blockedIndex >= index then
			forceRepath = true
		end
	end)

	local function finish(newStatus: Status)
		status = newStatus
		goal = nil
		computedFor = nil
		waypoints = {}
		stuckCount = 0
		humanoid:MoveTo(root.Position)
	end

	local function compute(target: Vector3): boolean
		lastCompute = os.clock()
		computedFor = target
		forceRepath = false
		local ok = pcall(function()
			path:ComputeAsync(root.Position, target)
		end)
		if not ok or path.Status ~= Enum.PathStatus.Success then
			waypoints = {}
			return false
		end
		waypoints = path:GetWaypoints()
		index = math.min(2, #waypoints) -- waypoint 1 is the start position
		return true
	end

	local mover = {}

	function mover.setGoal(position: Vector3, speed: number, interval: number)
		humanoid.WalkSpeed = speed
		repathInterval = interval
		local current = goal
		if current == nil or (current - position).Magnitude > 2 then
			goal = position
			status = "Moving"
			lastProgress = os.clock()
			lastPosition = root.Position
		end
	end

	function mover.stop()
		if goal ~= nil or status == "Moving" then
			finish("Idle")
		end
	end

	function mover.getStatus(): Status
		return status
	end

	function mover.update()
		local target = goal
		if target == nil then
			return
		end
		local now = os.clock()
		if flatDistance(root.Position, target) <= config.WaypointReach then
			finish("Arrived")
			return
		end

		local previous = computedFor
		local goalMoved = previous == nil or (previous - target).Magnitude > 4
		local needsPath = #waypoints == 0
			or forceRepath
			or (goalMoved and now - lastCompute >= repathInterval)
		if needsPath and now - lastCompute >= 0.25 then
			if not compute(target) then
				-- Pathing failed: walk straight if close, otherwise report failure.
				if (target - root.Position).Magnitude <= config.DirectWalkDistance then
					humanoid:MoveTo(target)
				else
					finish("Failed")
					return
				end
			end
		end

		local waypoint = waypoints[index]
		if waypoint and flatDistance(root.Position, waypoint.Position) <= config.WaypointReach then
			index += 1
			waypoint = waypoints[index]
		end
		if waypoint then
			humanoid:MoveTo(waypoint.Position)
		elseif #waypoints > 0 then
			humanoid:MoveTo(target)
		end

		-- Stuck detection: no real progress for StuckSeconds.
		if (root.Position - lastPosition).Magnitude >= config.StuckDistance then
			lastPosition = root.Position
			lastProgress = now
		elseif now - lastProgress >= config.StuckSeconds then
			lastProgress = now
			stuckCount += 1
			forceRepath = true
			if stuckCount >= config.StuckLimit then
				finish("Failed")
			end
		end
	end

	function mover.destroy()
		blockedConnection:Disconnect()
		path:Destroy()
	end

	return mover
end

return EchoMover
