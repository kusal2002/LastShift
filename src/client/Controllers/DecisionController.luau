--!strict
-- The transmitter screen: classify the anomaly (or say you're unsure), then Transmit or Abort.
-- The client only sends the choice; the server validates it and decides for the team.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Client = script.Parent.Parent
local State = require(Client.State)
local Theme = require(Client.UI.Theme)

local UNSURE = "Unsure"

local DecisionController = {}

local function parseOptions(raw: any): Types.DecisionOptions?
	if type(raw) ~= "table" or type(raw.Anomalies) ~= "table" or type(raw.TransmitSeconds) ~= "number" then
		return nil
	end
	for _, option in raw.Anomalies do
		if type(option) ~= "table" or type(option.Id) ~= "string" or type(option.DisplayName) ~= "string" then
			return nil
		end
	end
	return raw :: Types.DecisionOptions
end

function DecisionController.start()
	local submitRemote = Remotes.getClient(Remotes.Names.DecisionSubmit)
	local gui = Theme.screenGui("Decision", 11)
	local panel = Theme.panel(gui, "Panel", 460)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)

	Theme.label(panel, "RELAY TRANSMITTER", 20, Theme.Colors.Amber, true)
	Theme.label(
		panel,
		"1. What is in the station? Base it on your evidence (NOTES). A wrong report has consequences.",
		14
	)
	local choiceRows = Instance.new("Frame")
	choiceRows.BackgroundTransparency = 1
	choiceRows.Size = UDim2.new(1, 0, 0, 0)
	choiceRows.AutomaticSize = Enum.AutomaticSize.Y
	choiceRows.LayoutOrder = 3
	local rowsLayout = Instance.new("UIListLayout")
	rowsLayout.Padding = UDim.new(0, 8)
	rowsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowsLayout.Parent = choiceRows
	choiceRows.Parent = panel

	local stepTwo = Theme.label(panel, "", 14)
	stepTwo.LayoutOrder = 4
	local actionRow = Theme.row(panel, 48)
	actionRow.LayoutOrder = 5
	local transmitButton = Theme.rowButton(actionRow, "TRANSMIT", 2, Theme.Colors.Red)
	local abortButton = Theme.rowButton(actionRow, "ABORT", 2, Theme.Colors.Muted)
	local closeButton = Theme.button(panel, "CLOSE", Theme.Colors.Muted)
	closeButton.LayoutOrder = 6

	local selected: string? = nil
	local choiceButtons: { [string]: TextButton } = {}

	local function refresh()
		for id, button in choiceButtons do
			local isSelected = id == selected
			button.BackgroundColor3 = if isSelected then Theme.Colors.Amber else Theme.Colors.Button
			button.TextColor3 = if isSelected then Theme.Colors.Panel else Theme.Colors.Amber
		end
		local ready = selected ~= nil
		transmitButton.AutoButtonColor = ready
		abortButton.AutoButtonColor = ready
		transmitButton.TextTransparency = if ready then 0 else 0.6
		abortButton.TextTransparency = if ready then 0 else 0.6
	end

	local function build(options: Types.DecisionOptions)
		for _, child in choiceRows:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		table.clear(choiceButtons)
		local entries: { Types.AnomalyOption } = table.clone(options.Anomalies)
		table.insert(entries, { Id = UNSURE, DisplayName = "Unsure" })
		local row: Frame? = nil
		for index, option in entries do
			if (index - 1) % 2 == 0 then
				row = Theme.row(choiceRows, 44)
			end
			local currentRow = row :: Frame
			local button = Theme.rowButton(currentRow, option.DisplayName, 2)
			button.TextSize = 15
			choiceButtons[option.Id] = button
			button.Activated:Connect(function()
				selected = option.Id
				refresh()
			end)
		end
		stepTwo.Text =
			`2. TRANSMIT: survive {options.TransmitSeconds} seconds for a bigger reward. ABORT: the exit opens now.`
		selected = nil
		refresh()
	end

	local function submit(ending: string)
		local choice = selected
		if choice then
			submitRemote:FireServer(choice, ending)
		end
	end

	transmitButton.Activated:Connect(function()
		submit("Transmit")
	end)
	abortButton.Activated:Connect(function()
		submit("Abort")
	end)
	closeButton.Activated:Connect(function()
		gui.Enabled = false
	end)

	Remotes.getClient(Remotes.Names.DecisionOpen).OnClientEvent:Connect(function(raw: any)
		local options = parseOptions(raw)
		if options == nil then
			return
		end
		build(options)
		gui.Enabled = true
	end)
	Remotes.getClient(Remotes.Names.DecisionClose).OnClientEvent:Connect(function()
		gui.Enabled = false
	end)
	State.changed:Connect(function()
		local snapshot = State.get()
		if
			gui.Enabled and (snapshot == nil or snapshot.Phase ~= "Decision" or snapshot.Status ~= "Alive")
		then
			gui.Enabled = false
		end
	end)
end

return DecisionController
