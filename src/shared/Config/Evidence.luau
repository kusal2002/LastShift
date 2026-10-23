--!strict
-- Evidence definitions. Each item points to one anomaly. Descriptions are clues, never answers:
-- players compare them against what they observed to classify the anomaly.
-- Add new evidence here; no gameplay code needs to change.

export type Category = "Recording" | "Document" | "Reading" | "Visual"

export type EvidenceDef = {
	Id: string, -- stable identifier (used for the permanent casebook in Phase 6)
	DisplayName: string,
	Description: string,
	Category: Category,
	Anomaly: string, -- Config/Anomalies id this evidence supports
	Reward: number, -- credits for recovering it
	Risky: boolean, -- optional, placed near the Echo's lair, louder to pick up, worth more
}

local items: { EvidenceDef } = {
	-- Listener
	{
		Id = "listener_muffled_tape",
		DisplayName = "Muffled Tape",
		Description = "Every voice on the tape is a whisper. At 03:12 someone drops a wrench, and the tape cuts to static for a full minute.",
		Category = "Recording",
		Anomaly = "Listener",
		Reward = 10,
		Risky = false,
	},
	{
		Id = "listener_maintenance_log",
		DisplayName = "Maintenance Log 7",
		Description = '"Stopped running the generator at night. It only comes when the generator\'s loud."',
		Category = "Document",
		Anomaly = "Listener",
		Reward = 10,
		Risky = false,
	},
	{
		Id = "listener_mic_readout",
		DisplayName = "Microphone Readout",
		Description = "The station microphones peaked at 140 dB. Nothing on camera made a sound.",
		Category = "Reading",
		Anomaly = "Listener",
		Reward = 10,
		Risky = false,
	},
	{
		Id = "listener_foam_order",
		DisplayName = "Soundproofing Order",
		Description = "A requisition for acoustic foam, signed in shaking handwriting. Marked URGENT three times.",
		Category = "Document",
		Anomaly = "Listener",
		Reward = 10,
		Risky = false,
	},
	{
		Id = "listener_footstep_recording",
		DisplayName = "Footstep Recording",
		Description = "A recording of footsteps that match yours, played back from inside the tower.",
		Category = "Recording",
		Anomaly = "Listener",
		Reward = 30,
		Risky = true,
	},
	-- Mimic
	{
		Id = "mimic_duplicate_calls",
		DisplayName = "Duplicate Call Log",
		Description = "Two calls from Technician Hale at 02:40: one from the tower, one from the hall. Hale was off shift.",
		Category = "Document",
		Anomaly = "Mimic",
		Reward = 10,
		Risky = false,
	},
	{
		Id = "mimic_voice_analysis",
		DisplayName = "Voice Analysis",
		Description = "A spectrograph of a radio call. The voice never pauses to breathe.",
		Category = "Reading",
		Anomaly = "Mimic",
		Reward = 10,
		Risky = false,
	},
	{
		Id = "mimic_unsent_message",
		DisplayName = "Unsent Message",
		Description = "\"If I call you on the radio, don't come. It won't be me.\"",
		Category = "Recording",
		Anomaly = "Mimic",
		Reward = 10,
		Risky = false,
	},
	{
		Id = "mimic_camera_still",
		DisplayName = "Camera Still",
		Description = "A hall camera frame: a technician waving at the lens. Their face is blurred at every resolution.",
		Category = "Visual",
		Anomaly = "Mimic",
		Reward = 10,
		Risky = false,
	},
	{
		Id = "mimic_your_voice",
		DisplayName = "Tape Labelled Tonight",
		Description = "Today's date is on the label. The voice asking for help sounds exactly like yours.",
		Category = "Recording",
		Anomaly = "Mimic",
		Reward = 30,
		Risky = true,
	},
	-- Blackout
	{
		Id = "blackout_power_draw",
		DisplayName = "Power Draw Printout",
		Description = "The station drew full power for six minutes while the generator was offline.",
		Category = "Reading",
		Anomaly = "Blackout",
		Reward = 10,
		Risky = false,
	},
	{
		Id = "blackout_flashlight_log",
		DisplayName = "Flashlight Log",
		Description = '"Keep your light on it. It hates the light. The batteries won\'t last."',
		Category = "Document",
		Anomaly = "Blackout",
		Reward = 10,
		Risky = false,
	},
	{
		Id = "blackout_breaker_report",
		DisplayName = "Breaker Report",
		Description = "Every breaker tripped at once. Someone pulled them by hand, in the dark.",
		Category = "Document",
		Anomaly = "Blackout",
		Reward = 10,
		Risky = false,
	},
	{
		Id = "blackout_thermal_image",
		DisplayName = "Thermal Image",
		Description = "A cold silhouette in a dark corridor. In the next frame, with the lights on, there is nothing.",
		Category = "Visual",
		Anomaly = "Blackout",
		Reward = 10,
		Risky = false,
	},
	{
		Id = "blackout_bulb_box",
		DisplayName = "Box of Dead Bulbs",
		Description = "A crate of burnt-out bulbs. Every one shattered outward, from the inside.",
		Category = "Visual",
		Anomaly = "Blackout",
		Reward = 30,
		Risky = true,
	},
}

local byId: { [string]: EvidenceDef } = {}
for _, item in items do
	byId[item.Id] = table.freeze(item)
end

return table.freeze({
	Items = table.freeze(items),
	ById = table.freeze(byId),
	SpawnCount = 3, -- standard items placed per round (all for the active anomaly)
	Required = 2, -- items needed to complete the evidence objective
	InteractDistance = 8,
	HoldDuration = 1,
	RiskyNoise = 0.8, -- loudness when the risky item is taken
})
