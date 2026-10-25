--!strict
-- Settings and accessibility screen: volumes, subtitles, reduced flashes, text size, camera.
-- Changes apply immediately and are saved to the profile. Toggles show ON/OFF as text, not
-- just colour.
local Client = script.Parent.Parent
local Settings = require(Client.Settings)
local Theme = require(Client.UI.Theme)
local Overlay = require(Client.UI.Overlay)

type Key = Settings.Key

local VOLUME_STEP = 0.1
local TEXT_STEPS = { 0.85, 1, 1.15, 1.3 }

local SettingsController = {}

local overlay: Overlay.Overlay? = nil

local function rowFrame(parent: Instance, labelText: string): (Frame, TextLabel)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 44)
	row.LayoutOrder = #parent:GetChildren() + 1
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0.5, 0, 1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.TextSize = 15
	label.TextColor3 = Theme.Colors.Text
	label.FontFace = Theme.Regular
	label.Text = labelText
	label.Parent = row
	row.Parent = parent
	return row, label
end

local function smallButton(parent: Instance, text: string, x: UDim, width: UDim): TextButton
	local button = Instance.new("TextButton")
	button.Position = UDim2.new(x, UDim.new(0, 0))
	button.Size = UDim2.new(width, UDim.new(1, 0))
	button.BackgroundColor3 = Theme.Colors.Button
	button.Text = text
	button.TextSize = 16
	button.TextColor3 = Theme.Colors.Amber
	button.FontFace = Theme.Bold
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button
	button.Parent = parent
	return button
end

local function toggleRow(parent: Instance, labelText: string, key: Key)
	local row = rowFrame(parent, labelText)
	local on = Settings.get(key) == true
	local button = smallButton(row, if on then "ON" else "OFF", UDim.new(0.55, 0), UDim.new(0.45, 0))
	button.TextColor3 = if on then Theme.Colors.Green else Theme.Colors.Muted
	button.Activated:Connect(function()
		Settings.set(key, not (Settings.get(key) == true))
	end)
end

local function percent(value: number): string
	return `{math.round(value * 100)}%`
end

local function stepperRow(
	parent: Instance,
	labelText: string,
	key: Key,
	step: number,
	format: ((number) -> string)?
)
	local row = rowFrame(parent, labelText)
	local value = Settings.get(key) :: number
	local minus = smallButton(row, "-", UDim.new(0.55, 0), UDim.new(0.13, 0))
	local display = Instance.new("TextLabel")
	display.BackgroundTransparency = 1
	display.Position = UDim2.fromScale(0.68, 0)
	display.Size = UDim2.fromScale(0.19, 1)
	display.TextSize = 15
	display.TextColor3 = Theme.Colors.Text
	display.FontFace = Theme.Bold
	display.Text = (format or percent)(value)
	display.Parent = row
	local plus = smallButton(row, "+", UDim.new(0.87, 0), UDim.new(0.13, 0))
	minus.Activated:Connect(function()
		Settings.set(key, (Settings.get(key) :: number) - step)
	end)
	plus.Activated:Connect(function()
		Settings.set(key, (Settings.get(key) :: number) + step)
	end)
end

local function textSizeRow(parent: Instance)
	local row = rowFrame(parent, "Text size")
	local current = Settings.get("TextScale") :: number
	local index = 2
	for i, step in TEXT_STEPS do
		if math.abs(step - current) < 0.01 then
			index = i
		end
	end
	local minus = smallButton(row, "-", UDim.new(0.55, 0), UDim.new(0.13, 0))
	local display = Instance.new("TextLabel")
	display.BackgroundTransparency = 1
	display.Position = UDim2.fromScale(0.68, 0)
	display.Size = UDim2.fromScale(0.19, 1)
	display.TextSize = 15
	display.TextColor3 = Theme.Colors.Text
	display.FontFace = Theme.Bold
	display.Text = `{math.round(current * 100)}%`
	display.Parent = row
	local plus = smallButton(row, "+", UDim.new(0.87, 0), UDim.new(0.13, 0))
	minus.Activated:Connect(function()
		Settings.set("TextScale", TEXT_STEPS[math.max(1, index - 1)])
	end)
	plus.Activated:Connect(function()
		Settings.set("TextScale", TEXT_STEPS[math.min(#TEXT_STEPS, index + 1)])
	end)
end

local function render()
	local current = overlay
	if current == nil then
		return
	end
	current.clear()
	current.title.Text = "SETTINGS"
	local body = current.body

	Theme.label(body, "AUDIO", 15, Theme.Colors.Amber, true)
	stepperRow(body, "Master volume", "MasterVolume", VOLUME_STEP)
	stepperRow(body, "Effects (enemy, alarms, PA)", "EffectsVolume", VOLUME_STEP)
	stepperRow(body, "Ambient (footsteps, static)", "AmbientVolume", VOLUME_STEP)
	Theme.label(
		body,
		"Sound effects play once audio assets are added to the game. Subtitles always work.",
		13,
		Theme.Colors.Muted
	)

	Theme.label(body, "SUBTITLES", 15, Theme.Colors.Amber, true)
	toggleRow(body, "Important sounds", "Subtitles")
	toggleRow(body, "Background sounds", "AmbientSubtitles")

	Theme.label(body, "VISUALS", 15, Theme.Colors.Amber, true)
	toggleRow(body, "Reduced flashes (lights dim instead of flickering)", "ReducedFlashes")
	textSizeRow(body)

	Theme.label(body, "CAMERA", 15, Theme.Colors.Amber, true)
	stepperRow(body, "Mouse sensitivity", "MouseSensitivity", 0.1)
	stepperRow(body, "Field of view", "FieldOfView", 5, function(value: number): string
		return `{math.round(value)}°`
	end)
	stepperRow(body, "Camera motion (walking sway)", "CameraMotion", 0.25, function(value: number): string
		return if value <= 0 then "OFF" else percent(value)
	end)
	Theme.label(
		body,
		"In a shift, hold Left Alt to use the mouse on screen buttons. Gamepad and touch look speed are set in the Roblox menu.",
		13,
		Theme.Colors.Muted
	)

	Theme.label(body, "Settings are saved to your profile.", 13, Theme.Colors.Muted)
end

function SettingsController.start()
	overlay = Overlay.new("Settings", 16, Vector2.new(480, 620))
	Settings.changed:Connect(function()
		local current = overlay
		if current and current.gui.Enabled then
			render()
		end
	end)
	render()
end

function SettingsController.toggle()
	local current = overlay
	if current then
		render()
		current.toggle()
	end
end

function SettingsController.close()
	local current = overlay
	if current then
		current.close()
	end
end

return SettingsController
