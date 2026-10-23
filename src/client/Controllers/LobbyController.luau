--!strict
-- Lobby panel: player/ready count, countdown, and the PLAY / CANCEL button.
-- Also shown to anyone not inside the station during a round, so they can queue for the next one.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Client = script.Parent.Parent
local State = require(Client.State)
local Theme = require(Client.UI.Theme)

local LobbyController = {}

function LobbyController.start()
	local playRequest = Remotes.getClient(Remotes.Names.PlayRequest)
	local gui = Theme.screenGui("Lobby", 5)
	local panel = Theme.panel(gui, "Panel", 440)
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -20)

	Theme.label(panel, "LAST SHIFT", 28, Theme.Colors.Amber, true)
	Theme.label(panel, "SIGNAL LOST", 14, Theme.Colors.Muted)
	local status = Theme.label(panel, "", 16)
	local countdown = Theme.label(panel, "", 18, Theme.Colors.Amber, true)
	local button = Theme.button(panel, "PLAY")

	button.Activated:Connect(function()
		local snapshot = State.get()
		if snapshot then
			playRequest:FireServer(not snapshot.IsReady)
		end
	end)

	local function render()
		local snapshot = State.get()
		if snapshot == nil then
			gui.Enabled = false
			return
		end
		local inRound = snapshot.IsParticipant and snapshot.Phase ~= "Lobby"
		gui.Enabled = not inRound or (snapshot.Status ~= "Alive" and snapshot.Phase ~= "Results")
		button.Text = if snapshot.IsReady then "CANCEL" else "PLAY"

		if snapshot.Phase == "Lobby" then
			status.Text = `{snapshot.ReadyCount}/{snapshot.PlayerCount} ready  (needs {snapshot.MinPlayers})`
			local left = State.secondsLeft()
			countdown.Text = if left then `DEPLOYING IN {math.ceil(left)}` else "Press PLAY to start a shift"
		else
			local statusText: { [string]: string } = {
				Escaped = "You made it out. Waiting for the shift to end.",
				Dead = "You were lost. Waiting for the shift to end.",
				Lost = "You were left behind.",
			}
			local own: Types.PlayerStatus? = snapshot.Status
			status.Text = (own and statusText[own]) or "A shift is in progress."
			countdown.Text = if snapshot.IsReady
				then "You're queued for the next shift"
				else "Press PLAY to queue for the next shift"
		end
	end

	State.changed:Connect(render)
	State.clock:Connect(render)
	render()
end

return LobbyController
