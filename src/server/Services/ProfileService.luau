--!strict
-- The only owner of saved player data.
-- * Load: claims the profile with a session lock (UpdateAsync) so only one server owns it.
--   If another server still holds it, retry; if loading fails, KICK the player rather than let
--   them play on a blank profile that would overwrite their real data.
-- * Gameplay changes the in-memory profile only, through the functions below.
-- * Save: autosave (staggered), on leave (releases the lock), and on server shutdown.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local DataConfig = require(Shared.Config.Data)
local Cosmetics = require(Shared.Config.Cosmetics)
local Evidence = require(Shared.Config.Evidence)
local Anomalies = require(Shared.Config.Anomalies)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Profile = require(Shared.Logic.Profile)
local Progression = require(Shared.Logic.Progression)
local Log = require(Shared.Util.Log)

local ProfileStore = require(script.Parent.Parent.Data.ProfileStore)
local RemoteService = require(script.Parent.RemoteService)
local PlayerStateService = require(script.Parent.PlayerStateService)

local Names = Remotes.Names
-- The catalogue seen through Profile's minimal type.
local catalog = (Cosmetics :: any) :: Profile.Catalog

local ProfileService = {}

local store: ProfileStore.Store
local profiles: { [Player]: Profile.Data } = {}
local saving: { [Player]: boolean } = {}
local nextAutosave: { [Player]: number } = {}

local function keyFor(player: Player): string
	return DataConfig.KeyPrefix .. tostring(player.UserId)
end

local function jobId(): string
	-- Empty in Studio; still unique enough there because only one server runs.
	return if game.JobId ~= "" then game.JobId else "studio"
end

local function toColor(rgb: { number }?): Color3?
	if rgb == nil then
		return nil
	end
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function buildView(data: Profile.Data): Types.ProfileView
	local info = Progression.levelFor(data.xp)
	local owned = {}
	for id in data.owned do
		table.insert(owned, id)
	end
	table.sort(owned)
	local casebook: { Types.CasebookEntry } = {}
	for _, item in Evidence.Items do
		if data.casebook[item.Id] then
			local anomaly = Anomalies.ById[item.Anomaly]
			table.insert(casebook, {
				Id = item.Id,
				DisplayName = item.DisplayName,
				Description = item.Description,
				Category = item.Category :: string,
				AnomalyName = if anomaly then anomaly.DisplayName else item.Anomaly,
			})
		end
	end
	local anomalies: { Types.AnomalyRecordView } = {}
	for _, profile in Anomalies.List do
		local record = data.anomalies[profile.Id]
		table.insert(anomalies, {
			Id = profile.Id,
			DisplayName = profile.DisplayName,
			Encounters = if record then record.encounters else 0,
			Identified = if record then record.identified else 0,
		})
	end
	return {
		Persistent = not store.isMock,
		Credits = data.credits,
		XP = data.xp,
		Level = info.level,
		IntoLevel = info.intoLevel,
		ToNext = info.toNext,
		Owned = owned,
		Equipped = table.clone(data.equipped),
		Casebook = casebook,
		EvidenceTotal = #Evidence.Items,
		Anomalies = anomalies,
		Settings = table.clone(data.settings),
		Stats = {
			Rounds = data.stats.rounds,
			Escapes = data.stats.escapes,
			Transmissions = data.stats.transmissions,
			CorrectReports = data.stats.correctReports,
		},
	}
end

-- Sends the profile to its owner and applies cosmetic effects.
local function push(player: Player)
	local data = profiles[player]
	if data == nil then
		return
	end
	player:SetAttribute("Level", Progression.levelFor(data.xp).level)
	local skin = Cosmetics.ById[data.equipped.Flashlight or ""]
	local color = toColor(skin and skin.Color)
	if color then
		PlayerStateService.setFlashlightColor(player, color)
	end
	RemoteService.fire(player, Names.ProfileUpdate, buildView(data))
end

local function save(player: Player, release: boolean): boolean
	local data = profiles[player]
	if data == nil then
		return true
	end
	-- One save at a time per player.
	local waited = 0
	while saving[player] and waited < 15 do
		waited += task.wait(0.1)
	end
	saving[player] = true
	local key = keyFor(player)
	local lostLock = false
	local delaySeconds = 1
	local ok = false
	for attempt = 1, DataConfig.SaveAttempts do
		local success, err = pcall(function()
			store.update(key, function(stored: any): any
				local prepared = Profile.prepareSave(data, stored, jobId(), os.time(), release)
				lostLock = prepared == nil
				return prepared
			end)
		end)
		if success then
			ok = true
			break
		end
		Log.warn(
			"Data",
			"Save %d/%d for %s failed: %s",
			attempt,
			DataConfig.SaveAttempts,
			player.Name,
			tostring(err)
		)
		if attempt < DataConfig.SaveAttempts then
			task.wait(delaySeconds)
			delaySeconds = math.min(delaySeconds * 2, 16)
		end
	end
	saving[player] = nil
	if lostLock then
		Log.warn(
			"Data",
			"%s's profile is now owned by another server; this server will not overwrite it",
			player.Name
		)
		return false
	end
	if ok then
		Log.debug("Data", "Saved %s%s", player.Name, if release then " (released)" else "")
	end
	return ok
end

local function load(player: Player)
	local key = keyFor(player)
	local lastStatus: Profile.ClaimStatus | "Error" = "Error"
	for attempt = 1, DataConfig.LoadAttempts do
		if player.Parent ~= Players then
			return
		end
		local status: string? = nil
		local claimed: Profile.Data? = nil
		local ok, err = pcall(function()
			store.update(key, function(stored: any): any
				-- UpdateAsync may run this more than once; the last run is the one that counts.
				local data, result =
					Profile.claim(stored, jobId(), os.time(), DataConfig.LockStaleSeconds, catalog)
				status = result
				claimed = data
				return data
			end)
		end)
		local data = claimed
		if ok and status == "Claimed" and data ~= nil then
			profiles[player] = data
			if player.Parent ~= Players then
				-- Left while loading: hand the profile straight back.
				save(player, true)
				profiles[player] = nil
				return
			end
			-- Catch up level unlocks (e.g. new level rewards added since their last session).
			Profile.grantLevelUnlocks(data, Progression.levelFor(data.xp).level, catalog)
			nextAutosave[player] = os.clock()
				+ DataConfig.AutosaveSeconds
				+ (player.UserId % DataConfig.AutosaveSeconds)
			push(player)
			Log.info("Data", "Loaded %s (%s)", player.Name, if store.isMock then "mock" else "DataStore")
			return
		end
		lastStatus = if ok then "Locked" else "Error"
		if ok then
			Log.info(
				"Data",
				"%s's profile is locked by another server; retrying (%d/%d)",
				player.Name,
				attempt,
				DataConfig.LoadAttempts
			)
		else
			Log.warn(
				"Data",
				"Load %d/%d for %s failed: %s",
				attempt,
				DataConfig.LoadAttempts,
				player.Name,
				tostring(err)
			)
		end
		if attempt < DataConfig.LoadAttempts then
			task.wait(math.min(2 ^ (attempt - 1), 8))
		end
	end
	if player.Parent == Players then
		player:Kick(
			if lastStatus == "Locked"
				then "Your progress from your last session is still saving. Please rejoin in a moment."
				else "We couldn't load your progress right now. Nothing was lost; please rejoin."
		)
	end
end

local function onPlayerRemoving(player: Player)
	nextAutosave[player] = nil
	if profiles[player] then
		save(player, true)
		profiles[player] = nil
	end
end

function ProfileService.Init()
	store = ProfileStore.create()
end

function ProfileService.Start()
	Players.PlayerAdded:Connect(function(player: Player)
		load(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Autosave clock (server lifetime). Each player's save time is staggered by user id.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < 1 then
			return
		end
		accumulator = 0
		local now = os.clock()
		for player, due in nextAutosave do
			if now >= due and profiles[player] and not saving[player] then
				nextAutosave[player] = now + DataConfig.AutosaveSeconds
				task.spawn(save, player, false)
			end
		end
	end)

	-- Server shutdown: save and release everyone in parallel, then wait (briefly in Studio mock).
	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				save(player, true)
				pending -= 1
			end)
		end
		local limit = if RunService:IsStudio() and store.isMock then 1 else DataConfig.ShutdownWaitSeconds
		local deadline = os.clock() + limit
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	RemoteService.listen(
		Names.EquipCosmetic,
		{ capacity = 5, perSecond = 2 },
		function(player: Player, slot: any, id: any)
			local data = profiles[player]
			if data == nil or type(slot) ~= "string" or type(id) ~= "string" then
				return
			end
			if Profile.equip(data, slot, id, catalog) then
				push(player)
			end
		end
	)

	RemoteService.listen(Names.BuyCosmetic, { capacity = 3, perSecond = 1 }, function(player: Player, id: any)
		local data = profiles[player]
		if data == nil or type(id) ~= "string" then
			return
		end
		local result = Profile.buyWithCredits(data, id, catalog)
		local item = Cosmetics.ById[id]
		if result == "Bought" and item then
			RemoteService.notify(player, `Unlocked {item.DisplayName}.`, "success")
			push(player)
		elseif result == "TooPoor" then
			RemoteService.notify(player, "Not enough credits.", "warn")
		end
	end)

	RemoteService.listen(
		Names.SaveSetting,
		{ capacity = 10, perSecond = 3 },
		function(player: Player, key: any, value: any)
			local data = profiles[player]
			if data == nil or type(key) ~= "string" then
				return
			end
			Profile.setSetting(data, key, value)
		end
	)
end

function ProfileService.isLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- Applies a finished round to the player's saved progress. Saved with the next autosave or
-- when they leave. Announces level-ups, unlocks and new casebook entries.
function ProfileService.applyRound(player: Player, record: Profile.RoundRecord)
	local data = profiles[player]
	if data == nil then
		Log.warn("Data", "No profile for %s; round result not saved", player.Name)
		return
	end
	local before = Progression.levelFor(data.xp).level
	local added = Profile.applyRound(data, record)
	local after = Progression.levelFor(data.xp).level
	if after > before then
		RemoteService.notify(player, `Level up! You are now level {after}.`, "success")
		for _, id in Profile.grantLevelUnlocks(data, after, catalog) do
			local item = Cosmetics.ById[id]
			if item then
				RemoteService.notify(player, `Unlocked {item.DisplayName}.`, "success")
			end
		end
	end
	if #added > 0 then
		RemoteService.notify(
			player,
			`{#added} new casebook entr{if #added == 1 then "y" else "ies"}.`,
			"info"
		)
	end
	push(player)
end

return ProfileService
