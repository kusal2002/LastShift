--!strict
-- Full-screen briefing shown to participants before they enter the station.
local Client = script.Parent.Parent
local State = require(Client.State)
local Theme = require(Client.UI.Theme)

local BriefingController = {}

function BriefingController.start()
	local gui = Theme.screenGui("Briefing", 8)
	gui.ScreenInsets = Enum.ScreenInsets.None -- the dim backdrop covers the whole screen

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.25
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	local panel = Theme.panel(backdrop, "Panel", 560)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	Theme.scaled(panel)

	Theme.label(panel, "INCOMING ASSIGNMENT // NIGHT SHIFT", 14, Theme.Colors.Muted, true)
	local location = Theme.label(panel, "", 22, Theme.Colors.Amber, true)
	local objective = Theme.label(panel, "", 17)
	local classified = Theme.label(panel, "", 15, Theme.Colors.Red)
	local equipment = Theme.label(panel, "", 14, Theme.Colors.Green)
	local controls = Theme.label(panel, "", 14, Theme.Colors.Muted)
	local countdown = Theme.label(panel, "", 18, Theme.Colors.Amber, true)

	local function render()
		local snapshot = State.get()
		local briefing = snapshot and snapshot.Briefing
		local visible = snapshot ~= nil
			and snapshot.Phase == "Briefing"
			and snapshot.IsParticipant
			and briefing ~= nil
		gui.Enabled = visible
		if not visible or briefing == nil then
			return
		end
		location.Text = briefing.Location
		objective.Text = briefing.Objective
		classified.Text = `CLASSIFIED: {briefing.Classified}`
		equipment.Text = briefing.Equipment
		controls.Text = briefing.Controls
		local left = State.secondsLeft()
		countdown.Text = if left then `ENTERING STATION IN {math.ceil(left)}` else ""
	end

	State.changed:Connect(render)
	State.clock:Connect(render)
	render()
end

return BriefingController
