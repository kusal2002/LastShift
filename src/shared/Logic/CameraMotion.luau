--!strict
-- Bodycam camera rules: when first person is used, walking sway and field of view.
-- Pure: no Roblox APIs, so it runs in unit tests. The client turns the offset into a CFrame.
export type MotionConfig = {
	WalkSpeedReference: number,
	MovingSpeed: number,
	CycleHz: number,
	MaxSpeedScale: number,
	Response: number,
	BobHeight: number,
	BobSide: number,
	RollDegrees: number,
	PitchDegrees: number,
	SprintMultiplier: number,
	DownedMultiplier: number,
	SprintFovBoost: number,
	BreathHz: number,
	BreathPitchDegrees: number,
	BreathYawDegrees: number,
	MaxStep: number,
}

export type State = {
	cycle: number, -- footstep cycle, radians
	breath: number, -- idle drift, radians
	moving: number, -- 0..1, eased
	sprint: number, -- 0..1, eased
}

export type Input = {
	speed: number, -- horizontal speed, studs/second
	sprinting: boolean,
	downed: boolean,
	grounded: boolean,
}

-- Camera-space offset: x/y in studs, angles in radians.
export type Offset = { x: number, y: number, pitch: number, yaw: number, roll: number }

local TAU = 2 * math.pi

local CameraMotion = {}

CameraMotion.ZERO = table.freeze({ x = 0, y = 0, pitch = 0, yaw = 0, roll = 0 }) :: Offset

function CameraMotion.new(): State
	return { cycle = 0, breath = 0, moving = 0, sprint = 0 }
end

-- First person only for a living participant inside an active round (see
-- RoundTransitions.isActiveRound). Lobby, briefing, results and spectating keep the normal camera.
function CameraMotion.wantsFirstPerson(
	activeRound: boolean,
	isParticipant: boolean,
	status: string?,
	characterAlive: boolean
): boolean
	return activeRound and isParticipant and status == "Alive" and characterAlive
end

-- Moves `current` toward `target` at a frame-rate independent speed.
function CameraMotion.approach(current: number, target: number, dt: number, response: number): number
	return current + (target - current) * (1 - math.exp(-response * dt))
end

-- Advances the sway by `dt` seconds. `intensity` is the player's setting (0 = no motion).
function CameraMotion.step(
	state: State,
	dt: number,
	input: Input,
	config: MotionConfig,
	intensity: number
): (State, Offset)
	dt = math.clamp(dt, 0, config.MaxStep)
	intensity = math.clamp(intensity, 0, 1)

	local walking = input.grounded and input.speed > config.MovingSpeed
	local moving = CameraMotion.approach(state.moving, if walking then 1 else 0, dt, config.Response)
	local sprint =
		CameraMotion.approach(state.sprint, if walking and input.sprinting then 1 else 0, dt, config.Response)

	local cycle = state.cycle
	if walking then
		local speedScale = math.clamp(input.speed / config.WalkSpeedReference, 0.5, config.MaxSpeedScale)
		cycle = (cycle + dt * TAU * config.CycleHz * speedScale) % TAU
	end
	local breath = (state.breath + dt * TAU * config.BreathHz) % (2 * TAU)

	local nextState: State = { cycle = cycle, breath = breath, moving = moving, sprint = sprint }
	if intensity <= 0 then
		return nextState, CameraMotion.ZERO
	end

	local strength = moving * (1 + sprint * (config.SprintMultiplier - 1))
	if input.downed then
		strength *= config.DownedMultiplier
	end
	strength *= intensity

	local side = math.sin(cycle) -- one full left-right sway per cycle
	local step = math.abs(side) -- two dips per cycle: one per footstep
	local still = (1 - moving) * intensity

	local offset: Offset = {
		x = side * config.BobSide * strength,
		y = -step * config.BobHeight * strength,
		pitch = math.rad(
			step * config.PitchDegrees * strength + math.sin(breath) * config.BreathPitchDegrees * still
		),
		yaw = math.rad(math.sin(breath * 0.5) * config.BreathYawDegrees * still),
		roll = math.rad(side * config.RollDegrees * strength),
	}
	return nextState, offset
end

-- Field of view to ease toward: the player's base setting, plus a small widening while sprinting.
function CameraMotion.targetFov(
	baseFov: number,
	sprint: number,
	config: MotionConfig,
	intensity: number
): number
	return baseFov + config.SprintFovBoost * math.clamp(sprint, 0, 1) * math.clamp(intensity, 0, 1)
end

return CameraMotion
