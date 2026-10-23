--!strict
-- In-round HUD (phase, timer, objectives) and toast notifications from the server.
-- Toasts carry a text tag as well as a colour, so meaning never depends on colour alone.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Client = script.Parent.Parent
local State = require(Client.State)
local Theme = require(Client.UI.Theme)

local MAX_TOASTS = 4
local TOAST_SECONDS = 4

local KIND_STYLE: { [string]: { color: Color3, tag: string } } = {
	info = { color = Theme.Colors.Text, tag = "" },
	success = { color = Theme.Colors.Green, tag = "[OK] " },
	warn = { color = Theme.Colors.Amber, tag = "[!] " },
	danger = { color = Theme.Colors.Red, tag = "[!!] " },
}

local HUDController = {}

local function buildToasts()
	local gui = Theme.screenGui("Toasts", 20)
	gui.Enabled = true
	local container = Instance.new("Frame")
	container.BackgroundTransparency = 1
	container.AnchorPoint = Vector2.new(0.5, 0)
	container.Position = UDim2.new(0.5, 0, 0, 12)
	container.Size = UDim2.new(0.9, 0, 0, 0)
	container.AutomaticSize = Enum.AutomaticSize.Y
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(460, math.huge)
	limit.Parent = container
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = container
	container.Parent = gui

	local count = 0
	local live: { Frame } = {}

	Remotes.getClient(Remotes.Names.Notify).OnClientEvent:Connect(function(text: any, kind: any)
		if type(text) ~= "string" then
			return
		end
		local style = KIND_STYLE[if type(kind) == "string" then kind else "info"] or KIND_STYLE.info
		count += 1

		local toast = Theme.panel(container, "Toast", 460)
		toast.Size = UDim2.new(1, 0, 0, 0)
		toast.LayoutOrder = count
		local label = Theme.label(toast, style.tag .. text, 16, style.color, kind ~= "info")
		label.TextXAlignment = Enum.TextXAlignment.Center
		table.insert(live, toast)
		if #live > MAX_TOASTS then
			local oldest = table.remove(live, 1)
			if oldest then
				oldest:Destroy()
			end
		end

		task.delay(TOAST_SECONDS, function()
			if toast.Parent == nil then
				return
			end
			local fade = TweenInfo.new(0.4)
			TweenService:Create(toast, fade, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
			task.wait(0.4)
			local index = table.find(live, toast)
			if index then
				table.remove(live, index)
			end
			toast:Destroy()
		end)
	end)
end

local function buildHud()
	local gui = Theme.screenGui("HUD", 3)
	local panel = Theme.panel(gui, "Objectives", 330)
	panel.Size = UDim2.new(0.6, 0, 0, 0)
	panel.Position = UDim2.new(0, 12, 0, 12)

	local phaseLabel = Theme.label(panel, "", 16, Theme.Colors.Amber, true)
	local hint = Theme.label(panel, "", 14, Theme.Colors.Green, true)
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(1, 0, 0, 0)
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.LayoutOrder = 1e6 -- always below the phase and hint labels
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	list.Parent = panel

	local lastObjectives = ""

	local function renderObjectives()
		local snapshot = State.get()
		if snapshot == nil then
			return
		end
		-- Only rebuild rows when objective text actually changed.
		local key = ""
		for _, objective in snapshot.Objectives do
			key ..= `{objective.Id}:{objective.Complete}:{objective.Detail};`
		end
		if key == lastObjectives then
			return
		end
		lastObjectives = key
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for _, objective in snapshot.Objectives do
			local mark = if objective.Complete then "[x] " else "[ ] "
			local color = if objective.Complete then Theme.Colors.Muted else Theme.Colors.Text
			Theme.label(list, mark .. objective.Label, 15, color, not objective.Complete)
			Theme.label(list, "    " .. objective.Detail, 13, Theme.Colors.Muted)
		end
	end

	local function render()
		local snapshot = State.get()
		local visible = snapshot ~= nil
			and snapshot.IsParticipant
			and snapshot.Status == "Alive"
			and (snapshot.Phase == "Investigation" or snapshot.Phase == "Extraction")
		gui.Enabled = visible
		if not visible or snapshot == nil then
			return
		end
		local left = State.secondsLeft()
		local timer = if left then State.formatTime(left) else "--:--"
		if snapshot.Phase == "Extraction" then
			phaseLabel.Text = `EXTRACTION  {timer}`
			phaseLabel.TextColor3 = Theme.Colors.Red
			hint.Text = "Exit open: reach the loading bay"
			hint.Visible = true
		else
			phaseLabel.Text = `INVESTIGATION  {timer}`
			phaseLabel.TextColor3 = Theme.Colors.Amber
			hint.Visible = false
		end
		renderObjectives()
	end

	State.changed:Connect(render)
	State.clock:Connect(render)
	render()
end

function HUDController.start()
	buildToasts()
	buildHud()
end

return HUDController
