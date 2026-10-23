--!strict
-- Applies multipliers to a config table, returning a new (unfrozen) copy. Pure.
-- Keys may be nested with dots: { ["Speeds.Chase"] = 1.1 } multiplies base.Speeds.Chase.
local Tuning = {}

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value do
		copy[key] = deepCopy(inner)
	end
	return copy
end

function Tuning.apply(base: any, multipliers: { [string]: number }?): any
	local result = deepCopy(base)
	if multipliers == nil then
		return result
	end
	for path, factor in multipliers do
		local parts = string.split(path, ".")
		local node = result
		for index = 1, #parts - 1 do
			node = node[parts[index]]
			if type(node) ~= "table" then
				error(`Tuning: unknown key {path}`)
			end
		end
		local leaf = parts[#parts]
		if type(node[leaf]) ~= "number" then
			error(`Tuning: {path} is not a number`)
		end
		node[leaf] *= factor
	end
	return result
end

return Tuning
