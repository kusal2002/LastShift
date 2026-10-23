--!strict
-- The local player's saved progress as last sent by the server. Read-only on the client.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)

local ProfileState = {}

ProfileState.changed = Signal.new() -- fires with the new ProfileView

local current: Types.ProfileView? = nil

function ProfileState.get(): Types.ProfileView?
	return current
end

function ProfileState.owns(id: string): boolean
	local view = current
	if view == nil then
		return false
	end
	return table.find(view.Owned, id) ~= nil
end

function ProfileState.start()
	Remotes.getClient(Remotes.Names.ProfileUpdate).OnClientEvent:Connect(function(view: any)
		if type(view) ~= "table" or type(view.Credits) ~= "number" or type(view.Owned) ~= "table" then
			return
		end
		current = view :: Types.ProfileView
		ProfileState.changed:Fire(current)
	end)
end

return ProfileState
