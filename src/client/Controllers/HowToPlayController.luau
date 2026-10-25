--!strict
-- A short "how to play" guide, opened from the lobby. Explains the goal, controls and tools
-- without spelling out how each anomaly behaves; that is for players to work out.
local Client = script.Parent.Parent
local Theme = require(Client.UI.Theme)
local Overlay = require(Client.UI.Overlay)

local SECTIONS: { { title: string, lines: { string } } } = {
	{
		title = "YOUR SHIFT",
		lines = {
			"You're a night technician sent to restore Relay Station K-7. Something is inside.",
			"1. Replace the blown fuse, tune the radio to the posted frequency, and recover evidence.",
			"2. At the transmitter in Operations, report which anomaly you think it is.",
			"3. TRANSMIT (survive a countdown, bigger reward) or ABORT (leave now).",
			"4. Reach the loading bay before the exit seals.",
		},
	},
	{
		title = "CONTROLS",
		lines = {
			"Keyboard: WASD move, hold Shift sprint, F flashlight, G noise maker, J notes, E interact (hold), hold Left Alt for the mouse cursor.",
			"Gamepad: left stick move, L3 sprint, Y flashlight, X noise maker, D-pad left notes.",
			"Touch: thumbstick to move; RUN, LIGHT and DECOY buttons; tap prompts to interact.",
		},
	},
	{
		title = "STAYING ALIVE",
		lines = {
			"Walking is quiet. Sprinting is loud and something may hear it.",
			"A lit flashlight helps you see, and helps you be seen. Batteries run out; chargers are limited.",
			"Learn its sounds. Clicking, breathing and a rising screech all mean something.",
			"When it lunges there is a brief warning: move away.",
			"Your first serious hit puts you down, not out. A teammate can revive you. Alone, you get up once.",
		},
	},
	{
		title = "EVIDENCE",
		lines = {
			"Recordings, logs and readings describe what is in the station. Check NOTES.",
			"Not every signal can be trusted. Check where your teammates really are (HUD team list).",
			"Escape with evidence to add it to your permanent casebook.",
		},
	},
}

local HowToPlayController = {}

local overlay: Overlay.Overlay? = nil

function HowToPlayController.start()
	local current = Overlay.new("HowToPlay", 16, Vector2.new(540, 640))
	overlay = current
	current.title.Text = "HOW TO PLAY"
	for _, section in SECTIONS do
		Theme.label(current.body, section.title, 15, Theme.Colors.Amber, true)
		for _, line in section.lines do
			Theme.label(current.body, line, 14)
		end
	end
end

function HowToPlayController.toggle()
	local current = overlay
	if current then
		current.toggle()
	end
end

function HowToPlayController.close()
	local current = overlay
	if current then
		current.close()
	end
end

return HowToPlayController
