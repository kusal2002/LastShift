--!strict
-- Lobby panel: your level, credits and badge; player/ready count; countdown; PLAY / CANCEL;
-- and the CASEBOOK and LOCKER screens. Also shown to anyone not inside the station during a
-- round, so they can queue for the next one.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Cosmetics = require(Shared.Config.Cosmetics)
local Client = script.Parent.Parent
local State = require(Client.State)
local ProfileState = require(Client.ProfileState)
local Settings = require(Client.Settings)
local Theme = require(Client.UI.Theme)
local CasebookController = require(script.Parent.CasebookController)
local LockerController = require(script.Parent.LockerController)
local SettingsController = require(script.Parent.SettingsController)
local HowToPlayController = require(script.Parent.HowToPlayController)

local LobbyController = {}

function LobbyController.start()
	local playRequest = Remotes.getClient(Remotes.Names.PlayRequest)
	local gui = Theme.screenGui("Lobby", 5)
	local panel = Theme.panel(gui, "Panel", 440)
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -20)

	Theme.label(panel, "LAST SHIFT", 28, Theme.Colors.Amber, true)
	Theme.label(panel, "SIGNAL LOST", 14, Theme.Colors.Muted)
	local profileLine = Theme.label(panel, "Loading profile...", 15, Theme.Colors.Green, true)
	local progressLine = Theme.label(panel, "", 13, Theme.Colors.Muted)
	local status = Theme.label(panel, "", 16)
	local countdown = Theme.label(panel, "", 18, Theme.Colors.Amber, true)
	local button = Theme.button(panel, "PLAY")
	local menuRow = Theme.row(panel, 44)
	local casebookButton = Theme.rowButton(menuRow, "CASEBOOK", 2, Theme.Colors.Muted)
	local lockerButton = Theme.rowButton(menuRow, "LOCKER", 2, Theme.Colors.Muted)
	local helpRow = Theme.row(panel, 44)
	local settingsButton = Theme.rowButton(helpRow, "SETTINGS", 2, Theme.Colors.Muted)
	local howToButton = Theme.rowButton(helpRow, "HOW TO PLAY", 2, Theme.Colors.Muted)

	-- Only one lobby screen open at a time.
	local function closeScreens()
		CasebookController.close()
		LockerController.close()
		SettingsController.close()
		HowToPlayController.close()
	end

	button.Activated:Connect(function()
		local snapshot = State.get()
		if snapshot then
			playRequest:FireServer(not snapshot.IsReady)
		end
	end)
	local function bind(target: TextButton, screen: { toggle: () -> () })
		target.Activated:Connect(function()
			closeScreens()
			screen.toggle()
		end)
	end
	bind(casebookButton, CasebookController)
	bind(lockerButton, LockerController)
	bind(settingsButton, SettingsController)
	bind(howToButton, HowToPlayController)

	local function renderProfile()
		local view = ProfileState.get()
		if view == nil then
			profileLine.Text = "Loading profile..."
			progressLine.Text = ""
			return
		end
		local badge = Cosmetics.ById[view.Equipped.Badge or ""]
		local badgeText = if badge then `  ·  {badge.DisplayName}` else ""
		profileLine.Text = `LEVEL {view.Level}  ·  {view.Credits} CREDITS{badgeText}`
		local xpText = if view.ToNext > 0
			then `XP {view.IntoLevel}/{view.ToNext} to level {view.Level + 1}`
			else "Max level"
		local warning = if view.Persistent then "" else "   (Studio test data: not saved)"
		progressLine.Text = xpText .. warning
	end

	local function render()
		local snapshot = State.get()
		if snapshot == nil then
			gui.Enabled = false
			return
		end
		local inRound = snapshot.IsParticipant and snapshot.Phase ~= "Lobby"
		gui.Enabled = not inRound or (snapshot.Status ~= "Alive" and snapshot.Phase ~= "Results")
		if
			not gui.Enabled
			or (snapshot.IsParticipant and snapshot.Status == "Alive" and snapshot.Phase ~= "Lobby")
		then
			CasebookController.close()
			LockerController.close()
			HowToPlayController.close()
		end
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

	ProfileState.changed:Connect(function(view: Types.ProfileView)
		Settings.loadFrom(view.Settings)
		renderProfile()
	end)
	State.changed:Connect(render)
	State.clock:Connect(render)
	renderProfile()
	render()
end

return LobbyController
