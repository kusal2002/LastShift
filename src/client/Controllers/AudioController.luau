--!strict
-- Plays audio cues from the server and shows their subtitles.
-- A sound only plays if a verified asset id is set in Config/Assets (Sounds[AssetKey]);
-- until then subtitles carry every cue, which is also the accessibility fallback.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local AudioConfig = require(Shared.Config.Audio)
local Assets = require(Shared.Config.Assets)
local Remotes = require(Shared.Remotes)
local Client = script.Parent.Parent
local Settings = require(Client.Settings)
local Theme = require(Client.UI.Theme)

local MAX_LINES = 3
local LINE_SECONDS = 4.5

local AudioController = {}

local function playSound(assetKey: string, volume: number, position: Vector3?)
	local soundId = Assets.Sounds[assetKey]
	if soundId == nil then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	if position then
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = position
		attachment.Parent = Workspace.Terrain
		sound.Parent = attachment
		Debris:AddItem(attachment, 15)
	else
		sound.Parent = SoundService
		Debris:AddItem(sound, 15)
	end
	sound:Play()
end

-- Rough distance hint for spatial cues, so subtitles carry some of what stereo audio would.
local function distanceHint(position: Vector3?): string
	if position == nil then
		return ""
	end
	local distance = (Workspace.CurrentCamera.CFrame.Position - position).Magnitude
	if distance < 25 then
		return " (close)"
	elseif distance < 60 then
		return " (nearby)"
	end
	return ""
end

function AudioController.start()
	local gui = Theme.screenGui("Subtitles", 18)
	gui.Enabled = true
	local container = Instance.new("Frame")
	container.BackgroundTransparency = 1
	container.AnchorPoint = Vector2.new(0.5, 1)
	container.Position = UDim2.new(0.5, 0, 1, -150)
	container.Size = UDim2.new(0.9, 0, 0, 0)
	container.AutomaticSize = Enum.AutomaticSize.Y
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, math.huge)
	limit.Parent = container
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.Parent = container
	container.Parent = gui

	local order = 0
	local lines: { TextLabel } = {}

	local function showLine(text: string)
		order += 1
		local label = Instance.new("TextLabel")
		label.BackgroundColor3 = Color3.new(0, 0, 0)
		label.BackgroundTransparency = 0.45
		label.Size = UDim2.new(1, 0, 0, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.TextWrapped = true
		label.TextSize = 16
		label.TextColor3 = Theme.Colors.Text
		label.FontFace = Theme.Regular
		label.Text = text
		label.LayoutOrder = order
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 4)
		padding.PaddingBottom = UDim.new(0, 4)
		padding.PaddingLeft = UDim.new(0, 8)
		padding.PaddingRight = UDim.new(0, 8)
		padding.Parent = label
		label.Parent = container
		table.insert(lines, label)
		if #lines > MAX_LINES then
			local oldest = table.remove(lines, 1)
			if oldest then
				oldest:Destroy()
			end
		end
		task.delay(LINE_SECONDS, function()
			if label.Parent == nil then
				return
			end
			local fade = TweenInfo.new(0.5)
			TweenService:Create(label, fade, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			task.wait(0.5)
			local index = table.find(lines, label)
			if index then
				table.remove(lines, index)
			end
			label:Destroy()
		end)
	end

	Remotes.getClient(Remotes.Names.AudioCue).OnClientEvent:Connect(function(payload: any)
		if type(payload) ~= "table" or type(payload.Cue) ~= "string" then
			return
		end
		local cue = AudioConfig.Cues[payload.Cue]
		if cue == nil then
			return
		end
		local position: Vector3? = if typeof(payload.Position) == "Vector3" then payload.Position else nil
		playSound(cue.AssetKey, cue.Volume, position)

		if not Settings.Subtitles or (not cue.Important and not Settings.AmbientSubtitles) then
			return
		end
		local text = if type(payload.Text) == "string" then payload.Text else cue.Subtitle
		local label = cue.Label
		local prefix = if label then `[{label}] ` else ""
		showLine(prefix .. text .. distanceHint(position))
	end)
end

return AudioController
