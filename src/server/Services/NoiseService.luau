--!strict
-- Gameplay noise events (sprinting, failed repairs, revives...). Anything can emit a noise;
-- the Echo subscribes and decides what it can hear. Noises are server-only: clients can't emit them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

export type Noise = {
	position: Vector3,
	loudness: number, -- 0..1
	time: number, -- os.clock() when emitted
	source: string,
}

local NoiseService = {}

local listeners: { [number]: (Noise) -> () } = {}
local nextId = 0

function NoiseService.emit(position: Vector3, loudness: number, source: string)
	local noise: Noise = {
		position = position,
		loudness = math.clamp(loudness, 0, 1),
		time = os.clock(),
		source = source,
	}
	Log.debug(
		"Noise",
		"%s at %.0f,%.0f,%.0f (%.1f)",
		source,
		position.X,
		position.Y,
		position.Z,
		noise.loudness
	)
	for _, listener in listeners do
		task.spawn(listener, noise)
	end
end

-- Returns a function that unsubscribes.
function NoiseService.subscribe(listener: (Noise) -> ()): () -> ()
	nextId += 1
	local id = nextId
	listeners[id] = listener
	return function()
		listeners[id] = nil
	end
end

return NoiseService
