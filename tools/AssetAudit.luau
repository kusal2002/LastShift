-- Offline safety and quality audit for Roblox model files (run with Lune, not in Roblox).
-- analyze() reports what a model contains; clean() strips everything a decorative prop should
-- not have. Used by tools/asset_audit.luau and unit-tested in tests/audit_spec.luau.

export type Finding = { path: string, reason: string }

export type Report = {
	scripts: { Finding },
	remotes: { Finding },
	sounds: number,
	parts: number,
	meshParts: number,
	unions: number,
	unanchored: number,
	textures: number,
	suspicious: { Finding },
	warnings: { string },
	verdict: "Clean" | "NeedsCleaning" | "Rejected",
}

local AssetAudit = {}

AssetAudit.PartWarning = 500 -- parts in one prop before we warn about cost

-- Patterns seen in backdoored free models. Any hit rejects the whole asset: even after
-- stripping, its creator is not trustworthy.
AssetAudit.SuspiciousPatterns = {
	{ pattern = "require%s*%(%s*%d+", reason = "requires a module by asset id (classic backdoor)" },
	{ pattern = "getfenv", reason = "uses getfenv" },
	{ pattern = "setfenv", reason = "uses setfenv" },
	{ pattern = "loadstring", reason = "uses loadstring" },
	{ pattern = "HttpService", reason = "uses HttpService" },
	{ pattern = "TeleportService", reason = "uses TeleportService" },
	{ pattern = "MarketplaceService", reason = "uses MarketplaceService" },
	{ pattern = "InsertService", reason = "uses InsertService" },
	{ pattern = "string%.reverse", reason = "string reversal (common obfuscation)" },
	{ pattern = "\\%d%d%d?\\%d%d%d?\\%d%d%d?\\%d%d%d?", reason = "escaped byte strings (obfuscation)" },
}

-- Classes a decorative prop never needs. clean() removes them.
AssetAudit.StrippedClasses = {
	"LuaSourceContainer", -- Script, LocalScript, ModuleScript
	"RemoteEvent",
	"RemoteFunction",
	"UnreliableRemoteEvent",
	"BindableEvent",
	"BindableFunction",
	"Sound",
	"ClickDetector",
	"ProximityPrompt",
	"Tool",
}

local function pathOf(instance: any, root: any): string
	local names = {}
	local current = instance
	while current and current ~= root.Parent do
		table.insert(names, 1, current.Name)
		current = current.Parent
	end
	return table.concat(names, ".")
end

local function longestLine(source: string): number
	local longest = 0
	for line in string.gmatch(source, "[^\n]+") do
		longest = math.max(longest, #line)
	end
	return longest
end

function AssetAudit.scanSource(source: string): { string }
	local reasons = {}
	for _, rule in AssetAudit.SuspiciousPatterns do
		if string.find(source, rule.pattern) then
			table.insert(reasons, rule.reason)
		end
	end
	if longestLine(source) > 2000 then
		table.insert(reasons, "very long line (likely obfuscated)")
	end
	return reasons
end

function AssetAudit.analyze(roots: { any }): Report
	local report: Report = {
		scripts = {},
		remotes = {},
		sounds = 0,
		parts = 0,
		meshParts = 0,
		unions = 0,
		unanchored = 0,
		textures = 0,
		suspicious = {},
		warnings = {},
		verdict = "Clean",
	}
	for _, root in roots do
		local all = root:GetDescendants()
		table.insert(all, 1, root)
		for _, instance in all do
			local path = pathOf(instance, root)
			if instance:IsA("LuaSourceContainer") then
				table.insert(report.scripts, { path = path, reason = instance.ClassName })
				local ok, source = pcall(function()
					return instance.Source
				end)
				if ok and type(source) == "string" then
					for _, reason in AssetAudit.scanSource(source) do
						table.insert(report.suspicious, { path = path, reason = reason })
					end
				end
			elseif
				instance:IsA("RemoteEvent")
				or instance:IsA("RemoteFunction")
				or instance.ClassName == "UnreliableRemoteEvent"
			then
				table.insert(report.remotes, { path = path, reason = instance.ClassName })
			elseif instance:IsA("Sound") then
				report.sounds += 1
			elseif
				instance:IsA("Decal")
				or instance:IsA("Texture")
				or instance.ClassName == "SurfaceAppearance"
			then
				report.textures += 1
			end
			if instance:IsA("BasePart") then
				report.parts += 1
				if instance:IsA("MeshPart") then
					report.meshParts += 1
				elseif instance:IsA("UnionOperation") then
					report.unions += 1
				end
				if not instance.Anchored then
					report.unanchored += 1
				end
			end
		end
	end
	if report.parts > AssetAudit.PartWarning then
		table.insert(report.warnings, `{report.parts} parts: heavy for a prop, simplify in Studio`)
	end
	if report.parts == 0 then
		table.insert(report.warnings, "no visible parts")
	end
	if #report.suspicious > 0 then
		report.verdict = "Rejected"
	elseif #report.scripts > 0 or #report.remotes > 0 or report.sounds > 0 or report.unanchored > 0 then
		report.verdict = "NeedsCleaning"
	end
	return report
end

-- Removes scripts and other non-visual instances, anchors every part, and turns off touch
-- events. Small parts stop casting shadows (cheaper on mobile). Returns how many were removed.
function AssetAudit.clean(roots: { any }): number
	local removed = 0
	for _, root in roots do
		local toRemove = {}
		for _, instance in root:GetDescendants() do
			for _, class in AssetAudit.StrippedClasses do
				if instance:IsA(class) then
					table.insert(toRemove, instance)
					break
				end
			end
		end
		for _, instance in toRemove do
			if instance.Parent ~= nil then
				instance:Destroy()
				removed += 1
			end
		end
		local all = root:GetDescendants()
		table.insert(all, 1, root)
		for _, instance in all do
			if instance:IsA("BasePart") then
				instance.Anchored = true
				instance.CanTouch = false
				local size = instance.Size
				if math.max(size.X, size.Y, size.Z) < 2 then
					instance.CastShadow = false
				end
			end
		end
	end
	return removed
end

return AssetAudit
