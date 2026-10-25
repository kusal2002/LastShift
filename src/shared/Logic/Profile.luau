--!strict
-- The saved player profile: schema, migration, validation, session-lock decisions, and every
-- change gameplay is allowed to make. Pure: no Roblox APIs, so all of it is unit-tested.
-- ProfileService (server) is the only caller and the only code that touches DataStores.

export type Lock = { jobId: string, at: number }

export type AnomalyRecord = { encounters: number, identified: number }

export type Data = {
	version: number,
	credits: number,
	xp: number,
	stats: {
		rounds: number,
		escapes: number,
		transmissions: number,
		correctReports: number,
	},
	casebook: { [string]: boolean }, -- evidence ids unlocked by escaping with them
	anomalies: { [string]: AnomalyRecord },
	owned: { [string]: boolean }, -- cosmetic ids
	equipped: { [string]: string }, -- slot -> cosmetic id
	settings: { [string]: boolean | number },
	lock: Lock?,
}

-- Minimal shapes of the configs this module reads, so it stays testable with plain tables.
export type CosmeticLike = {
	Id: string,
	Slot: string,
	Unlock: { Kind: string, Level: number?, Price: number? },
}
export type Catalog = {
	Items: { CosmeticLike },
	ById: { [string]: CosmeticLike },
	DefaultBySlot: { [string]: string },
}

local Profile = {}

Profile.CurrentVersion = 2

-- Settings that may be saved, with defaults. Anything else a client sends is ignored.
-- A setting's type is its default's type. Numbers are clamped to SettingRanges.
local settingDefaults: { [string]: boolean | number } = {
	Subtitles = true,
	AmbientSubtitles = true,
	ReducedFlashes = false,
	-- Added in v2
	MasterVolume = 1,
	EffectsVolume = 1, -- important cues (enemy, alarms, PA)
	AmbientVolume = 0.8, -- background cues (footsteps, static)
	TextScale = 1, -- UI size multiplier
	-- Added for the bodycam camera. No version bump: missing keys load as these defaults.
	MouseSensitivity = 1,
	FieldOfView = 80,
	CameraMotion = 1, -- 0 turns camera sway off
}
Profile.SettingDefaults = table.freeze(settingDefaults)

local settingRanges: { [string]: { number } } = {
	MasterVolume = { 0, 1 },
	EffectsVolume = { 0, 1 },
	AmbientVolume = { 0, 1 },
	TextScale = { 0.85, 1.3 },
	MouseSensitivity = { 0.2, 2 },
	FieldOfView = { 70, 90 },
	CameraMotion = { 0, 1 },
}
Profile.SettingRanges = table.freeze(settingRanges)

function Profile.new(catalog: Catalog): Data
	local data: Data = {
		version = Profile.CurrentVersion,
		credits = 0,
		xp = 0,
		stats = { rounds = 0, escapes = 0, transmissions = 0, correctReports = 0 },
		casebook = {},
		anomalies = {},
		owned = {},
		equipped = {},
		settings = table.clone(Profile.SettingDefaults) :: any,
		lock = nil,
	}
	Profile.grantDefaults(data, catalog)
	return data
end

-- Upgrades older saves step by step. Add a function here whenever the schema changes and bump
-- CurrentVersion. MIGRATIONS[n] turns a version-n save into version n+1.
local MIGRATIONS: { [number]: (any) -> any } = {
	-- v1 -> v2: volume and text-size settings.
	[1] = function(data: any): any
		if type(data.settings) ~= "table" then
			data.settings = {}
		end
		data.settings.MasterVolume = data.settings.MasterVolume or 1
		data.settings.EffectsVolume = data.settings.EffectsVolume or 1
		data.settings.AmbientVolume = data.settings.AmbientVolume or 0.8
		data.settings.TextScale = data.settings.TextScale or 1
		return data
	end,
}

function Profile.migrate(data: any): any
	if type(data.version) ~= "number" then
		data.version = 1
	end
	while data.version < Profile.CurrentVersion do
		local step = MIGRATIONS[data.version]
		if step == nil then
			error(`missing profile migration from v{data.version}`)
		end
		data = step(data)
		data.version += 1
	end
	return data
end

local function nonNegative(value: any): number
	if type(value) ~= "number" or value ~= value or value == math.huge then
		return 0
	end
	return math.max(0, math.floor(value))
end

local function boolSet(value: any): { [string]: boolean }
	local result = {}
	if type(value) == "table" then
		for key, flag in value do
			if type(key) == "string" and flag == true then
				result[key] = true
			end
		end
	end
	return result
end

-- Repairs anything malformed in stored data (missing fields, wrong types) without losing
-- valid values. Unknown cosmetics and invalid equips are dropped.
function Profile.sanitize(raw: any, catalog: Catalog): Data
	local data = Profile.new(catalog)
	if type(raw) ~= "table" then
		return data
	end
	data.version = Profile.CurrentVersion
	data.credits = nonNegative(raw.credits)
	data.xp = nonNegative(raw.xp)
	local stats = if type(raw.stats) == "table" then raw.stats else {}
	data.stats = {
		rounds = nonNegative(stats.rounds),
		escapes = nonNegative(stats.escapes),
		transmissions = nonNegative(stats.transmissions),
		correctReports = nonNegative(stats.correctReports),
	}
	data.casebook = boolSet(raw.casebook)
	if type(raw.anomalies) == "table" then
		for id, record in raw.anomalies do
			if type(id) == "string" and type(record) == "table" then
				data.anomalies[id] = {
					encounters = nonNegative(record.encounters),
					identified = nonNegative(record.identified),
				}
			end
		end
	end
	for id in boolSet(raw.owned) do
		if catalog.ById[id] then
			data.owned[id] = true
		end
	end
	Profile.grantDefaults(data, catalog)
	if type(raw.equipped) == "table" then
		for slot, id in raw.equipped do
			if type(slot) == "string" and type(id) == "string" then
				local item = catalog.ById[id]
				if item and item.Slot == slot and data.owned[id] then
					data.equipped[slot] = id
				end
			end
		end
	end
	if type(raw.settings) == "table" then
		for key in Profile.SettingDefaults do
			Profile.setSetting(data, key, raw.settings[key])
		end
	end
	if type(raw.lock) == "table" and type(raw.lock.jobId) == "string" and type(raw.lock.at) == "number" then
		data.lock = { jobId = raw.lock.jobId, at = raw.lock.at }
	end
	return data
end

-- Everyone owns default cosmetics; empty slots get their default equipped.
function Profile.grantDefaults(data: Data, catalog: Catalog)
	for slot, id in catalog.DefaultBySlot do
		data.owned[id] = true
		if data.equipped[slot] == nil then
			data.equipped[slot] = id
		end
	end
end

-- Session locking ------------------------------------------------------------

export type ClaimStatus = "Claimed" | "Locked"

-- May this server take the profile? Free, our own, or stale locks can be taken.
function Profile.canClaim(lock: Lock?, jobId: string, now: number, staleSeconds: number): boolean
	if lock == nil then
		return true
	end
	return lock.jobId == jobId or now - lock.at >= staleSeconds
end

-- The UpdateAsync transform used when a player joins. Returns the data to write (or nil to
-- leave the store untouched) and what happened. Never yields.
function Profile.claim(
	stored: any,
	jobId: string,
	now: number,
	staleSeconds: number,
	catalog: Catalog
): (Data?, ClaimStatus)
	local data = if stored == nil
		then Profile.new(catalog)
		else Profile.sanitize(Profile.migrate(stored), catalog)
	if not Profile.canClaim(data.lock, jobId, now, staleSeconds) then
		return nil, "Locked"
	end
	data.lock = { jobId = jobId, at = now }
	return data, "Claimed"
end

-- The UpdateAsync transform used for autosave and release. Writes our in-memory copy unless
-- another server has since taken the lock (then returns nil: never overwrite their data).
function Profile.prepareSave(current: Data, stored: any, jobId: string, now: number, release: boolean): Data?
	if type(stored) == "table" and type(stored.lock) == "table" and stored.lock.jobId ~= jobId then
		return nil
	end
	local copy = Profile.deepCopy(current) :: Data
	copy.lock = if release then nil else { jobId = jobId, at = now }
	return copy
end

function Profile.deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value do
		copy[key] = Profile.deepCopy(inner)
	end
	return copy
end

-- Gameplay changes ------------------------------------------------------------

export type RoundRecord = {
	credits: number,
	xp: number,
	escaped: boolean,
	transmitted: boolean, -- the transmission finished
	anomalyId: string,
	correctReport: boolean,
	evidenceIds: { string }, -- team evidence this round
}

-- Applies a finished round. Evidence enters the casebook only if the player escaped.
-- Returns the evidence ids newly added to the casebook.
function Profile.applyRound(data: Data, record: RoundRecord): { string }
	data.credits += math.max(0, math.floor(record.credits))
	data.xp += math.max(0, math.floor(record.xp))
	data.stats.rounds += 1
	if record.escaped then
		data.stats.escapes += 1
	end
	if record.transmitted then
		data.stats.transmissions += 1
	end
	if record.correctReport then
		data.stats.correctReports += 1
	end
	local anomaly = data.anomalies[record.anomalyId] or { encounters = 0, identified = 0 }
	anomaly.encounters += 1
	if record.correctReport then
		anomaly.identified += 1
	end
	data.anomalies[record.anomalyId] = anomaly

	local added = {}
	if record.escaped then
		for _, id in record.evidenceIds do
			if not data.casebook[id] then
				data.casebook[id] = true
				table.insert(added, id)
			end
		end
	end
	return added
end

-- Grants level-unlocked cosmetics up to `level`. Returns newly unlocked ids.
function Profile.grantLevelUnlocks(data: Data, level: number, catalog: Catalog): { string }
	local unlocked = {}
	for _, item in catalog.Items do
		local required = item.Unlock.Level
		if
			item.Unlock.Kind == "Level"
			and required ~= nil
			and level >= required
			and not data.owned[item.Id]
		then
			data.owned[item.Id] = true
			table.insert(unlocked, item.Id)
		end
	end
	return unlocked
end

export type PurchaseResult = "Bought" | "Unknown" | "Owned" | "NotForSale" | "TooPoor"

function Profile.buyWithCredits(data: Data, id: string, catalog: Catalog): PurchaseResult
	local item = catalog.ById[id]
	if item == nil then
		return "Unknown"
	end
	if data.owned[id] then
		return "Owned"
	end
	local price = item.Unlock.Price
	if item.Unlock.Kind ~= "Credits" or price == nil then
		return "NotForSale"
	end
	if data.credits < price then
		return "TooPoor"
	end
	data.credits -= price
	data.owned[id] = true
	return "Bought"
end

function Profile.equip(data: Data, slot: string, id: string, catalog: Catalog): boolean
	local item = catalog.ById[id]
	if item == nil or item.Slot ~= slot or not data.owned[id] then
		return false
	end
	data.equipped[slot] = id
	return true
end

-- Only known settings of the right type are stored. Numbers are clamped and rounded to 0.05.
function Profile.setSetting(data: Data, key: string, value: any): boolean
	local default = Profile.SettingDefaults[key]
	if default == nil or type(value) ~= type(default) then
		return false
	end
	if type(value) == "number" then
		if value ~= value then
			return false
		end
		local range = Profile.SettingRanges[key]
		local low = if range then range[1] else 0
		local high = if range then range[2] else 1
		value = math.round(math.clamp(value, low, high) * 20) / 20
	end
	data.settings[key] = value
	return true
end

return Profile
