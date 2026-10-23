--!strict
-- Server entry point. Services are initialised in dependency order, then started.
-- Init: create instances and wire services together. Start: connect events and begin running.
local Services = script.Parent.Services

local ordered: { any } = {
	require(Services.RemoteService),
	require(Services.MapService),
	require(Services.InteractionService),
	require(Services.PlayerStateService),
	require(Services.ChargingService),
	require(Services.ObjectiveService),
	require(Services.ExtractionService),
	require(Services.RoundService),
	require(Services.DevCommandService), -- does nothing outside Studio
}

for _, service in ordered do
	if service.Init then
		service.Init()
	end
end

for _, service in ordered do
	if service.Start then
		service.Start()
	end
end
