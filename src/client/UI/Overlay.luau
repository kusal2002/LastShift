--!strict
-- A centred, scrolling panel with a title and a close button, used by lobby screens such as the
-- casebook and locker. Content goes into `body`.
local Theme = require(script.Parent.Theme)

export type Overlay = {
	gui: ScreenGui,
	body: ScrollingFrame,
	title: TextLabel,
	open: () -> (),
	close: () -> (),
	toggle: () -> (),
	clear: () -> (),
}

local Overlay = {}

function Overlay.new(name: string, displayOrder: number, maxSize: Vector2): Overlay
	local gui = Theme.screenGui(name, displayOrder)

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.92, 0.85)
	panel.BackgroundColor3 = Theme.Colors.Panel
	panel.BackgroundTransparency = 0.08
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = panel
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = maxSize
	limit.Parent = panel
	panel.Parent = gui
	Theme.scaled(panel)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(14, 10)
	title.Size = UDim2.new(1, -120, 0, 32)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextSize = 22
	title.TextColor3 = Theme.Colors.Amber
	title.FontFace = Theme.Bold
	title.Parent = panel

	local closeButton = Instance.new("TextButton")
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -10, 0, 8)
	closeButton.Size = UDim2.fromOffset(96, 40)
	closeButton.BackgroundColor3 = Theme.Colors.Button
	closeButton.Text = "CLOSE"
	closeButton.TextSize = 16
	closeButton.TextColor3 = Theme.Colors.Muted
	closeButton.FontFace = Theme.Bold
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 4)
	closeCorner.Parent = closeButton
	closeButton.Parent = panel

	local body = Instance.new("ScrollingFrame")
	body.Position = UDim2.fromOffset(14, 58)
	body.Size = UDim2.new(1, -28, 1, -72)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 6
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body
	body.Parent = panel

	local overlay = {} :: Overlay
	overlay.gui = gui
	overlay.body = body
	overlay.title = title

	function overlay.open()
		gui.Enabled = true
	end
	function overlay.close()
		gui.Enabled = false
	end
	function overlay.toggle()
		gui.Enabled = not gui.Enabled
	end
	function overlay.clear()
		for _, child in body:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	closeButton.Activated:Connect(overlay.close)
	return overlay
end

return Overlay
