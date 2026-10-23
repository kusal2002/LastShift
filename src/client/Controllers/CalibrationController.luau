--!strict
-- Tuning dial for the signal calibration objective. The client only picks a number;
-- the server decides whether it is right.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Calibration = require(Shared.Logic.Calibration)
local Client = script.Parent.Parent
local State = require(Client.State)
local Theme = require(Client.UI.Theme)

local CalibrationController = {}

local function parseParams(raw: any): Types.CalibrationParams?
	if type(raw) ~= "table" then
		return nil
	end
	if type(raw.Min) ~= "number" or type(raw.Max) ~= "number" or type(raw.Step) ~= "number" then
		return nil
	end
	if type(raw.AttemptsLeft) ~= "number" or raw.Step <= 0 then
		return nil
	end
	return raw :: Types.CalibrationParams
end

function CalibrationController.start()
	local submitRemote = Remotes.getClient(Remotes.Names.CalibrationSubmit)
	local cancelRemote = Remotes.getClient(Remotes.Names.CalibrationCancel)

	local gui = Theme.screenGui("Calibration", 10)
	local panel = Theme.panel(gui, "Panel", 400)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)

	Theme.label(panel, "RADIO CALIBRATION", 18, Theme.Colors.Amber, true)
	Theme.label(panel, "Match the target frequency posted somewhere in the station.", 14, Theme.Colors.Muted)
	local valueLabel = Theme.label(panel, "", 40, Theme.Colors.Green, true)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Center

	local tuneRow = Theme.row(panel, 48)
	local downBig = Theme.rowButton(tuneRow, "-1.0", 4)
	local downSmall = Theme.rowButton(tuneRow, "-0.1", 4)
	local upSmall = Theme.rowButton(tuneRow, "+0.1", 4)
	local upBig = Theme.rowButton(tuneRow, "+1.0", 4)

	local attemptsLabel = Theme.label(panel, "", 14, Theme.Colors.Muted)
	local actionRow = Theme.row(panel, 48)
	local lockButton = Theme.rowButton(actionRow, "LOCK SIGNAL", 2, Theme.Colors.Green)
	local closeButton = Theme.rowButton(actionRow, "CLOSE", 2, Theme.Colors.Muted)

	local params: Types.CalibrationParams? = nil
	local steps = 0 -- dial position in whole steps, avoids floating-point drift

	local function render()
		local current = params
		if current == nil then
			return
		end
		valueLabel.Text = Calibration.format(steps * current.Step)
		attemptsLabel.Text = `Attempts before overload: {current.AttemptsLeft}`
	end

	local function nudge(delta: number)
		local current = params
		if current == nil then
			return
		end
		local low = Calibration.toSteps(current.Min, current.Step)
		local high = Calibration.toSteps(current.Max, current.Step)
		steps = math.clamp(steps + Calibration.toSteps(delta, current.Step), low, high)
		render()
	end

	local function hide()
		gui.Enabled = false
		params = nil
	end

	downBig.Activated:Connect(function()
		nudge(-1)
	end)
	downSmall.Activated:Connect(function()
		nudge(-0.1)
	end)
	upSmall.Activated:Connect(function()
		nudge(0.1)
	end)
	upBig.Activated:Connect(function()
		nudge(1)
	end)
	lockButton.Activated:Connect(function()
		local current = params
		if current then
			submitRemote:FireServer(steps * current.Step)
		end
	end)
	closeButton.Activated:Connect(function()
		hide()
		cancelRemote:FireServer()
	end)

	Remotes.getClient(Remotes.Names.CalibrationOpen).OnClientEvent:Connect(function(raw: any)
		local parsed = parseParams(raw)
		if parsed == nil then
			return
		end
		-- Re-opening (after a wrong guess) keeps the dial where the player left it.
		if not gui.Enabled then
			steps = Calibration.toSteps(parsed.Min, parsed.Step)
		end
		params = parsed
		gui.Enabled = true
		render()
	end)
	Remotes.getClient(Remotes.Names.CalibrationClose).OnClientEvent:Connect(hide)

	-- Close if the player is no longer active in a round (died, escaped, round ended).
	State.changed:Connect(function()
		local snapshot = State.get()
		if
			gui.Enabled
			and (snapshot == nil or snapshot.Status ~= "Alive" or snapshot.Phase ~= "Investigation")
		then
			hide()
		end
	end)
end

return CalibrationController
