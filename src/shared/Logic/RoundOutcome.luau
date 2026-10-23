--!strict
-- Decides when a round ends and whether it succeeded. Pure: no Roblox APIs.
export type Status = "Alive" | "Escaped" | "Dead" | "Lost" | "Left"
export type Reason = "Extracted" | "AllLost" | "TimeUp" | "ExtractionMissed" | ""

local RoundOutcome = {}

function RoundOutcome.count(statuses: { [any]: Status }, status: Status): number
	local total = 0
	for _, value in statuses do
		if value == status then
			total += 1
		end
	end
	return total
end

-- True when every participant has left the server (round is cancelled, no results).
function RoundOutcome.isAbandoned(statuses: { [any]: Status }): boolean
	for _, value in statuses do
		if value ~= "Left" then
			return false
		end
	end
	return true
end

function RoundOutcome.isSuccess(statuses: { [any]: Status }): boolean
	return RoundOutcome.count(statuses, "Escaped") > 0
end

-- phase: current phase name. timeExpired: the phase timer has run out.
function RoundOutcome.decideEnd(
	phase: string,
	statuses: { [any]: Status },
	timeExpired: boolean
): (boolean, Reason)
	local escaped = RoundOutcome.count(statuses, "Escaped") > 0
	if RoundOutcome.count(statuses, "Alive") == 0 then
		return true, if escaped then "Extracted" else "AllLost"
	end
	if timeExpired then
		if phase == "Extraction" then
			return true, if escaped then "Extracted" else "ExtractionMissed"
		end
		return true, "TimeUp"
	end
	return false, ""
end

-- Anyone still inside when the round ends is left behind.
function RoundOutcome.finalize(statuses: { [any]: Status })
	for key, value in statuses do
		if value == "Alive" then
			statuses[key] = "Lost"
		end
	end
end

return RoundOutcome
