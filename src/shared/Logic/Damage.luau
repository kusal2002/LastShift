--!strict
-- Damage, downed and revive rules. Pure: no Roblox APIs.
-- A player can be downed once per round. A lethal hit after that, or any hit while
-- downed, eliminates them.
export type Config = {
	Max: number,
	HitProtectionSeconds: number,
	ReviveProtectionSeconds: number,
	ReviveHealth: number,
}

export type State = {
	health: number,
	downed: boolean,
	downedUsed: boolean,
	protectedUntil: number,
}

export type HitResult = "Ignored" | "Damaged" | "Downed" | "Killed"

local Damage = {}

function Damage.new(config: Config): State
	return { health = config.Max, downed = false, downedUsed = false, protectedUntil = 0 }
end

function Damage.isValidAmount(amount: any): boolean
	return type(amount) == "number" and amount == amount and amount > 0 and amount < math.huge
end

-- Applies a hit at time `now`. Returns what happened and the new state.
function Damage.resolve(state: State, amount: number, now: number, config: Config): (HitResult, State)
	if not Damage.isValidAmount(amount) or now < state.protectedUntil then
		return "Ignored", state
	end
	if state.downed then
		return "Killed", { health = 0, downed = false, downedUsed = true, protectedUntil = now }
	end
	local remaining = state.health - amount
	local protectedUntil = now + config.HitProtectionSeconds
	if remaining > 0 then
		return "Damaged",
			{
				health = remaining,
				downed = false,
				downedUsed = state.downedUsed,
				protectedUntil = protectedUntil,
			}
	end
	if not state.downedUsed then
		return "Downed", { health = 0, downed = true, downedUsed = true, protectedUntil = protectedUntil }
	end
	return "Killed", { health = 0, downed = false, downedUsed = true, protectedUntil = now }
end

function Damage.revive(state: State, now: number, config: Config): State
	return {
		health = config.ReviveHealth,
		downed = false,
		downedUsed = state.downedUsed,
		protectedUntil = now + config.ReviveProtectionSeconds,
	}
end

return Damage
