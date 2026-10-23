--!strict
-- Sends audio cues to clients. Clients play the sound if a verified asset is configured and
-- always show a subtitle. Cue ids come from Config/Audio; unknown ids are rejected.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local AudioConfig = require(Shared.Config.Audio)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Log = require(Shared.Util.Log)
local RemoteService = require(script.Parent.RemoteService)
local InteractionService = require(script.Parent.InteractionService)

local AudioEventService = {}

function AudioEventService.play(players: { Player }, cueId: string, text: string?, position: Vector3?)
	if AudioConfig.Cues[cueId] == nil then
		Log.warn("Audio", "Unknown cue %s", cueId)
		return
	end
	local payload: Types.AudioCuePayload = { Cue = cueId, Text = text, Position = position }
	for _, player in players do
		if player.Parent == Players then
			RemoteService.fire(player, Remotes.Names.AudioCue, payload)
		end
	end
end

-- Plays a spatial cue only to players within `radius` of `position`.
function AudioEventService.playNear(
	players: { Player },
	cueId: string,
	position: Vector3,
	radius: number,
	text: string?
)
	local listeners = {}
	for _, player in players do
		local root = InteractionService.getRoot(player)
		if root and (root.Position - position).Magnitude <= radius then
			table.insert(listeners, player)
		end
	end
	if #listeners > 0 then
		AudioEventService.play(listeners, cueId, text, position)
	end
end

return AudioEventService
