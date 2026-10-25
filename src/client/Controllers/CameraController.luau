--!strict
-- Bodycam first-person camera. Client only: it changes what the local player sees and nothing
-- else (no remotes, no gameplay state).
--
-- During an active round, a living participant is locked in first person with the field of view
-- from their settings and a small walking sway. Lobby, briefing, results and spectating keep the
-- normal camera, so SpectateController still works unchanged.
--
-- Built on Roblox's own camera, so mouse, touch and gamepad look keep working. The sway is a
-- small offset added just after the camera updates and removed just before its next update, so
-- the default camera never sees it and can't drift.
--
-- The mouse is locked to the centre in first person. It is freed while a menu that needs it is
-- open (Config/Camera.CursorScreens), or while the player holds Left Alt for the corner buttons.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local CameraConfig = require(Shared.Config.Camera)
local CameraMotion = require(Shared.Logic.CameraMotion)
local RoundTransitions = require(Shared.Logic.RoundTransitions)
local Client = script.Parent.Parent
local Settings = require(Client.Settings)
local State = require(Client.State)
local Theme = require(Client.UI.Theme)

local UNDO_STEP = "LastShiftCameraUndo"
local APPLY_STEP = "LastShiftCameraApply"
local FREE_CURSOR_ACTION = "LastShiftFreeCursor"

local CameraController = {}

local localPlayer = Players.LocalPlayer

local active = false
local lastOffset: CFrame? = nil -- sway added after the last camera update
local motion = CameraMotion.new()
local fieldOfView = CameraConfig.DefaultFieldOfView
local defaultMinZoom = localPlayer.CameraMinZoomDistance

local humanoid: Humanoid? = nil
local root: BasePart? = nil
local characterConnections: { RBXScriptConnection } = {}

local flashlight: Attachment? = nil -- created by PlayerStateService on the server
local flashlightHome: CFrame? = nil -- its original offset, restored when leaving first person

local holdingFreeCursor = false
local cursorButton: TextButton? = nil -- a Modal button frees the mouse in first person
local cursorScreens: { GuiObject | ScreenGui } = {}

local function camera(): Camera
	return Workspace.CurrentCamera
end

-- Mouse cursor --------------------------------------------------------------------

local function cursorNeeded(): boolean
	if holdingFreeCursor then
		return true
	end
	for _, item in cursorScreens do
		if item.Parent ~= nil then
			if item:IsA("ScreenGui") and item.Enabled then
				return true
			elseif item:IsA("GuiObject") and item.Visible then
				local gui = item:FindFirstAncestorOfClass("ScreenGui")
				if gui and gui.Enabled then
					return true
				end
			end
		end
	end
	return false
end

local function refreshCursor()
	local button = cursorButton
	if button then
		button.Visible = active and cursorNeeded()
	end
end

local function watchScreen(gui: Instance)
	if not gui:IsA("ScreenGui") then
		return
	end
	if table.find(CameraConfig.CursorScreens, gui.Name) then
		table.insert(cursorScreens, gui)
		gui:GetPropertyChangedSignal("Enabled"):Connect(refreshCursor)
	end
	local panelName = (CameraConfig.CursorPanels :: { [string]: string })[gui.Name]
	if panelName then
		gui:GetPropertyChangedSignal("Enabled"):Connect(refreshCursor)
		local function watchPanel(panel: Instance)
			if panel.Name == panelName and panel:IsA("GuiObject") then
				table.insert(cursorScreens, panel)
				panel:GetPropertyChangedSignal("Visible"):Connect(refreshCursor)
				refreshCursor()
			end
		end
		gui.ChildAdded:Connect(watchPanel)
		for _, child in gui:GetChildren() do
			watchPanel(child)
		end
	end
	refreshCursor()
end

-- Flashlight ----------------------------------------------------------------------

local function findFlashlight(): Attachment?
	local current = flashlight
	if current and current.Parent ~= nil then
		return current
	end
	flashlight, flashlightHome = nil, nil
	local character = localPlayer.Character
	local head = character and character:FindFirstChild("Head")
	local found = head and head:FindFirstChild("FlashlightAttachment")
	if found and found:IsA("Attachment") then
		flashlight, flashlightHome = found, found.CFrame
		return found
	end
	return nil
end

-- Local only: the server never moves this attachment after creating it, and the Echo only checks
-- whether the light is on, not where it points. Teammates still see the head-mounted beam.
local function aimFlashlight(view: CFrame)
	if not CameraConfig.AimFlashlight then
		return
	end
	local attachment = findFlashlight()
	if attachment then
		attachment.WorldCFrame = CFrame.new(attachment.WorldPosition) * view.Rotation
	end
end

local function restoreFlashlight()
	local attachment, home = flashlight, flashlightHome
	if attachment and home and attachment.Parent ~= nil then
		attachment.CFrame = home
	end
end

-- Per-frame camera work (only bound while first person is active) -----------------

local function undoOffset()
	local offset = lastOffset
	if offset then
		lastOffset = nil
		local cam = camera()
		cam.CFrame = cam.CFrame * offset:Inverse()
	end
end

local function applyOffset(dt: number)
	local cam = camera()
	local speed, grounded = 0, true
	local currentRoot, currentHumanoid = root, humanoid
	if currentRoot then
		local velocity = currentRoot.AssemblyLinearVelocity
		speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	end
	if currentHumanoid then
		grounded = currentHumanoid.FloorMaterial ~= Enum.Material.Air
	end
	-- Set by the server (PlayerStateService); read here for presentation only.
	local input: CameraMotion.Input = {
		speed = speed,
		sprinting = localPlayer:GetAttribute("Sprinting") == true,
		downed = localPlayer:GetAttribute("Downed") == true,
		grounded = grounded,
	}
	local intensity = Settings.get("CameraMotion") :: number
	local offset
	motion, offset = CameraMotion.step(motion, dt, input, CameraConfig.Motion, intensity)

	local view = cam.CFrame
	aimFlashlight(view)

	local sway = CFrame.new(offset.x, offset.y, 0) * CFrame.Angles(offset.pitch, offset.yaw, offset.roll)
	cam.CFrame = view * sway
	lastOffset = sway

	local target = CameraMotion.targetFov(
		Settings.get("FieldOfView") :: number,
		motion.sprint,
		CameraConfig.Motion,
		intensity
	)
	fieldOfView = CameraMotion.approach(fieldOfView, target, math.min(dt, 0.1), CameraConfig.FovResponse)
	cam.FieldOfView = fieldOfView
end

-- First person on / off -----------------------------------------------------------

local function activate()
	if active then
		return
	end
	active = true
	motion = CameraMotion.new()
	fieldOfView = camera().FieldOfView
	localPlayer.CameraMinZoomDistance = defaultMinZoom
	localPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
	RunService:BindToRenderStep(UNDO_STEP, Enum.RenderPriority.Camera.Value - 1, undoOffset)
	RunService:BindToRenderStep(APPLY_STEP, Enum.RenderPriority.Camera.Value + 1, applyOffset)
	refreshCursor()
end

local function deactivate()
	if not active then
		return
	end
	active = false
	RunService:UnbindFromRenderStep(UNDO_STEP)
	RunService:UnbindFromRenderStep(APPLY_STEP)
	undoOffset()
	restoreFlashlight()
	camera().FieldOfView = CameraConfig.DefaultFieldOfView
	localPlayer.CameraMode = Enum.CameraMode.Classic
	-- Classic mode keeps the zoom at first-person distance; push it back out once.
	localPlayer.CameraMinZoomDistance = math.max(defaultMinZoom, CameraConfig.ExitZoomDistance)
	task.delay(0.25, function()
		if not active then
			localPlayer.CameraMinZoomDistance = defaultMinZoom
		end
	end)
	refreshCursor()
end

local function refresh()
	local snapshot = State.get()
	local currentHumanoid = humanoid
	local alive = currentHumanoid ~= nil and currentHumanoid.Parent ~= nil and currentHumanoid.Health > 0
	local wants = snapshot ~= nil
		and CameraMotion.wantsFirstPerson(
			RoundTransitions.isActiveRound(snapshot.Phase),
			snapshot.IsParticipant,
			snapshot.Status,
			alive
		)
	if wants then
		activate()
	else
		deactivate()
	end
end

-- Respawns: forget the old body, pick up the new one, and re-check the camera.
local function onCharacterAdded(character: Model)
	for _, connection in characterConnections do
		connection:Disconnect()
	end
	table.clear(characterConnections)
	humanoid, root = nil, nil
	flashlight, flashlightHome = nil, nil
	motion = CameraMotion.new()

	local foundHumanoid = character:WaitForChild("Humanoid", 10)
	if foundHumanoid == nil or not foundHumanoid:IsA("Humanoid") or character ~= localPlayer.Character then
		refresh()
		return
	end
	humanoid = foundHumanoid
	local foundRoot = character:WaitForChild("HumanoidRootPart", 10)
	root = if foundRoot and foundRoot:IsA("BasePart") then foundRoot else nil
	table.insert(characterConnections, foundHumanoid.Died:Connect(refresh))
	refresh()
end

local function applySensitivity()
	UserInputService.MouseDeltaSensitivity = Settings.get("MouseSensitivity") :: number
end

function CameraController.start()
	local gui = Theme.screenGui("CameraCursor", 30)
	gui.Enabled = true
	local button = Instance.new("TextButton")
	button.Name = "FreeCursor"
	button.BackgroundTransparency = 1
	button.Size = UDim2.fromOffset(1, 1)
	button.Text = ""
	button.AutoButtonColor = false
	button.Selectable = false
	button.Modal = true
	button.Visible = false
	button.Parent = gui
	cursorButton = button

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(watchScreen)
	for _, child in playerGui:GetChildren() do
		watchScreen(child)
	end

	ContextActionService:BindAction(
		FREE_CURSOR_ACTION,
		function(_name: string, state: Enum.UserInputState, _input: InputObject)
			if state == Enum.UserInputState.Begin then
				holdingFreeCursor = true
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				holdingFreeCursor = false
			end
			refreshCursor()
			return Enum.ContextActionResult.Pass
		end,
		false,
		Enum.KeyCode.LeftAlt
	)

	Settings.changed:Connect(function(key: string)
		if key == "MouseSensitivity" then
			applySensitivity()
		end
	end)
	applySensitivity()

	State.changed:Connect(refresh)
	localPlayer.CharacterAdded:Connect(onCharacterAdded)
	local character = localPlayer.Character
	if character then
		task.spawn(onCharacterAdded, character)
	end
	refresh()
end

return CameraController
