--!strict
-- The transmitter. Unlocks once every objective is done. A player classifies the anomaly
-- (or says they're unsure) and chooses Transmit (a dangerous countdown, bigger reward) or
-- Abort (the exit opens now). The first valid submission decides for the team.
-- Everything is validated here; the client only sends its choice.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Anomalies = require(Shared.Config.Anomalies)
local ObjectivesConfig = require(Shared.Config.Objectives)
local RoundConfig = require(Shared.Config.Round)
local Tags = require(Shared.Config.Tags)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Maid = require(Shared.Util.Maid)
local Log = require(Shared.Util.Log)
local MapService = require(script.Parent.MapService)
local InteractionService = require(script.Parent.InteractionService)
local RemoteService = require(script.Parent.RemoteService)

export type Classification = "Correct" | "Incorrect" | "None"
export type Ending = "Transmit" | "Abort"

export type Choice = {
	classification: Classification,
	classifiedAs: string?, -- anomaly id chosen, nil if unsure
	ending: Ending,
	byName: string,
}

export type OpenParams = {
	anomalyId: string,
	onDecided: (Choice) -> (),
}

local UNSURE = "Unsure"
local Names = Remotes.Names
local config = ObjectivesConfig.Transmitter

local DecisionService = {}

local maid = Maid.new()
local isOpen = false
local decided: Choice? = nil
local anomalyId = ""
local transmitter: BasePart? = nil
local sessions: { [Player]: boolean } = {}
local onDecided: (Choice) -> () = function(_choice: Choice) end

local function options(): Types.DecisionOptions
	local list: { Types.AnomalyOption } = {}
	for _, profile in Anomalies.List do
		table.insert(list, { Id = profile.Id, DisplayName = profile.DisplayName })
	end
	return { Anomalies = list, TransmitSeconds = RoundConfig.TransmitDuration }
end

local function closeAll()
	for player in table.clone(sessions) do
		sessions[player] = nil
		if player.Parent ~= nil then
			RemoteService.fire(player, Names.DecisionClose)
		end
	end
end

local function decide(choice: Choice)
	decided = choice
	isOpen = false
	closeAll()
	maid:clean()
	onDecided(choice)
end

function DecisionService.Start()
	RemoteService.listen(
		Names.DecisionSubmit,
		{ capacity = 3, perSecond = 1 },
		function(player: Player, rawAnomaly: any, rawEnding: any)
			if not isOpen or decided ~= nil or not sessions[player] then
				return
			end
			if type(rawAnomaly) ~= "string" or (rawEnding ~= "Transmit" and rawEnding ~= "Abort") then
				return
			end
			if rawAnomaly ~= UNSURE and Anomalies.ById[rawAnomaly] == nil then
				return
			end
			local console = transmitter
			local allowed = InteractionService.checkGate(player)
			if
				not allowed
				or console == nil
				or not InteractionService.isWithinReach(player, console, config.SubmitDistance)
			then
				sessions[player] = nil
				RemoteService.fire(player, Names.DecisionClose)
				return
			end
			local classification: Classification = if rawAnomaly == UNSURE
				then "None"
				elseif rawAnomaly == anomalyId then "Correct"
				else "Incorrect"
			decide({
				classification = classification,
				classifiedAs = if rawAnomaly == UNSURE then nil else rawAnomaly,
				ending = rawEnding,
				byName = player.DisplayName,
			})
		end
	)
end

function DecisionService.open(params: OpenParams)
	DecisionService.reset()
	anomalyId = params.anomalyId
	onDecided = params.onDecided
	isOpen = true

	local console: BasePart? = MapService.getTagged(Tags.RadioConsole)[1]
	if console == nil then
		Log.warn("Decision", "No %s on the map; aborting automatically", Tags.RadioConsole)
		local fallback: Choice =
			{ classification = "None", classifiedAs = nil, ending = "Abort", byName = "Station" }
		task.defer(decide, fallback)
		return
	end
	transmitter = console
	local prompt = InteractionService.createPrompt(console, {
		ActionText = "Use transmitter",
		ObjectText = "Relay Transmitter",
		MaxDistance = config.InteractDistance,
	}, function(player: Player)
		if decided ~= nil then
			return
		end
		sessions[player] = true
		RemoteService.fire(player, Names.DecisionOpen, options())
	end)
	maid:give(prompt)
end

function DecisionService.getTransmitter(): BasePart?
	return transmitter
end

function DecisionService.getChoice(): Choice?
	return decided
end

function DecisionService.reset()
	isOpen = false
	decided = nil
	transmitter = nil
	closeAll()
	maid:clean()
	onDecided = function(_choice: Choice) end
end

return DecisionService
