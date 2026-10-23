--!strict
-- Audio cue catalogue. The server sends cue ids; clients play the sound if a verified asset
-- is configured in Config/Assets (Sounds[AssetKey]) and always show the subtitle, so every
-- important cue also has a text alternative. No asset IDs are invented here.

export type Cue = {
	Subtitle: string, -- shown when no Text override is sent
	Label: string?, -- prefix such as "PA" or "Radio"
	AssetKey: string, -- key into Assets.Sounds (may be missing)
	Volume: number,
	Important: boolean, -- important cues are subtitled even with ambient subtitles off
}

local cues: { [string]: Cue } = {
	-- Ambient and director events
	DistantFootsteps = {
		Subtitle = "[heavy footsteps somewhere in the station]",
		AssetKey = "FootstepsDistant",
		Volume = 0.6,
		Important = false,
	},
	RadioStatic = {
		Subtitle = "[the radios crackle with static]",
		AssetKey = "RadioStatic",
		Volume = 0.5,
		Important = false,
	},
	ElectricalBuzz = {
		Subtitle = "[lights buzz and stutter]",
		AssetKey = "ElectricalBuzz",
		Volume = 0.5,
		Important = false,
	},
	PAChime = { Subtitle = "[PA chime]", Label = "PA", AssetKey = "PAChime", Volume = 0.7, Important = true },
	RadioCall = {
		Subtitle = "[radio call]",
		Label = "Radio",
		AssetKey = "RadioCall",
		Volume = 0.7,
		Important = true,
	},
	PowerFailing = {
		Subtitle = "[the electrical hum falters... lights are about to fail]",
		AssetKey = "PowerFailing",
		Volume = 0.8,
		Important = true,
	},
	PowerDown = { Subtitle = "[power cut]", AssetKey = "PowerDown", Volume = 0.8, Important = true },
	PowerRestored = {
		Subtitle = "[backup power hums back on]",
		AssetKey = "PowerRestored",
		Volume = 0.7,
		Important = true,
	},
	ExtractionAlarm = {
		Subtitle = "[extraction alarm]",
		AssetKey = "ExtractionAlarm",
		Volume = 0.8,
		Important = true,
	},
	GhostStatic = {
		Subtitle = "[a burst of static where something should be]",
		AssetKey = "GhostStatic",
		Volume = 0.8,
		Important = true,
	},
	DecoyBeep = {
		Subtitle = "[a shrill electronic beeping]",
		AssetKey = "DecoyBeep",
		Volume = 0.9,
		Important = true,
	},
	-- Echo state cues, heard only near the Echo. Learnable warnings.
	EchoClick = {
		Subtitle = "[a low clicking, close by]",
		AssetKey = "EchoClick",
		Volume = 0.6,
		Important = true,
	},
	EchoWhisper = {
		Subtitle = "[something breathing, watching]",
		AssetKey = "EchoWhisper",
		Volume = 0.5,
		Important = true,
	},
	EchoScreech = {
		Subtitle = "[a rising screech: it's coming]",
		AssetKey = "EchoScreech",
		Volume = 0.9,
		Important = true,
	},
	EchoWindup = {
		Subtitle = "[a sharp intake of breath]",
		AssetKey = "EchoWindup",
		Volume = 0.9,
		Important = true,
	},
}

-- Authored lines. {room} and {name} are filled in by the server.
local paLines = {
	"Night crew, reminder: relay maintenance logs are due before sunrise.",
	"Station notice: do not respond to transmissions on unassigned frequencies.",
	"Attention. Sector lighting is operating on reduced capacity.",
	"Please remain calm. Please remain calm. Please remain calm.",
}

local mimicCallLines = {
	"{name}: Over here, {room}. I found something.",
	"{name}: Can anyone hear me? I'm stuck in the {room}.",
	"{name}: Come to the {room}. Quickly. Don't run.",
}

local mimicPALines = {
	"This is {name}. Everyone report to the {room}.",
	"{name} speaking. The exit is in the {room}. Come now.",
}

for _, cue in cues do
	table.freeze(cue)
end

return table.freeze({
	Cues = table.freeze(cues),
	PALines = table.freeze(paLines),
	MimicCallLines = table.freeze(mimicCallLines),
	MimicPALines = table.freeze(mimicPALines),
	EchoCueRadius = 60, -- players this close hear the Echo's state cues
})
