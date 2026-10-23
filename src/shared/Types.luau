--!strict
-- Data shapes shared between server and client.

export type Phase = "Lobby" | "Briefing" | "Investigation" | "Extraction" | "Results"
export type PlayerStatus = "Alive" | "Escaped" | "Dead" | "Lost" | "Left"

export type ObjectiveView = {
	Id: string,
	Kind: string,
	Label: string,
	Detail: string,
	Complete: boolean,
}

export type BriefingView = {
	Location: string,
	Objective: string,
	Controls: string,
}

-- Sent to each player whenever round state changes.
export type Snapshot = {
	RoundId: number,
	Phase: Phase,
	PhaseEndsAt: number?, -- workspace:GetServerTimeNow() time; nil when no timer is running
	PlayerCount: number,
	ReadyCount: number,
	MinPlayers: number,
	IsReady: boolean,
	IsParticipant: boolean,
	Status: PlayerStatus?,
	Objectives: { ObjectiveView },
	ExitOpen: boolean,
	Briefing: BriefingView?,
}

export type TeamMemberResult = {
	Name: string,
	Status: PlayerStatus,
}

export type Results = {
	RoundId: number,
	Success: boolean,
	Reason: string,
	YourStatus: PlayerStatus,
	ObjectivesCompleted: number,
	ObjectivesTotal: number,
	Evidence: { string },
	DurationSeconds: number,
	Team: { TeamMemberResult },
}

export type CalibrationParams = {
	Min: number,
	Max: number,
	Step: number,
	AttemptsLeft: number,
}

return {}
