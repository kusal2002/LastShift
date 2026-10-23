--!strict
-- Sprint and flashlight input. Sends intents only; the server decides what actually happens.
-- Keyboard: hold Shift to sprint, F for flashlight. Gamepad: L3 sprint, Y flashlight.
-- Touch: on-screen RUN (tap to toggle) and LIGHT buttons above the jump button.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Client = script.Parent.Parent
local Theme = require(Client.UI.Theme)

local InputController = {}

local function makeTouchButton(parent: Instance, text: string, xOffset: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = text
	button.AnchorPoint = Vector2.new(1, 1)
	button.Size = UDim2.fromOffset(72, 72)
	button.Position = UDim2.new(1, xOffset, 1, -190)
	button.BackgroundColor3 = Theme.Colors.Panel
	button.BackgroundTransparency = 0.25
	button.Text = text
	button.TextSize = 16
	button.TextColor3 = Theme.Colors.Amber
	button.FontFace = Theme.Bold
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Amber
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	button.Parent = parent
	return button
end

function InputController.start()
	local sprintRemote = Remotes.getClient(Remotes.Names.SprintRequest)
	local flashlightRemote = Remotes.getClient(Remotes.Names.FlashlightToggle)

	local wantsSprint = false
	local runButton: TextButton? = nil

	local function setSprint(on: boolean)
		if on == wantsSprint then
			return
		end
		wantsSprint = on
		sprintRemote:FireServer(on)
		if runButton then
			runButton.BackgroundColor3 = if on then Theme.Colors.Amber else Theme.Colors.Panel
			runButton.TextColor3 = if on then Theme.Colors.Panel else Theme.Colors.Amber
		end
	end

	ContextActionService:BindAction(
		"LastShiftSprint",
		function(_name: string, state: Enum.UserInputState, _input: InputObject)
			if state == Enum.UserInputState.Begin then
				setSprint(true)
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				setSprint(false)
			end
			return Enum.ContextActionResult.Pass
		end,
		false,
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.ButtonL3
	)

	ContextActionService:BindAction(
		"LastShiftFlashlight",
		function(_name: string, state: Enum.UserInputState, _input: InputObject)
			if state == Enum.UserInputState.Begin then
				flashlightRemote:FireServer()
			end
			return Enum.ContextActionResult.Pass
		end,
		false,
		Enum.KeyCode.F,
		Enum.KeyCode.ButtonY
	)

	local decoyRemote = Remotes.getClient(Remotes.Names.DecoyUse)
	ContextActionService:BindAction(
		"LastShiftDecoy",
		function(_name: string, state: Enum.UserInputState, _input: InputObject)
			if
				state == Enum.UserInputState.Begin
				and Players.LocalPlayer:GetAttribute("HasDecoy") == true
			then
				decoyRemote:FireServer()
			end
			return Enum.ContextActionResult.Pass
		end,
		false,
		Enum.KeyCode.G,
		Enum.KeyCode.ButtonX
	)

	if UserInputService.TouchEnabled then
		local gui = Theme.screenGui("TouchControls", 4)
		gui.Enabled = true
		local run = makeTouchButton(gui, "RUN", -20)
		local light = makeTouchButton(gui, "LIGHT", -104)
		local decoy = makeTouchButton(gui, "DECOY", -188)
		runButton = run
		run.Activated:Connect(function()
			setSprint(not wantsSprint)
		end)
		light.Activated:Connect(function()
			flashlightRemote:FireServer()
		end)
		decoy.Activated:Connect(function()
			decoyRemote:FireServer()
		end)
		-- Only shown while carrying a noise maker.
		local function refreshDecoy()
			decoy.Visible = Players.LocalPlayer:GetAttribute("HasDecoy") == true
		end
		Players.LocalPlayer:GetAttributeChangedSignal("HasDecoy"):Connect(refreshDecoy)
		refreshDecoy()
	end

	-- A new character starts walking; clear any held sprint.
	Players.LocalPlayer.CharacterAdded:Connect(function()
		setSprint(false)
	end)
end

return InputController
