--!strict
-- Server-validated ProximityPrompt interactions.
-- Every trigger is checked for: rate limit, round gate (phase + player state), alive, distance.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ObjectivesConfig = require(Shared.Config.Objectives)
local RateLimiter = require(Shared.Util.RateLimiter)
local Log = require(Shared.Util.Log)
local RemoteService = require(script.Parent.RemoteService)

export type PromptOptions = {
	ActionText: string,
	ObjectText: string?,
	HoldDuration: number?,
	MaxDistance: number,
}
-- Returns whether the player may interact right now, plus an optional message to show them.
export type Gate = (player: Player) -> (boolean, string?)

local InteractionService = {}

local config = ObjectivesConfig.Interaction
local limiter = RateLimiter.new(config.RateCapacity, config.RatePerSecond)
local gate: Gate = function(_player: Player)
	return true, nil
end

function InteractionService.Init()
	Players.PlayerRemoving:Connect(function(player: Player)
		limiter:remove(player)
	end)
end

function InteractionService.setGate(newGate: Gate)
	gate = newGate
end

function InteractionService.checkGate(player: Player): (boolean, string?)
	return gate(player)
end

-- The player's root part if they have a living character.
function InteractionService.getRoot(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function InteractionService.isWithinReach(player: Player, target: BasePart, maxDistance: number): boolean
	local root = InteractionService.getRoot(player)
	if root == nil then
		return false
	end
	return (root.Position - target.Position).Magnitude <= maxDistance + config.DistanceTolerance
end

-- Creates a prompt on `part`. The handler only runs after every server check passes.
-- The caller owns the returned prompt and must destroy it (usually via a Maid).
function InteractionService.createPrompt(
	part: BasePart,
	options: PromptOptions,
	handler: (Player) -> ()
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = options.ActionText
	prompt.ObjectText = options.ObjectText or ""
	prompt.HoldDuration = options.HoldDuration or 0
	prompt.MaxActivationDistance = options.MaxDistance
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player: Player)
		if not limiter:check(player) then
			return
		end
		local allowed, reason = gate(player)
		if not allowed then
			if reason then
				RemoteService.notify(player, reason, "warn")
			end
			return
		end
		if not InteractionService.isWithinReach(player, part, options.MaxDistance) then
			Log.debug("Interaction", "Rejected %s on %s: out of reach", player.Name, part.Name)
			return
		end
		handler(player)
	end)
	prompt.Parent = part
	return prompt
end

return InteractionService
