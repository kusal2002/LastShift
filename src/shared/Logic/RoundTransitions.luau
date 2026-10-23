--!strict
-- Which round phase may follow which. Pure: no Roblox APIs.
-- Investigation -> Decision (objectives done) -> Transmission (team chose to transmit) or
-- straight to Extraction (team aborted) -> Results.
export type Phase =
	"Lobby"
	| "Briefing"
	| "Investigation"
	| "Decision"
	| "Transmission"
	| "Extraction"
	| "Results"

local ALLOWED: { [string]: { [string]: boolean } } = {
	Lobby = { Briefing = true },
	Briefing = { Investigation = true, Lobby = true }, -- Lobby = cancelled (everyone left)
	Investigation = { Decision = true, Results = true, Lobby = true },
	Decision = { Transmission = true, Extraction = true, Results = true, Lobby = true },
	Transmission = { Extraction = true, Results = true, Lobby = true },
	Extraction = { Results = true, Lobby = true },
	Results = { Lobby = true },
}

local ACTIVE: { [string]: boolean } = {
	Investigation = true,
	Decision = true,
	Transmission = true,
	Extraction = true,
}

local RoundTransitions = {}

function RoundTransitions.canTransition(from: Phase, to: Phase): boolean
	local targets = ALLOWED[from]
	return targets ~= nil and targets[to] == true
end

-- Phases where players are inside the station and can act.
function RoundTransitions.isActiveRound(phase: Phase): boolean
	return ACTIVE[phase] == true
end

return RoundTransitions
