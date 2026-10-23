--!strict
-- Evidence notebook: everything the team has recovered this round, for working out which
-- anomaly is in the station. Opened with the NOTES button (any device) or J / gamepad DPadLeft.
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local RoundTransitions = require(Shared.Logic.RoundTransitions)
local Types = require(Shared.Types)
local Client = script.Parent.Parent
local State = require(Client.State)
local Theme = require(Client.UI.Theme)

local NotebookController = {}

function NotebookController.start()
	local gui = Theme.screenGui("Notebook", 9)

	local toggle = Instance.new("TextButton")
	toggle.AnchorPoint = Vector2.new(1, 0)
	toggle.Position = UDim2.new(1, -12, 0, 12)
	toggle.Size = UDim2.fromOffset(110, 44)
	toggle.BackgroundColor3 = Theme.Colors.Panel
	toggle.BackgroundTransparency = 0.15
	toggle.TextColor3 = Theme.Colors.Amber
	toggle.FontFace = Theme.Bold
	toggle.TextSize = 16
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = toggle
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Amber
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = toggle
	toggle.Parent = gui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -12, 0, 64)
	panel.Size = UDim2.new(0.9, 0, 0.6, 0)
	panel.BackgroundColor3 = Theme.Colors.Panel
	panel.BackgroundTransparency = 0.1
	panel.Visible = false
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 6)
	panelCorner.Parent = panel
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(380, 520)
	limit.Parent = panel
	panel.Parent = gui

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -16, 1, -16)
	scroll.Position = UDim2.fromOffset(8, 8)
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

	local lastKey = ""

	local function rebuild()
		local snapshot = State.get()
		local evidence: { Types.EvidenceView } = if snapshot then snapshot.Evidence else {}
		local key = ""
		for _, item in evidence do
			key ..= item.Id .. ";"
		end
		if key == lastKey then
			return
		end
		lastKey = key
		for _, child in scroll:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		Theme.label(scroll, "CASE NOTES", 16, Theme.Colors.Amber, true)
		if #evidence == 0 then
			Theme.label(
				scroll,
				"Nothing recovered yet. Search the station for recordings, logs and readings.",
				14,
				Theme.Colors.Muted
			)
			return
		end
		Theme.label(scroll, "Compare these with what you've seen and heard.", 13, Theme.Colors.Muted)
		for _, item in evidence do
			local title = `{item.DisplayName}  [{item.Category}]` .. (if item.Risky then "  (rare)" else "")
			Theme.label(scroll, title, 15, Theme.Colors.Text, true)
			Theme.label(scroll, item.Description, 14, Theme.Colors.Muted)
		end
	end

	local function render()
		local snapshot = State.get()
		local visible = snapshot ~= nil
			and snapshot.IsParticipant
			and snapshot.Status == "Alive"
			and RoundTransitions.isActiveRound(snapshot.Phase)
		gui.Enabled = visible
		if not visible then
			panel.Visible = false
			return
		end
		local count = if snapshot then #snapshot.Evidence else 0
		toggle.Text = `NOTES ({count})`
		rebuild()
	end

	local function flip()
		if gui.Enabled then
			panel.Visible = not panel.Visible
		end
	end

	toggle.Activated:Connect(flip)
	ContextActionService:BindAction(
		"LastShiftNotebook",
		function(_name: string, state: Enum.UserInputState, _input: InputObject)
			if state == Enum.UserInputState.Begin then
				flip()
			end
			return Enum.ContextActionResult.Pass
		end,
		false,
		Enum.KeyCode.J,
		Enum.KeyCode.DPadLeft
	)

	State.changed:Connect(render)
	render()
end

return NotebookController
