--!strict
-- Data shapes shared between server and client.

export type Phase =
	"Lobby"
	| "Briefing"
	| "Investigation"
	| "Decision"
	| "Transmission"
	| "Extraction"
	| "Results"
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
	Classified: string, -- a hint about this round's anomaly
}

export type TeamMemberView = {
	UserId: number,
	Name: string,
	Status: PlayerStatus,
	Downed: boolean,
	Location: string, -- room name, or "" when unknown or outside
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
	Team: { TeamMemberView }, -- this round's participants; empty when not in a round
	Evidence: { EvidenceView }, -- recovered this round; empty when not a participant
}

export type EvidenceView = {
	Id: string,
	DisplayName: string,
	Description: string,
	Category: string,
	Risky: boolean,
}

export type AnomalyOption = { Id: string, DisplayName: string }

-- Sent when a player opens the transmitter.
export type DecisionOptions = {
	Anomalies: { AnomalyOption },
	TransmitSeconds: number,
}

export type RewardLine = { Label: string, Amount: number }

export type CasebookEntry = {
	Id: string,
	DisplayName: string,
	Description: string,
	Category: string,
	AnomalyName: string, -- revealed once you have escaped with this evidence
}

export type AnomalyRecordView = { Id: string, DisplayName: string, Encounters: number, Identified: number }

-- The local player's saved progress, sent on load and after every change.
export type ProfileView = {
	Persistent: boolean, -- false when Studio is using the mock store (nothing is saved)
	Credits: number,
	XP: number,
	Level: number,
	IntoLevel: number,
	ToNext: number, -- 0 at max level
	Owned: { string },
	Equipped: { [string]: string },
	Casebook: { CasebookEntry },
	EvidenceTotal: number,
	Anomalies: { AnomalyRecordView },
	Settings: { [string]: boolean },
	Stats: { Rounds: number, Escapes: number, Transmissions: number, CorrectReports: number },
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
	AnomalyName: string, -- revealed at the end of the round
	Classification: string, -- "Correct" | "Incorrect" | "None"
	ClassifiedAs: string?, -- what the team chose, if anything
	Ending: string, -- "Transmit" | "Abort" | "None"
	TransmitCompleted: boolean,
	Credits: number,
	XP: number,
	Breakdown: { RewardLine },
}

export type AudioCuePayload = {
	Cue: string,
	Text: string?, -- replaces the cue's default subtitle
	Position: Vector3?, -- spatial cues only
}

export type CalibrationParams = {
	Min: number,
	Max: number,
	Step: number,
	AttemptsLeft: number,
}

return {}
