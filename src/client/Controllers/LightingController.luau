--!strict
-- Cosmetic light flicker, run locally. Only touches Brightness and lamp Transparency, which the
-- server never changes, so it can't fight a real blackout. With Reduced Flashes on, lights dim
-- smoothly instead of flickering.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local Tags = require(Shared.Config.Tags)
local Client = script.Parent.Parent
local Settings = require(Client.Settings)

local LightingController = {}

local busy: { [BasePart]: boolean } = {}

local function flickerLamp(lamp: BasePart, seconds: number)
	if busy[lamp] then
		return
	end
	local light = lamp:FindFirstChildOfClass("PointLight")
	if light == nil then
		return
	end
	busy[lamp] = true
	local brightness = light.Brightness
	local transparency = lamp.Transparency

	if Settings.ReducedFlashes then
		local half = TweenInfo.new(seconds / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, true)
		TweenService:Create(light, half, { Brightness = brightness * 0.3 }):Play()
		task.wait(seconds)
	else
		local stopAt = os.clock() + seconds
		while os.clock() < stopAt and lamp.Parent ~= nil do
			local off = math.random() < 0.5
			light.Brightness = if off then brightness * 0.05 else brightness
			lamp.Transparency = if off then 0.6 else transparency
			task.wait(0.05 + math.random() * 0.12)
		end
	end
	light.Brightness = brightness
	lamp.Transparency = transparency
	busy[lamp] = nil
end

function LightingController.start()
	Remotes.getClient(Remotes.Names.LightFlicker).OnClientEvent:Connect(function(room: any, seconds: any)
		if type(room) ~= "string" or type(seconds) ~= "number" then
			return
		end
		local duration = math.clamp(seconds, 0.2, 5)
		for _, instance in CollectionService:GetTagged(Tags.StationLight) do
			if instance:IsA("BasePart") and instance:GetAttribute("Room") == room then
				task.spawn(flickerLamp, instance, duration)
			end
		end
	end)
end

return LightingController
