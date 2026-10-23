--!strict
-- Station lights. Blackouts (outages) are server-authoritative: lamps in the affected rooms
-- really turn off for everyone, and the Echo reads isOutage(). Flickers are cosmetic and run on
-- each client, so players with reduced-flash settings get a gentle dim instead.
-- The backup power switch ends an outage early, at the cost of a loud noise.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local DirectorConfig = require(Shared.Config.Director)
local EnemyConfig = require(Shared.Config.Enemy)
local Tags = require(Shared.Config.Tags)
local Remotes = require(Shared.Remotes)
local Maid = require(Shared.Util.Maid)
local Log = require(Shared.Util.Log)
local MapService = require(script.Parent.MapService)
local InteractionService = require(script.Parent.InteractionService)
local NoiseService = require(script.Parent.NoiseService)
local RemoteService = require(script.Parent.RemoteService)

type LampState = { light: PointLight?, color: Color3, material: Enum.Material }

local DARK_COLOR = Color3.fromRGB(28, 28, 30)

local LightingService = {}

local lamps: { [BasePart]: LampState } = {}
local outageRooms: { [string]: boolean } = {}
local outageEndsAt: number? = nil
local switchPrompts: { ProximityPrompt } = {}
local roundMaid = Maid.new()
local onRestored: (byPlayer: Player?) -> () = function(_byPlayer: Player?) end

local function setLamp(lamp: BasePart, state: LampState, on: boolean)
	local light = state.light
	if light then
		light.Enabled = on
	end
	lamp.Material = if on then state.material else Enum.Material.SmoothPlastic
	lamp.Color = if on then state.color else DARK_COLOR
end

local function setSwitchesEnabled(enabled: boolean)
	for _, prompt in switchPrompts do
		prompt.Enabled = enabled
	end
end

function LightingService.Init()
	for _, lamp in MapService.getTagged(Tags.StationLight) do
		lamps[lamp] = {
			light = lamp:FindFirstChildOfClass("PointLight"),
			color = lamp.Color,
			material = lamp.Material,
		}
	end
end

function LightingService.isOutage(): boolean
	return outageEndsAt ~= nil
end

function LightingService.isRoomDark(room: string): boolean
	return outageRooms[room] == true
end

function LightingService.startOutage(rooms: { string }, duration: number)
	for _, room in rooms do
		outageRooms[room] = true
	end
	for lamp, state in lamps do
		local room = lamp:GetAttribute("Room")
		if type(room) == "string" and outageRooms[room] then
			setLamp(lamp, state, false)
		end
	end
	outageEndsAt = os.clock() + duration
	setSwitchesEnabled(true)
	Log.debug("Lighting", "Outage in %s for %ds", table.concat(rooms, ", "), duration)
end

-- Returns true if an outage was active.
function LightingService.endOutage(): boolean
	local wasActive = outageEndsAt ~= nil
	for lamp, state in lamps do
		setLamp(lamp, state, true)
	end
	table.clear(outageRooms)
	outageEndsAt = nil
	setSwitchesEnabled(false)
	return wasActive
end

-- Called by the director every tick; ends timed-out outages.
function LightingService.update()
	local endsAt = outageEndsAt
	if endsAt ~= nil and os.clock() >= endsAt then
		LightingService.endOutage()
		onRestored(nil)
	end
end

-- Cosmetic flicker, animated on each client.
function LightingService.flicker(players: { Player }, room: string, seconds: number)
	for _, player in players do
		RemoteService.fire(player, Remotes.Names.LightFlicker, room, seconds)
	end
end

-- Sets up the backup power switches. `restored` is called when power returns
-- (with the player who flipped the switch, or nil if the outage simply ran out).
function LightingService.beginRound(restored: (byPlayer: Player?) -> ())
	LightingService.endRound()
	onRestored = restored
	local config = DirectorConfig.Outage
	for _, switch in MapService.getTagged(Tags.PowerSwitch) do
		local prompt = InteractionService.createPrompt(switch, {
			ActionText = "Restore power",
			ObjectText = "Backup Power",
			HoldDuration = config.SwitchHoldSeconds,
			MaxDistance = config.SwitchInteractDistance,
		}, function(player: Player)
			if not LightingService.endOutage() then
				return
			end
			-- Throwing the old breaker is loud.
			NoiseService.emit(switch.Position, EnemyConfig.Noise.FuseInsert, "PowerSwitch")
			onRestored(player)
		end)
		prompt.Enabled = false
		table.insert(switchPrompts, prompt)
		roundMaid:give(prompt)
	end
end

function LightingService.endRound()
	LightingService.endOutage()
	roundMaid:clean()
	table.clear(switchPrompts)
	onRestored = function(_byPlayer: Player?) end
end

return LightingService
