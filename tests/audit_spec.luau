-- Tests for the offline asset audit (tools/AssetAudit.luau).
local H = require("./harness")
local roblox = require("@lune/roblox")
local AssetAudit = require("../tools/AssetAudit")

local Instance = roblox.Instance
local Vector3 = roblox.Vector3

local function prop(): any
	local model = Instance.new("Model")
	model.Name = "Desk"
	local top = Instance.new("Part")
	top.Name = "Top"
	top.Anchored = true
	top.Parent = model
	return model
end

H.test("a plain anchored prop is clean", function()
	local report = AssetAudit.analyze({ prop() })
	H.eq(report.verdict, "Clean")
	H.eq(report.parts, 1)
end)

H.test("harmless scripts, sounds and loose parts need cleaning", function()
	local model = prop()
	local script = Instance.new("Script")
	script.Source = "print('spin the fan')"
	script.Parent = model
	local sound = Instance.new("Sound")
	sound.Parent = model
	local loose = Instance.new("Part")
	loose.Anchored = false
	loose.Parent = model
	local report = AssetAudit.analyze({ model })
	H.eq(report.verdict, "NeedsCleaning")
	H.eq(#report.scripts, 1)
	H.eq(report.sounds, 1)
	H.eq(report.unanchored, 1)
end)

H.test("backdoor patterns reject the asset", function()
	for _, source in
		{
			"require(4567891230)",
			"local f = getfenv()",
			"loadstring(code)()",
			'game:GetService("HttpService"):GetAsync(url)',
			'local s = string.reverse("kcab")',
			"local x = '\\104\\101\\108\\108'",
		}
	do
		local model = prop()
		local script = Instance.new("Script")
		script.Source = source
		script.Parent = model.Top
		local report = AssetAudit.analyze({ model })
		H.eq(report.verdict, "Rejected", source)
		H.ok(#report.suspicious > 0)
	end
end)

H.test("very long lines count as obfuscation", function()
	H.ok(#AssetAudit.scanSource(string.rep("a", 2500)) > 0)
	H.eq(#AssetAudit.scanSource("print('hello')"), 0)
end)

H.test("remotes are reported", function()
	local model = prop()
	local remote = Instance.new("RemoteEvent")
	remote.Parent = model
	local report = AssetAudit.analyze({ model })
	H.eq(#report.remotes, 1)
	H.eq(report.verdict, "NeedsCleaning")
end)

H.test("clean strips non-visual instances and anchors everything", function()
	local model = prop()
	for _, class in
		{
			"Script",
			"LocalScript",
			"ModuleScript",
			"RemoteEvent",
			"Sound",
			"ClickDetector",
			"ProximityPrompt",
		}
	do
		Instance.new(class).Parent = model.Top
	end
	local loose = Instance.new("Part")
	loose.Anchored = false
	loose.Size = Vector3.new(0.5, 0.5, 0.5)
	loose.Parent = model
	local removed = AssetAudit.clean({ model })
	H.eq(removed, 7)
	local report = AssetAudit.analyze({ model })
	H.eq(report.verdict, "Clean")
	H.eq(loose.Anchored, true)
	H.eq(loose.CanTouch, false)
	H.eq(loose.CastShadow, false, "small parts stop casting shadows")
end)

H.test("cleaned models survive a save and reload", function()
	local model = prop()
	Instance.new("Script").Parent = model
	AssetAudit.clean({ model })
	local reloaded = roblox.deserializeModel(roblox.serializeModel({ model }))
	H.eq(AssetAudit.analyze(reloaded).verdict, "Clean")
end)

return H
