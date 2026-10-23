--!strict
-- End-of-round results with Play Again / Return to Lobby.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Client = script.Parent.Parent
local State = require(Client.State)
local Theme = require(Client.UI.Theme)

local REASON_TEXT: { [string]: string } = {
	Extracted = "The team got out.",
	AllLost = "Nobody made it out.",
	TimeUp = "The shift ran out before the relay was restored.",
	ExtractionMissed = "The exit sealed before anyone reached it.",
}

local STATUS_TEXT: { [string]: string } = {
	Escaped = "Escaped",
	Lost = "Left behind",
	Dead = "Killed",
	Left = "Disconnected",
	Alive = "In the station",
}

local ResultsController = {}

function ResultsController.start()
	local playRequest = Remotes.getClient(Remotes.Names.PlayRequest)
	local gui = Theme.screenGui("Results", 15)
	local panel = Theme.panel(gui, "Panel", 460)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)

	local header = Theme.label(panel, "", 28, Theme.Colors.Green, true)
	local reason = Theme.label(panel, "", 16)
	local stats = Theme.label(panel, "", 15)
	local team = Theme.label(panel, "", 14, Theme.Colors.Muted)
	local row = Theme.row(panel, 48)
	local againButton = Theme.rowButton(row, "PLAY AGAIN", 2)
	local lobbyButton = Theme.rowButton(row, "LOBBY", 2, Theme.Colors.Muted)

	againButton.Activated:Connect(function()
		gui.Enabled = false
		playRequest:FireServer(true)
	end)
	lobbyButton.Activated:Connect(function()
		gui.Enabled = false
	end)

	Remotes.getClient(Remotes.Names.Results).OnClientEvent:Connect(function(raw: any)
		if type(raw) ~= "table" or type(raw.Success) ~= "boolean" then
			return
		end
		local results = raw :: Types.Results
		header.Text = if results.Success then "SHIFT COMPLETE" else "SIGNAL LOST"
		header.TextColor3 = if results.Success then Theme.Colors.Green else Theme.Colors.Red
		reason.Text = REASON_TEXT[results.Reason] or results.Reason

		local evidence = if #results.Evidence > 0 then table.concat(results.Evidence, ", ") else "none"
		stats.Text = table.concat({
			`Your status: {STATUS_TEXT[results.YourStatus] or results.YourStatus}`,
			`Objectives: {results.ObjectivesCompleted}/{results.ObjectivesTotal}`,
			`Evidence: {evidence}`,
			`Shift time: {State.formatTime(results.DurationSeconds)}`,
		}, "\n")

		local lines = { "TEAM" }
		for _, member in results.Team do
			table.insert(lines, `{member.Name} - {STATUS_TEXT[member.Status] or member.Status}`)
		end
		team.Text = table.concat(lines, "\n")
		gui.Enabled = true
	end)

	-- Hide stale results when the next briefing starts.
	State.changed:Connect(function()
		local snapshot = State.get()
		if snapshot and snapshot.Phase == "Briefing" and snapshot.IsParticipant then
			gui.Enabled = false
		end
	end)
end

return ResultsController
