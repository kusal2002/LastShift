--!strict
-- Objective B: tune the radio console to the target frequency posted on the frequency board.
-- The target is chosen and checked on the server. Wrong answers count toward an overload
-- that locks the console for a few seconds (never permanently).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.Objectives).Calibration
local Tags = require(Shared.Config.Tags)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Calibration = require(Shared.Logic.Calibration)
local Selection = require(Shared.Logic.Selection)
local Maid = require(Shared.Util.Maid)
local Log = require(Shared.Util.Log)

local Services = script.Parent.Parent.Services
local MapService = require(Services.MapService)
local InteractionService = require(Services.InteractionService)
local RemoteService = require(Services.RemoteService)
local NoiseService = require(Services.NoiseService)
local EnemyConfig = require(Shared.Config.Enemy)
local ObjectiveTypes = require(script.Parent.ObjectiveTypes)

local Names = Remotes.Names
local ID = "calibration"
local LABEL = "Tune the relay frequency"
local DISPLAY_NAME = "FrequencyDisplay"
local LOCKED_COLOR = Color3.fromRGB(60, 120, 80)

local CalibrationObjective = {}

-- The board's text label, created if a hand-built board lacks one.
local function ensureDisplay(board: BasePart): TextLabel
	local existing = board:FindFirstChild(DISPLAY_NAME)
	if existing and existing:IsA("SurfaceGui") then
		local label = existing:FindFirstChildOfClass("TextLabel")
		if label then
			return label
		end
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = DISPLAY_NAME
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(8, 14, 10)
	label.TextColor3 = Color3.fromRGB(126, 205, 140)
	label.Font = Enum.Font.RobotoMono
	label.TextScaled = true
	label.Parent = gui
	gui.Parent = board
	return label
end

function CalibrationObjective.new(ctx: ObjectiveTypes.Context): ObjectiveTypes.Objective
	local foundConsole = Selection.pickOne(MapService.getTagged(Tags.RadioConsole), ctx.nextInt)
	local foundBoard = Selection.pickOne(MapService.getTagged(Tags.FrequencyBoard), ctx.nextInt)
	if foundConsole == nil or foundBoard == nil then
		Log.warn(
			"Objective",
			"Calibration skipped: map needs %s and %s parts",
			Tags.RadioConsole,
			Tags.FrequencyBoard
		)
		return ObjectiveTypes.skipped(ID, "Calibration", LABEL)
	end
	local console: BasePart = foundConsole
	local board: BasePart = foundBoard

	local maid = Maid.new()
	local target =
		Calibration.randomTarget(ctx.nextInt, Config.MinFrequency, Config.MaxFrequency, Config.Step)
	local complete = false
	local mistakes = 0
	local lockedUntil = 0
	local sessions: { [Player]: boolean } = {} -- players with the tuning UI open
	local originalConsoleColor = console.Color

	local display = ensureDisplay(board)
	display.Text = `RELAY K-7\nTARGET {Calibration.format(target)}`
	Log.debug("Objective", "Calibration target %s", Calibration.format(target))

	local function params(): Types.CalibrationParams
		return {
			Min = Config.MinFrequency,
			Max = Config.MaxFrequency,
			Step = Config.Step,
			AttemptsLeft = Config.MaxMistakes - mistakes,
		}
	end

	local function close(player: Player)
		sessions[player] = nil
		if player.Parent ~= nil then
			RemoteService.fire(player, Names.CalibrationClose)
		end
	end

	local function closeAll()
		for player in table.clone(sessions) do
			close(player)
		end
	end

	local prompt: ProximityPrompt
	prompt = InteractionService.createPrompt(console, {
		ActionText = "Tune",
		ObjectText = "Radio Console",
		MaxDistance = Config.InteractDistance,
	}, function(player: Player)
		if complete then
			return
		end
		if os.clock() < lockedUntil then
			ctx.notify(player, "The console is overloaded. Give it a moment.", "warn")
			return
		end
		sessions[player] = true
		RemoteService.fire(player, Names.CalibrationOpen, params())
	end)
	maid:give(prompt)

	maid:give(
		RemoteService.listen(
			Names.CalibrationSubmit,
			{ capacity = 3, perSecond = 1 },
			function(player: Player, value: any)
				if not sessions[player] then
					return
				end
				local allowed = InteractionService.checkGate(player)
				if
					complete
					or not allowed
					or not InteractionService.isWithinReach(player, console, Config.SubmitDistance)
				then
					close(player)
					return
				end
				if not Calibration.isValidInput(value, Config.MinFrequency, Config.MaxFrequency) then
					return
				end
				if os.clock() < lockedUntil then
					close(player)
					return
				end

				if Calibration.isMatch(value, target, Config.Step) then
					complete = true
					prompt.Enabled = false
					console.Color = LOCKED_COLOR
					display.Text = `SIGNAL LOCKED\n{Calibration.format(target)}`
					closeAll()
					ctx.notify(player, `Signal locked at {Calibration.format(target)}.`, "success")
					ctx.markChanged()
					return
				end

				-- Wrong frequency: a burst of loud static the Echo can hear.
				mistakes += 1
				NoiseService.emit(console.Position, EnemyConfig.Noise.FailedCalibration, "FailedCalibration")
				if mistakes >= Config.MaxMistakes then
					mistakes = 0
					lockedUntil = os.clock() + Config.LockoutSeconds
					closeAll()
					ctx.notify(
						player,
						`Feedback surge! The console is locked for {Config.LockoutSeconds} seconds.`,
						"danger"
					)
				else
					ctx.notify(player, "Static. That isn't the frequency.", "warn")
					RemoteService.fire(player, Names.CalibrationOpen, params())
				end
			end
		)
	)

	maid:give(
		RemoteService.listen(
			Names.CalibrationCancel,
			{ capacity = 4, perSecond = 2 },
			function(player: Player)
				sessions[player] = nil
			end
		)
	)

	return {
		Id = ID,
		getView = function(): Types.ObjectiveView
			return {
				Id = ID,
				Kind = "Calibration",
				Label = LABEL,
				Detail = if complete then "Signal locked" else "Find the posted target frequency",
				Complete = complete,
			}
		end,
		isComplete = function()
			return complete
		end,
		onPlayerRemoved = function(player: Player)
			if sessions[player] then
				close(player)
			end
		end,
		destroy = function()
			closeAll()
			maid:clean()
			console.Color = originalConsoleColor
			display.Text = "NO SIGNAL"
		end,
	}
end

return CalibrationObjective
