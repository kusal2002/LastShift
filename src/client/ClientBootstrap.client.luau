--!strict
-- Client entry point. Waits for the game to load, then starts state and UI controllers.
if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Client = script.Parent
local Controllers = Client.Controllers
local State = require(Client.State)

local controllers: { any } = {
	require(Controllers.HUDController),
	require(Controllers.LobbyController),
	require(Controllers.BriefingController),
	require(Controllers.CalibrationController),
	require(Controllers.ResultsController),
	require(Controllers.InputController),
	require(Controllers.DownedController),
	require(Controllers.SpectateController),
	require(Controllers.AudioController),
	require(Controllers.LightingController),
	require(Controllers.DevController), -- does nothing outside Studio
}

for _, controller in controllers do
	controller.start()
end

-- Start listening last so every controller is connected before the first snapshot arrives.
State.start()
