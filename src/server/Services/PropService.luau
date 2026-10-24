--!strict
-- Puts imported 3D models on gameplay objects.
-- The gameplay object (the "hook" part) keeps its tag, prompt and collision; PropService clones
-- the matching model from ServerStorage.Props, places it on the hook, and hides the hook.
-- If the model isn't imported yet, nothing changes: the placeholder stays visible.
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

export type DressOptions = {
	attach: boolean?, -- weld to an unanchored hook (e.g. a fuse carried by a player)
}

local PropService = {}

local missingLogged: { [string]: boolean } = {}

local function propsFolder(): Instance?
	return ServerStorage:FindFirstChild("Props")
end

-- Finds a model by "Kit/Name". Returns nil if it hasn't been imported.
function PropService.find(path: string): Instance?
	local node = propsFolder()
	for _, segment in string.split(path, "/") do
		if node == nil then
			return nil
		end
		node = node:FindFirstChild(segment)
	end
	if node and (node:IsA("Model") or node:IsA("BasePart")) then
		return node
	end
	return nil
end

function PropService.has(path: string): boolean
	return PropService.find(path) ~= nil
end

local function partsOf(instance: Instance): { BasePart }
	local parts: { BasePart } = {}
	if instance:IsA("BasePart") then
		table.insert(parts, instance)
	end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

-- Dresses `hook` with the model at `path`. Returns the clone, or nil if the model is missing
-- (the hook then stays visible as the placeholder).
function PropService.dress(hook: BasePart, path: string?, options: DressOptions?): Instance?
	if path == nil then
		return nil
	end
	local source = PropService.find(path)
	if source == nil then
		if not missingLogged[path] then
			missingLogged[path] = true
			Log.debug("Props", "No model for %s yet; using placeholder", path)
		end
		return nil
	end
	local attach = options ~= nil and options.attach == true
	local clone = source:Clone()
	-- Visual only: the hook handles collision, prompts and queries.
	for _, part in partsOf(clone) do
		part.Anchored = not attach
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		if attach then
			part.Massless = true
		end
	end
	if clone:IsA("Model") then
		clone:PivotTo(hook.CFrame)
	elseif clone:IsA("BasePart") then
		clone.CFrame = hook.CFrame
	end
	if attach then
		for _, part in partsOf(clone) do
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hook
			weld.Part1 = part
			weld.Parent = part
		end
	end
	clone.Parent = hook
	hook.Transparency = 1
	return clone
end

return PropService
