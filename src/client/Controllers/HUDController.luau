--!strict
-- In-round HUD (phase, timer, objectives, team), survival meters, and toast notifications.
-- Status is always shown as text as well as colour, so meaning never depends on colour alone.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local PlayerConfig = require(Shared.Config.Player)
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

local TEAM_STATUS: { [string]: string } = {
	Alive = "OK",
	Escaped = "ESCAPED",
	Dead = "LOST",
	Lost = "LEFT BEHIND",
	Left = "DISCONNECTED",
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
		-- Only rebuild rows when objective or team text actually changed.
		local key = ""
		for _, objective in snapshot.Objectives do
			key ..= `{objective.Id}:{objective.Complete}:{objective.Detail};`
		end
		for _, member in snapshot.Team do
			key ..= `{member.UserId}:{member.Status}:{member.Downed}:{member.Location};`
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
		if #snapshot.Team > 1 then
			Theme.label(list, "TEAM", 13, Theme.Colors.Muted, true)
			for _, member in snapshot.Team do
				local text, color = TEAM_STATUS.Alive, Theme.Colors.Green
				if member.Status == "Alive" and member.Downed then
					text, color = "DOWN", Theme.Colors.Red
				elseif member.Status ~= "Alive" then
					text, color = TEAM_STATUS[member.Status] or member.Status, Theme.Colors.Muted
				end
				-- Where teammates really are: the check against fake radio calls.
				local where = if member.Status == "Alive" and member.Location ~= ""
					then ` ({member.Location})`
					else ""
				Theme.label(list, `{member.Name} - {text}{where}`, 13, color)
			end
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

type Meter = { row: Frame, fill: Frame, value: TextLabel }

local function makeMeter(parent: Instance, name: string, color: Color3): Meter
	local row = Instance.new("Frame")
	row.Name = name
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 18)
	row.LayoutOrder = #parent:GetChildren()
	row.Parent = parent

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0, 70, 1, 0)
	label.Text = name
	label.TextSize = 12
	label.TextColor3 = Theme.Colors.Muted
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.FontFace = Theme.Bold
	label.Parent = row

	local track = Instance.new("Frame")
	track.BackgroundColor3 = Theme.Colors.Button
	track.BorderSizePixel = 0
	track.Position = UDim2.new(0, 72, 0.5, -4)
	track.Size = UDim2.new(1, -122, 0, 8)
	track.Parent = row

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = track

	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position = UDim2.fromScale(1, 0)
	value.Size = UDim2.new(0, 46, 1, 0)
	value.TextSize = 12
	value.TextColor3 = Theme.Colors.Text
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.FontFace = Theme.Regular
	value.Parent = row

	return { row = row, fill = fill, value = value }
end

local function setMeter(meter: Meter, fraction: number, text: string)
	meter.fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	meter.value.Text = text
end

-- Health, stamina and flashlight battery, bottom centre. Values come from server-set attributes.
local function buildMeters()
	local player = Players.LocalPlayer
	local gui = Theme.screenGui("Meters", 3)
	local panel = Theme.panel(gui, "Meters", 300)
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -16)
	panel.Size = UDim2.new(0.6, 0, 0, 0)

	local health = makeMeter(panel, "HEALTH", Theme.Colors.Red)
	local stamina = makeMeter(panel, "STAMINA", Theme.Colors.Green)
	local battery = makeMeter(panel, "LIGHT", Theme.Colors.Amber)
	local hints = Theme.label(panel, "[Shift] sprint   [F] flashlight", 12, Theme.Colors.Muted)
	hints.LayoutOrder = 100
	hints.Visible = UserInputService.KeyboardEnabled

	local function render()
		local snapshot = State.get()
		local visible = snapshot ~= nil
			and snapshot.IsParticipant
			and snapshot.Status == "Alive"
			and (snapshot.Phase == "Investigation" or snapshot.Phase == "Extraction")
		gui.Enabled = visible
		if not visible then
			return
		end

		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if player:GetAttribute("Downed") == true then
			setMeter(health, 0, "DOWN")
		elseif humanoid then
			setMeter(health, humanoid.Health / humanoid.MaxHealth, `{math.ceil(humanoid.Health)}`)
		end

		local staminaValue = tonumber(player:GetAttribute("Stamina")) or 100
		setMeter(stamina, staminaValue / PlayerConfig.Stamina.Max, `{staminaValue}%`)

		local batteryValue = tonumber(player:GetAttribute("Battery")) or 100
		local on = player:GetAttribute("FlashlightOn") == true
		setMeter(
			battery,
			batteryValue / PlayerConfig.Flashlight.MaxBattery,
			`{if on then "ON" else "OFF"} {batteryValue}%`
		)

		local hasDecoy = player:GetAttribute("HasDecoy") == true
		hints.Text = "[Shift] sprint   [F] flashlight" .. (if hasDecoy then "   [G] noise maker" else "")
		hints.Visible = UserInputService.KeyboardEnabled or hasDecoy
	end

	for _, attribute in { "Stamina", "Battery", "FlashlightOn", "Downed", "HasDecoy" } do
		player:GetAttributeChangedSignal(attribute):Connect(render)
	end
	State.changed:Connect(render)
	State.clock:Connect(render)
	render()
end

function HUDController.start()
	buildToasts()
	buildHud()
	buildMeters()
end

return HUDController
