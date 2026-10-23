--!strict
-- Stamina rules for sprinting. Pure: no Roblox APIs.
export type Config = {
	Max: number,
	DrainPerSecond: number,
	RegenPerSecond: number,
	RegenDelay: number,
	ExhaustedThreshold: number,
}

export type State = {
	value: number,
	exhausted: boolean, -- ran dry; can't sprint until ExhaustedThreshold is reached
	sinceSprint: number, -- seconds since the player last sprinted
}

local Stamina = {}

function Stamina.new(config: Config): State
	return { value = config.Max, exhausted = false, sinceSprint = math.huge }
end

-- Advances stamina by dt. Returns the new state and whether the player is sprinting this tick.
function Stamina.step(
	state: State,
	dt: number,
	wantsSprint: boolean,
	isMoving: boolean,
	config: Config
): (State, boolean)
	local value = state.value
	local exhausted = state.exhausted
	local sinceSprint = state.sinceSprint

	local sprinting = wantsSprint and isMoving and not exhausted and value > 0
	if sprinting then
		value = math.max(0, value - config.DrainPerSecond * dt)
		sinceSprint = 0
		if value <= 0 then
			exhausted = true
		end
	else
		sinceSprint += dt
		if sinceSprint >= config.RegenDelay then
			value = math.min(config.Max, value + config.RegenPerSecond * dt)
		end
		if exhausted and value >= config.ExhaustedThreshold then
			exhausted = false
		end
	end

	return { value = value, exhausted = exhausted, sinceSprint = sinceSprint }, sprinting
end

return Stamina
