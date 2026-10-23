--!strict
-- Every RemoteEvent name in one place. The server creates them at startup.
local Remotes = {}

Remotes.FolderName = "Remotes"

Remotes.Names = table.freeze({
	-- server -> client
	RoundSnapshot = "RoundSnapshot",
	Notify = "Notify",
	Results = "Results",
	CalibrationOpen = "CalibrationOpen",
	CalibrationClose = "CalibrationClose",
	AudioCue = "AudioCue", -- (payload: AudioCuePayload)
	DecisionOpen = "DecisionOpen", -- (options: DecisionOptions)
	DecisionClose = "DecisionClose", -- ()
	LightFlicker = "LightFlicker", -- (room: string, seconds: number) cosmetic only
	-- client -> server
	SnapshotRequest = "SnapshotRequest", -- () client asks for current state once on join
	PlayRequest = "PlayRequest", -- (wantsReady: boolean)
	CalibrationSubmit = "CalibrationSubmit", -- (frequency: number)
	CalibrationCancel = "CalibrationCancel", -- ()
	SprintRequest = "SprintRequest", -- (wantsSprint: boolean)
	FlashlightToggle = "FlashlightToggle", -- ()
	DecoyUse = "DecoyUse", -- () place the carried noise maker
	DecisionSubmit = "DecisionSubmit", -- (anomalyId: string, ending: "Transmit" | "Abort")
	DevCommand = "DevCommand", -- (command: string) Studio only; ignored on live servers
})

-- Client helper: waits for a remote created by the server.
function Remotes.getClient(name: string): RemoteEvent
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local folder = ReplicatedStorage:WaitForChild(Remotes.FolderName)
	local remote = folder:WaitForChild(name)
	if not remote:IsA("RemoteEvent") then
		error(`Remote {name} is not a RemoteEvent`)
	end
	return remote
end

return Remotes
