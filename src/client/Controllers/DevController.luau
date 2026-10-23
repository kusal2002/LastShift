--!strict
-- Studio-only test keys: F6 take 40 damage, F7 skip the phase timer, F8 drain flashlight, F9 wake the Echo.
-- Does nothing in a live game; the server also refuses these outside Studio.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)

local KEYS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.F6] = "Damage",
	[Enum.KeyCode.F7] = "SkipTimer",
	[Enum.KeyCode.F8] = "DrainBattery",
	[Enum.KeyCode.F9] = "WakeEcho",
}

local DevController = {}

function DevController.start()
	if not RunService:IsStudio() then
		return
	end
	local remote = Remotes.getClient(Remotes.Names.DevCommand)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		local command = KEYS[input.KeyCode]
		if command and not processed then
			remote:FireServer(command)
		end
	end)
end

return DevController
