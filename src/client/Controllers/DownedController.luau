--!strict
-- Overlay shown while the local player is downed, with the bleed-out or recovery countdown.
-- Also hides the player's own revive prompt (only teammates can revive you).
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Client = script.Parent.Parent
local State = require(Client.State)
local Theme = require(Client.UI.Theme)

local DownedController = {}

local function hideOwnRevivePrompt(character: Model)
	local function check(instance: Instance)
		if instance:IsA("ProximityPrompt") and instance.Name == "RevivePrompt" then
			instance.Enabled = false -- local only; teammates still see it
		end
	end
	for _, descendant in character:GetDescendants() do
		check(descendant)
	end
	character.DescendantAdded:Connect(check)
end

function DownedController.start()
	local player = Players.LocalPlayer
	local gui = Theme.screenGui("Downed", 12)
	gui.ScreenInsets = Enum.ScreenInsets.None

	local tint = Instance.new("Frame")
	tint.Size = UDim2.fromScale(1, 1)
	tint.BackgroundColor3 = Color3.fromRGB(90, 0, 0)
	tint.BackgroundTransparency = 0.65
	tint.BorderSizePixel = 0
	tint.Parent = gui

	local panel = Theme.panel(tint, "Panel", 420)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.4)
	Theme.scaled(panel)
	local title = Theme.label(panel, "YOU ARE DOWN", 28, Theme.Colors.Red, true)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local detail = Theme.label(panel, "", 16)
	detail.TextXAlignment = Enum.TextXAlignment.Center

	local function render()
		local downed = player:GetAttribute("Downed") == true
		gui.Enabled = downed
		if not downed then
			return
		end
		local endsAt = tonumber(player:GetAttribute("DownedEndsAt")) or 0
		local left = math.max(0, math.ceil(endsAt - Workspace:GetServerTimeNow()))
		if player:GetAttribute("SoloDowned") == true then
			detail.Text = `Catching your breath... back on your feet in {left}s`
		else
			detail.Text = `A teammate can revive you. Bleeding out in {left}s`
		end
	end

	player:GetAttributeChangedSignal("Downed"):Connect(render)
	player:GetAttributeChangedSignal("DownedEndsAt"):Connect(render)
	State.clock:Connect(render)
	render()

	player.CharacterAdded:Connect(hideOwnRevivePrompt)
	if player.Character then
		hideOwnRevivePrompt(player.Character)
	end
end

return DownedController
