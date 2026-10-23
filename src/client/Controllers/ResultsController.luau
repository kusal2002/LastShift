--!strict
-- End-of-round results: outcome, the anomaly revealed, the team's report and ending,
-- credits and XP with a breakdown, and the team. Play Again / Lobby buttons.
-- The content scrolls so it fits on small screens.
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
	TimeUp = "The shift ran out.",
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

local function reportText(results: Types.Results): string
	if results.Classification == "Correct" then
		return `Your report: {results.ClassifiedAs or "?"} (correct)`
	elseif results.Classification == "Incorrect" then
		return `Your report: {results.ClassifiedAs or "?"} (wrong)`
	elseif results.Ending ~= "None" then
		return "Your report: unsure"
	end
	return "No report was filed."
end

local function endingText(results: Types.Results): string
	if results.Ending == "Transmit" then
		return if results.TransmitCompleted
			then "Ending: transmission sent"
			else "Ending: transmission cut short"
	elseif results.Ending == "Abort" then
		return "Ending: aborted"
	end
	return "Ending: none"
end

function ResultsController.start()
	local playRequest = Remotes.getClient(Remotes.Names.PlayRequest)
	local gui = Theme.screenGui("Results", 15)

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.92, 0.85)
	panel.BackgroundColor3 = Theme.Colors.Panel
	panel.BackgroundTransparency = 0.1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = panel
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(480, 600)
	limit.Parent = panel
	panel.Parent = gui

	local scroll = Instance.new("ScrollingFrame")
	scroll.Position = UDim2.fromOffset(14, 14)
	scroll.Size = UDim2.new(1, -28, 1, -84)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll
	scroll.Parent = panel

	local header = Theme.label(scroll, "", 28, Theme.Colors.Green, true)
	local reason = Theme.label(scroll, "", 16)
	local case = Theme.label(scroll, "", 15, Theme.Colors.Amber)
	local rewards = Theme.label(scroll, "", 18, Theme.Colors.Green, true)
	local breakdown = Theme.label(scroll, "", 14, Theme.Colors.Muted)
	local stats = Theme.label(scroll, "", 15)
	local team = Theme.label(scroll, "", 14, Theme.Colors.Muted)

	local row = Theme.row(panel, 48)
	row.AnchorPoint = Vector2.new(0, 1)
	row.Position = UDim2.new(0, 14, 1, -14)
	row.Size = UDim2.new(1, -28, 0, 48)
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
		if type(raw) ~= "table" or type(raw.Success) ~= "boolean" or type(raw.Credits) ~= "number" then
			return
		end
		local results = raw :: Types.Results
		header.Text = if results.Success then "SHIFT COMPLETE" else "SIGNAL LOST"
		header.TextColor3 = if results.Success then Theme.Colors.Green else Theme.Colors.Red
		reason.Text = REASON_TEXT[results.Reason] or results.Reason

		case.Text = table.concat({
			`The anomaly was {results.AnomalyName}.`,
			reportText(results),
			endingText(results),
		}, "\n")

		rewards.Text = `+{results.Credits} credits    +{results.XP} XP`
		local lines = {}
		for _, line in results.Breakdown do
			local sign = if line.Amount >= 0 then "+" else ""
			table.insert(lines, `{line.Label}: {sign}{line.Amount}`)
		end
		breakdown.Text = table.concat(lines, "\n")
		breakdown.Visible = #lines > 0

		local evidence = if #results.Evidence > 0 then table.concat(results.Evidence, ", ") else "none"
		stats.Text = table.concat({
			`Your status: {STATUS_TEXT[results.YourStatus] or results.YourStatus}`,
			`Objectives: {results.ObjectivesCompleted}/{results.ObjectivesTotal}`,
			`Evidence: {evidence}`,
			`Shift time: {State.formatTime(results.DurationSeconds)}`,
		}, "\n")

		local teamLines = { "TEAM" }
		for _, member in results.Team do
			table.insert(teamLines, `{member.Name} - {STATUS_TEXT[member.Status] or member.Status}`)
		end
		team.Text = table.concat(teamLines, "\n")
		scroll.CanvasPosition = Vector2.zero
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
