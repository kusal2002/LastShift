--!strict
-- Storage backend for player profiles. Two implementations behind one interface:
--   Live: Roblox DataStoreService (always used on live servers).
--   Mock: in-memory table for Studio testing without API access. NOTHING IS SAVED.
-- Only ProfileService uses this. All calls may yield and may throw; callers pcall and retry.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local DataConfig = require(Shared.Config.Data)
local Profile = require(Shared.Logic.Profile)
local Log = require(Shared.Util.Log)

export type Store = {
	isMock: boolean,
	-- Atomic read-modify-write. `transform` receives the stored value (or nil) and returns the
	-- value to store, or nil to leave it unchanged. It must not yield.
	update: (key: string, transform: (stored: any) -> any) -> (),
}

local ProfileStore = {}

local function liveStore(): Store
	local dataStore = DataStoreService:GetDataStore(DataConfig.StoreName)
	return {
		isMock = false,
		update = function(key: string, transform: (any) -> any)
			dataStore:UpdateAsync(key, function(stored: any)
				return transform(stored)
			end)
		end,
	}
end

local function mockStore(): Store
	local values: { [string]: any } = {}
	return {
		isMock = true,
		update = function(key: string, transform: (any) -> any)
			local result = transform(Profile.deepCopy(values[key]))
			if result ~= nil then
				values[key] = Profile.deepCopy(result)
			end
		end,
	}
end

-- Picks the backend. Live servers always get real DataStores.
function ProfileStore.create(): Store
	if not RunService:IsStudio() then
		return liveStore()
	end
	if DataConfig.Mode == "Mock" then
		Log.warn("Data", "Using MOCK persistence (Config/Data.Mode = Mock): progress will NOT be saved")
		return mockStore()
	end
	-- Studio, Auto: use DataStores only if "Enable Studio Access to API Services" is on.
	local ok, err = pcall(function()
		DataStoreService:GetDataStore(DataConfig.StoreName):GetAsync("__studio_probe")
	end)
	if ok then
		Log.info("Data", "Studio has API access: using real DataStores")
		return liveStore()
	end
	Log.warn(
		"Data",
		"Using MOCK persistence in Studio (no API access: %s). Progress will NOT be saved.",
		tostring(err)
	)
	return mockStore()
end

return ProfileStore
