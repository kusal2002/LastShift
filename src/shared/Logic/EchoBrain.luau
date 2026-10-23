--!strict
-- The Echo's decision rules. Pure: no Roblox APIs, so every transition is unit-tested.
-- The server's Echo object gathers a Perception each AI tick and acts on the returned state.
export type State =
	"Dormant"
	| "Patrol"
	| "Listen"
	| "Investigate"
	| "Stalk"
	| "Hunt"
	| "Attack"
	| "Search"
	| "Retreat"
	| "Recover"

export type Perception = {
	awake: boolean, -- the round allows the Echo to act
	stateTime: number, -- seconds spent in the current state
	canSeeTarget: boolean,
	targetDistance: number?, -- distance to the seen target, if any
	timeSinceSeen: number, -- seconds since any target was last seen
	alert: number,
	heardSound: boolean, -- an audible, unhandled sound is waiting
	arrived: boolean, -- reached the current movement goal
	pathFailed: boolean, -- the current movement goal could not be reached
	attackReady: boolean, -- attack cooldown has elapsed
	attackHit: boolean, -- the last attack's windup ended in a hit
	solo: boolean,
}

export type Config = {
	HuntThreshold: number,
	CloseDistance: number,
	ListenDuration: number,
	InvestigateMaxSeconds: number,
	SearchDuration: number,
	StalkDuration: number,
	StalkBreakDistance: number,
	LoseTrackSeconds: number,
	ChaseDuration: number,
	SoloChaseDuration: number,
	RetreatMaxSeconds: number,
	RecoverDuration: number,
	AttackRange: number,
	AttackWindup: number,
	AttackRecovery: number,
	AlertGainPerSecond: number,
	AlertDecayPerSecond: number,
}

local EchoBrain = {}

local function isClose(p: Perception, distance: number): boolean
	local d = p.targetDistance
	return p.canSeeTarget and d ~= nil and d <= distance
end

local function onSight(p: Perception, config: Config): State
	if p.alert >= config.HuntThreshold or isClose(p, config.CloseDistance) then
		return "Hunt"
	end
	return "Stalk"
end

function EchoBrain.decide(state: State, p: Perception, config: Config): State
	if not p.awake then
		return "Dormant"
	end

	if state == "Dormant" then
		return "Patrol"
	elseif state == "Patrol" then
		if p.canSeeTarget then
			return onSight(p, config)
		end
		if p.heardSound then
			return "Listen"
		end
	elseif state == "Listen" then
		if p.canSeeTarget then
			return onSight(p, config)
		end
		if p.stateTime >= config.ListenDuration then
			return "Investigate"
		end
	elseif state == "Investigate" then
		if p.canSeeTarget then
			return onSight(p, config)
		end
		if p.arrived or p.pathFailed or p.stateTime >= config.InvestigateMaxSeconds then
			return "Search"
		end
	elseif state == "Stalk" then
		if p.alert >= config.HuntThreshold or isClose(p, config.StalkBreakDistance) then
			return "Hunt"
		end
		if not p.canSeeTarget and p.timeSinceSeen >= config.LoseTrackSeconds then
			return "Search"
		end
		if p.stateTime >= config.StalkDuration then
			return "Retreat"
		end
	elseif state == "Hunt" then
		if isClose(p, config.AttackRange) and p.attackReady then
			return "Attack"
		end
		if not p.canSeeTarget and (p.timeSinceSeen >= config.LoseTrackSeconds or p.pathFailed) then
			return "Search"
		end
		local limit = if p.solo then config.SoloChaseDuration else config.ChaseDuration
		if p.stateTime >= limit then
			return "Retreat"
		end
	elseif state == "Attack" then
		if p.stateTime >= config.AttackWindup + config.AttackRecovery then
			-- After a hit it backs off, giving the victim a chance to escape or be revived.
			return if p.attackHit then "Retreat" else "Hunt"
		end
	elseif state == "Search" then
		if p.canSeeTarget then
			return onSight(p, config)
		end
		if p.heardSound then
			return "Listen"
		end
		if p.stateTime >= config.SearchDuration then
			return "Recover"
		end
	elseif state == "Retreat" then
		if p.arrived or p.pathFailed or p.stateTime >= config.RetreatMaxSeconds then
			return "Recover"
		end
	elseif state == "Recover" then
		if p.stateTime >= config.RecoverDuration then
			return "Patrol"
		end
	end
	return state
end

-- Alert rises faster the closer the seen player is; decays when no one is in sight.
function EchoBrain.updateAlert(
	alert: number,
	dt: number,
	seeing: boolean,
	distance: number?,
	sightRange: number,
	config: Config
): number
	if seeing and distance ~= nil then
		local closeness = 1.5 - math.clamp(distance / sightRange, 0, 1)
		return math.min(100, alert + config.AlertGainPerSecond * closeness * dt)
	end
	return math.max(0, alert - config.AlertDecayPerSecond * dt)
end

-- Horizontal field-of-view test. forward and toTarget are XZ directions (need not be unit length).
function EchoBrain.isInFieldOfView(
	forwardX: number,
	forwardZ: number,
	toX: number,
	toZ: number,
	fovDegrees: number
): boolean
	local forwardLength = math.sqrt(forwardX * forwardX + forwardZ * forwardZ)
	local toLength = math.sqrt(toX * toX + toZ * toZ)
	if forwardLength == 0 or toLength == 0 then
		return true
	end
	local cosine = (forwardX * toX + forwardZ * toZ) / (forwardLength * toLength)
	return cosine >= math.cos(math.rad(fovDegrees / 2))
end

export type HeardSound = { distance: number, loudness: number, age: number }

-- Index of the most noticeable audible sound, or nil. A sound is audible when it is recent,
-- loud enough, and within HearingRadius scaled by its loudness.
function EchoBrain.pickSound(
	sounds: { HeardSound },
	hearingRadius: number,
	memorySeconds: number,
	minLoudness: number
): number?
	local bestIndex: number? = nil
	local bestScore = -math.huge
	for index, sound in sounds do
		local reach = hearingRadius * sound.loudness
		if sound.age <= memorySeconds and sound.loudness >= minLoudness and sound.distance <= reach then
			local score = reach - sound.distance - sound.age
			if score > bestScore then
				bestScore = score
				bestIndex = index
			end
		end
	end
	return bestIndex
end

return EchoBrain
