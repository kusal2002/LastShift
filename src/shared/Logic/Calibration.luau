--!strict
-- Frequency math for the signal calibration objective. Pure: no Roblox APIs.
-- Values are compared as whole numbers of steps to avoid floating-point drift.
local Calibration = {}

function Calibration.toSteps(value: number, step: number): number
	return math.round(value / step)
end

function Calibration.isValidInput(value: any, min: number, max: number): boolean
	if type(value) ~= "number" then
		return false
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return false
	end
	return value >= min - 1e-6 and value <= max + 1e-6
end

function Calibration.isMatch(value: number, target: number, step: number): boolean
	return Calibration.toSteps(value, step) == Calibration.toSteps(target, step)
end

-- nextInt(a, b) must return a whole number in [a, b].
function Calibration.randomTarget(
	nextInt: (number, number) -> number,
	min: number,
	max: number,
	step: number
): number
	local low = Calibration.toSteps(min, step)
	local high = Calibration.toSteps(max, step)
	-- Keep the target away from the dial's starting value (the minimum).
	local steps = nextInt(math.min(low + 10, high), high)
	return steps * step
end

function Calibration.format(value: number): string
	return string.format("%05.1f MHz", value)
end

return Calibration
