--!strict
-- The locker: cosmetic flashlight beams and badges. Equip what you own, see what unlocks at
-- which level, and buy credit items. The server validates every request.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Cosmetics = require(Shared.Config.Cosmetics)
local Remotes = require(Shared.Remotes)
local Client = script.Parent.Parent
local ProfileState = require(Client.ProfileState)
local Theme = require(Client.UI.Theme)
local Overlay = require(Client.UI.Overlay)

local SLOT_TITLES: { [string]: string } = {
	Flashlight = "FLASHLIGHT BEAM",
	Badge = "BADGE",
}

local LockerController = {}

local overlay: Overlay.Overlay? = nil
local equipRemote: RemoteEvent? = nil
local buyRemote: RemoteEvent? = nil

local function itemRow(parent: Instance, text: string, color: Color3?): (Frame, TextButton)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 44)
	row.LayoutOrder = #parent:GetChildren() + 1
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0.58, 0, 1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.TextSize = 15
	label.TextColor3 = color or Theme.Colors.Text
	label.FontFace = Theme.Bold
	label.Text = text
	label.Parent = row
	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.fromScale(1, 0)
	button.Size = UDim2.new(0.4, 0, 1, 0)
	button.BackgroundColor3 = Theme.Colors.Button
	button.TextSize = 15
	button.FontFace = Theme.Bold
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button
	button.Parent = row
	row.Parent = parent
	return row, button
end

local function render()
	local current = overlay
	local view = ProfileState.get()
	if current == nil then
		return
	end
	current.clear()
	if view == nil then
		current.title.Text = "LOCKER"
		Theme.label(current.body, "Loading your locker...", 15, Theme.Colors.Muted)
		return
	end
	current.title.Text = `LOCKER  {view.Credits} CR`
	Theme.label(
		current.body,
		"Cosmetic only: beams change colour, never range or brightness.",
		13,
		Theme.Colors.Muted
	)

	for _, slot in Cosmetics.Slots do
		Theme.label(current.body, SLOT_TITLES[slot] or slot, 15, Theme.Colors.Amber, true)
		for _, item in Cosmetics.Items do
			if item.Slot == slot then
				local rgb = item.Color
				local swatch = if rgb then Color3.fromRGB(rgb[1], rgb[2], rgb[3]) else nil
				local _, button = itemRow(current.body, item.DisplayName, swatch)
				local owned = ProfileState.owns(item.Id)
				local equipped = view.Equipped[slot] == item.Id
				local unlock = item.Unlock :: any
				if equipped then
					button.Text = "EQUIPPED"
					button.TextColor3 = Theme.Colors.Green
					button.AutoButtonColor = false
				elseif owned then
					button.Text = "EQUIP"
					button.TextColor3 = Theme.Colors.Amber
					button.Activated:Connect(function()
						local remote = equipRemote
						if remote then
							remote:FireServer(slot, item.Id)
						end
					end)
				elseif unlock.Kind == "Credits" then
					local affordable = view.Credits >= unlock.Price
					button.Text = `BUY {unlock.Price} CR`
					button.TextColor3 = if affordable then Theme.Colors.Amber else Theme.Colors.Muted
					button.Activated:Connect(function()
						local remote = buyRemote
						if remote then
							remote:FireServer(item.Id)
						end
					end)
				elseif unlock.Kind == "Level" then
					button.Text = `LEVEL {unlock.Level}`
					button.TextColor3 = Theme.Colors.Muted
					button.AutoButtonColor = false
				else
					button.Text = "LOCKED"
					button.TextColor3 = Theme.Colors.Muted
					button.AutoButtonColor = false
				end
			end
		end
	end
end

function LockerController.start()
	equipRemote = Remotes.getClient(Remotes.Names.EquipCosmetic)
	buyRemote = Remotes.getClient(Remotes.Names.BuyCosmetic)
	overlay = Overlay.new("Locker", 14, Vector2.new(480, 620))
	ProfileState.changed:Connect(render)
	render()
end

function LockerController.toggle()
	local current = overlay
	if current then
		render()
		current.toggle()
	end
end

function LockerController.close()
	local current = overlay
	if current then
		current.close()
	end
end

return LockerController
