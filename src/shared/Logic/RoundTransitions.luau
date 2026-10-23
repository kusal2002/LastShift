--!strict
-- Which round phase may follow which. Pure: no Roblox APIs.
export type Phase = "Lobby" | "Briefing" | "Investigation" | "Extraction" | "Results"

local ALLOWED: { [string]: { [string]: boolean } } = {
	Lobby = { Briefing = true },
	Briefing = { Investigation = true, Lobby = true }, -- Lobby = cancelled (everyone left)
	Investigation = { Extraction = true, Results = true, Lobby = true },
	Extraction = { Results = true, Lobby = true },
	Results = { Lobby = true },
}

local RoundTransitions = {}

function RoundTransitions.canTransition(from: Phase, to: Phase): boolean
	local targets = ALLOWED[from]
	return targets ~= nil and targets[to] == true
end

-- Phases where players are inside the station and objectives can be worked on.
function RoundTransitions.isActiveRound(phase: Phase): boolean
	return phase == "Investigation" or phase == "Extraction"
end

return RoundTransitions
