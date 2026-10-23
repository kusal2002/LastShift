--!strict
-- The three anomaly profiles. One is chosen per round. Each tweaks the shared Echo AI and
-- the event director rather than being a separate enemy.
--
-- EchoModifiers / DarkModifiers multiply values in Config/Enemy ("Speeds.Chase" = nested key).
-- DarkModifiers apply on top while a blackout is active.
-- EventWeights: how often each director event is picked (0 or missing = never).

export type Profile = {
	Id: string,
	DisplayName: string, -- used by classification in Phase 5; never shown before then
	BriefingHint: string, -- a hint, not an answer
	EchoModifiers: { [string]: number },
	DarkModifiers: { [string]: number }?,
	EventWeights: { [string]: number },
	DecoyCount: number, -- noise makers placed in the station
}

local profiles: { Profile } = {
	{
		Id = "Listener",
		DisplayName = "The Listener",
		BriefingHint = 'Recovered log: "It went still whenever we did."',
		EchoModifiers = {
			HearingRadius = 1.5,
			MinAudibleLoudness = 0.66,
			SightRange = 0.8,
			ListenDuration = 0.7,
			["Speeds.Investigate"] = 1.2,
		},
		EventWeights = {
			DistantFootsteps = 3,
			RadioInterference = 2,
			LightFlicker = 2,
			PAAnnouncement = 1,
		},
		DecoyCount = 2,
	},
	{
		Id = "Mimic",
		DisplayName = "The Mimic",
		BriefingHint = 'Recovered log: "Dispatch says they never sent that call."',
		EchoModifiers = {
			HearingRadius = 0.9,
			StalkDuration = 1.6,
			StalkDistance = 0.8,
			["Speeds.Chase"] = 0.95,
			["Speeds.ChaseMultiplayer"] = 0.95,
		},
		EventWeights = {
			DistantFootsteps = 2,
			RadioInterference = 2,
			LightFlicker = 1,
			PAAnnouncement = 1,
			MimicCall = 3,
			MimicFalseCue = 2,
			MimicPA = 1,
		},
		DecoyCount = 1,
	},
	{
		Id = "Blackout",
		DisplayName = "The Blackout",
		BriefingHint = 'Recovered log: "Keep the lights on. Whatever it takes."',
		EchoModifiers = {
			SightRange = 0.9,
		},
		DarkModifiers = {
			SightRange = 1.3,
			HuntThreshold = 0.6,
			["Speeds.Chase"] = 1.1, -- 17.6: still slower than a sprinting player
			["Speeds.ChaseMultiplayer"] = 1.1,
		},
		EventWeights = {
			DistantFootsteps = 2,
			RadioInterference = 1,
			LightFlicker = 3,
			PAAnnouncement = 1,
			PowerOutage = 3,
		},
		DecoyCount = 1,
	},
}

local byId: { [string]: Profile } = {}
for _, profile in profiles do
	byId[profile.Id] = profile
end

return table.freeze({
	List = table.freeze(profiles),
	ById = table.freeze(byId),
})
