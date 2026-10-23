--!strict
-- Chooses when and which scare event happens. Pure: no Roblox APIs.
-- Rules: a quiet start, a minimum gap between any two events (shorter as intensity rises),
-- per-event cooldowns, minimum intensity per event, and events that are currently blocked.
export type EventDef = { Id: string, Cooldown: number, MinIntensity: number }

export type Config = {
	StartDelay: number,
	MinGapStart: number,
	MinGapEnd: number,
}

export type State = {
	startedAt: number,
	lastEventAt: number,
	lastById: { [string]: number },
}

local ScareDirector = {}

function ScareDirector.new(startedAt: number): State
	return { startedAt = startedAt, lastEventAt = -math.huge, lastById = {} }
end

-- 0 at the start of investigation, 1 at the end; extraction is always 1.
function ScareDirector.intensity(elapsed: number, duration: number, extracting: boolean): number
	if extracting then
		return 1
	end
	if duration <= 0 then
		return 0
	end
	return math.clamp(elapsed / duration, 0, 1)
end

function ScareDirector.minGap(intensity: number, config: Config): number
	return config.MinGapStart + (config.MinGapEnd - config.MinGapStart) * math.clamp(intensity, 0, 1)
end

-- Returns an event id or nil. `random()` must return a number in [0, 1).
function ScareDirector.pick(
	state: State,
	now: number,
	intensity: number,
	events: { EventDef },
	weights: { [string]: number },
	blocked: { [string]: boolean },
	config: Config,
	random: () -> number
): string?
	if now - state.startedAt < config.StartDelay then
		return nil
	end
	if now - state.lastEventAt < ScareDirector.minGap(intensity, config) then
		return nil
	end
	local candidates: { EventDef } = {}
	local total = 0
	for _, event in events do
		local weight = weights[event.Id] or 0
		local last = state.lastById[event.Id] or -math.huge
		if
			weight > 0
			and not blocked[event.Id]
			and intensity >= event.MinIntensity
			and now - last >= event.Cooldown
		then
			table.insert(candidates, event)
			total += weight
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = random() * total
	for _, event in candidates do
		roll -= weights[event.Id]
		if roll < 0 then
			return event.Id
		end
	end
	return candidates[#candidates].Id
end

function ScareDirector.record(state: State, id: string, now: number)
	state.lastEventAt = now
	state.lastById[id] = now
end

return ScareDirector
