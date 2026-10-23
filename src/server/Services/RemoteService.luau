--!strict
-- Creates every RemoteEvent at startup and wraps client->server handlers with rate limiting.
-- Handlers must still validate argument types themselves.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local RateLimiter = require(Shared.Util.RateLimiter)
local Log = require(Shared.Util.Log)

export type Limit = { capacity: number, perSecond: number }
export type NotifyKind = "info" | "success" | "warn" | "danger"

local RemoteService = {}

local remotes: { [string]: RemoteEvent } = {}

function RemoteService.Init()
	local folder = Instance.new("Folder")
	folder.Name = Remotes.FolderName
	for _, value in Remotes.Names do
		local name = tostring(value)
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		remotes[name] = remote
	end
	folder.Parent = ReplicatedStorage
end

local function get(name: string): RemoteEvent
	local remote: RemoteEvent? = remotes[name]
	if remote == nil then
		error(`Unknown remote {name}`)
	end
	return remote
end

function RemoteService.fire(player: Player, name: string, ...: any)
	get(name):FireClient(player, ...)
end

function RemoteService.notify(player: Player, text: string, kind: NotifyKind?)
	if player.Parent == Players then
		get(Remotes.Names.Notify):FireClient(player, text, kind or "info")
	end
end

-- Connects a rate-limited handler. Returns a function that disconnects it.
function RemoteService.listen(name: string, limit: Limit, handler: (Player, ...any) -> ()): () -> ()
	local limiter = RateLimiter.new(limit.capacity, limit.perSecond)
	local eventConnection = get(name).OnServerEvent:Connect(function(player: Player, ...: any)
		if not limiter:check(player) then
			Log.debug("Remote", "Rate limited %s on %s", player.Name, name)
			return
		end
		handler(player, ...)
	end)
	local leaveConnection = Players.PlayerRemoving:Connect(function(player: Player)
		limiter:remove(player)
	end)
	return function()
		eventConnection:Disconnect()
		leaveConnection:Disconnect()
	end
end

return RemoteService
