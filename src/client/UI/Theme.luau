--!strict
-- Shared look and small builders for the UI: dark translucent panels, monospace text, amber and
-- green accents. Layouts use scale + max size so they fit phones, and every panel gets a UIScale
-- that shrinks it on small screens and follows the player's text-size setting.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Theme = {}

Theme.Colors = table.freeze({
	Panel = Color3.fromRGB(12, 14, 17),
	Button = Color3.fromRGB(30, 33, 37),
	Stroke = Color3.fromRGB(70, 74, 80),
	Text = Color3.fromRGB(226, 224, 214),
	Muted = Color3.fromRGB(140, 146, 150),
	Amber = Color3.fromRGB(255, 176, 59),
	Green = Color3.fromRGB(126, 205, 140),
	Red = Color3.fromRGB(222, 76, 64),
})

local family = Font.fromEnum(Enum.Font.RobotoMono).Family
Theme.Regular = Font.new(family, Enum.FontWeight.Regular)
Theme.Bold = Font.new(family, Enum.FontWeight.Bold)

-- Responsive scaling ---------------------------------------------------------------
local scales: { UIScale } = {}
local userScale = 1
local REFERENCE_SIZE = 640 -- screens whose short side is smaller than this get scaled down

local function effectiveScale(): number
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local factor = math.clamp(math.min(viewport.X, viewport.Y) / REFERENCE_SIZE, 0.6, 1)
	return factor * userScale
end

local function refreshScales()
	local value = effectiveScale()
	for index = #scales, 1, -1 do
		local scale = scales[index]
		if scale.Parent == nil then
			table.remove(scales, index)
		else
			scale.Scale = value
		end
	end
end

local cameraConnection: RBXScriptConnection? = nil
local function watchCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
	end
	local camera = Workspace.CurrentCamera
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScales)
	end
	refreshScales()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

-- Gives a top-level panel responsive scaling (scales around its AnchorPoint).
function Theme.scaled<T>(object: T): T
	local scale = Instance.new("UIScale")
	scale.Scale = effectiveScale()
	scale.Parent = object :: any
	table.insert(scales, scale)
	return object
end

-- The player's text-size setting (multiplies the screen-size factor).
function Theme.setUserScale(value: number)
	userScale = value
	refreshScales()
end

local layoutOrder = 0
local function nextOrder(): number
	layoutOrder += 1
	return layoutOrder
end

function Theme.screenGui(name: string, displayOrder: number): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function addStroke(parent: Instance, color: Color3)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
end

-- Vertical stack panel that grows to fit its content. maxWidth caps it on large screens.
function Theme.panel(parent: Instance, name: string, maxWidth: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = Theme.Colors.Panel
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Size = UDim2.new(0.92, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	addCorner(frame, 6)
	addStroke(frame, Theme.Colors.Stroke)

	local padding = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(padding :: any)[side] = UDim.new(0, 14)
	end
	padding.Parent = frame

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame

	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(maxWidth, math.huge)
	limit.Parent = frame

	frame.Parent = parent
	-- Nested panels (e.g. toasts inside a container) inherit their parent's scale.
	if parent:IsA("ScreenGui") then
		Theme.scaled(frame)
	end
	return frame
end

function Theme.label(
	parent: Instance,
	text: string,
	textSize: number,
	color: Color3?,
	bold: boolean?
): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.TextSize = textSize
	label.TextColor3 = color or Theme.Colors.Text
	label.FontFace = if bold then Theme.Bold else Theme.Regular
	label.LayoutOrder = nextOrder()
	label.Parent = parent
	return label
end

-- Touch-friendly button (48 px tall).
function Theme.button(parent: Instance, text: string, color: Color3?): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 48)
	button.BackgroundColor3 = Theme.Colors.Button
	button.AutoButtonColor = true
	button.Text = text
	button.TextSize = 18
	button.TextColor3 = color or Theme.Colors.Amber
	button.FontFace = Theme.Bold
	button.LayoutOrder = nextOrder()
	addCorner(button, 4)
	addStroke(button, color or Theme.Colors.Amber)
	button.Parent = parent
	return button
end

-- Horizontal row; children should use Theme.rowButton.
function Theme.row(parent: Instance, height: number): Frame
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, height)
	row.LayoutOrder = nextOrder()
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	row.Parent = parent
	return row
end

-- A button that takes an equal share of a row with `count` buttons.
function Theme.rowButton(row: Frame, text: string, count: number, color: Color3?): TextButton
	local button = Theme.button(row, text, color)
	local gap = 8 * (count - 1) / count
	button.Size = UDim2.new(1 / count, -gap, 1, 0)
	return button
end

return Theme
