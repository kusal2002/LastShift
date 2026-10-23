--!strict
-- Holds the latest round snapshot from the server and a slow clock for countdown text.
-- Read-only on the client: nothing here can change game state.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)

local State = {}

State.changed = Signal.new() -- fires with the new snapshot
State.clock = Signal.new() -- fires about four times a second

local current: Types.Snapshot? = nil

function State.get(): Types.Snapshot?
	return current
end

function State.secondsLeft(): number?
	local snapshot = current
	if snapshot == nil then
		return nil
	end
	local endsAt = snapshot.PhaseEndsAt
	if endsAt == nil then
		return nil
	end
	return math.max(0, endsAt - Workspace:GetServerTimeNow())
end

function State.formatTime(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%02d:%02d", whole // 60, whole % 60)
end

function State.start()
	Remotes.getClient(Remotes.Names.RoundSnapshot).OnClientEvent:Connect(function(snapshot: any)
		if type(snapshot) ~= "table" then
			return
		end
		current = snapshot :: Types.Snapshot
		State.changed:Fire(current)
	end)
	Remotes.getClient(Remotes.Names.SnapshotRequest):FireServer()

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator >= 0.25 then
			accumulator = 0
			State.clock:Fire()
		end
	end)
end

return State
