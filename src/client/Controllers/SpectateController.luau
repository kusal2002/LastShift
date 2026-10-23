--!strict
-- Lets eliminated players watch teammates who are still inside the station.
-- Camera only: nothing here affects gameplay.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RoundTransitions = require(ReplicatedStorage.Shared.Logic.RoundTransitions)
local Client = script.Parent.Parent
local State = require(Client.State)
local Theme = require(Client.UI.Theme)

local SpectateController = {}

local function humanoidOf(player: Player?): Humanoid?
	local character = player and player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

function SpectateController.start()
	local localPlayer = Players.LocalPlayer
	local gui = Theme.screenGui("Spectate", 6)
	local panel = Theme.panel(gui, "Panel", 320)
	panel.Size = UDim2.new(0.6, 0, 0, 0)
	panel.Position = UDim2.fromOffset(12, 12)

	Theme.label(panel, "SPECTATING", 13, Theme.Colors.Muted, true)
	local nameLabel = Theme.label(panel, "", 20, Theme.Colors.Amber, true)
	local row = Theme.row(panel, 44)
	local previous = Theme.rowButton(row, "<", 3)
	local nextButton = Theme.rowButton(row, ">", 3)
	local stop = Theme.rowButton(row, "STOP", 3, Theme.Colors.Muted)

	local index = 1
	local optedOut = false
	local watching: Player? = nil

	-- Teammates still inside the station.
	local function targets(): { Player }
		local snapshot = State.get()
		local list = {}
		if snapshot == nil then
			return list
		end
		for _, member in snapshot.Team do
			if member.Status == "Alive" and member.UserId ~= localPlayer.UserId then
				local player = Players:GetPlayerByUserId(member.UserId)
				if player then
					table.insert(list, player)
				end
			end
		end
		return list
	end

	local function restoreCamera()
		local own = humanoidOf(localPlayer)
		if own then
			Workspace.CurrentCamera.CameraSubject = own
		end
		watching = nil
	end

	local function render()
		local snapshot = State.get()
		local eligible = snapshot ~= nil
			and snapshot.Status == "Dead"
			and RoundTransitions.isActiveRound(snapshot.Phase)
		if not eligible then
			optedOut = false
		end
		local list = if eligible and not optedOut then targets() else {}
		if #list == 0 then
			gui.Enabled = false
			if watching then
				restoreCamera()
			end
			return
		end
		index = ((index - 1) % #list) + 1
		local target = list[index]
		local humanoid = humanoidOf(target)
		if humanoid and Workspace.CurrentCamera.CameraSubject ~= humanoid then
			Workspace.CurrentCamera.CameraSubject = humanoid
		end
		watching = target
		nameLabel.Text = target.DisplayName
		gui.Enabled = true
	end

	previous.Activated:Connect(function()
		index -= 1
		render()
	end)
	nextButton.Activated:Connect(function()
		index += 1
		render()
	end)
	stop.Activated:Connect(function()
		optedOut = true
		render()
	end)

	State.changed:Connect(render)
	State.clock:Connect(render)
end

return SpectateController
