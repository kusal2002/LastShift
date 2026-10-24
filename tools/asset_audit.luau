-- Audits every model in assets/raw and writes cleaned copies to assets/props.
--
-- Usage:
--   lune run tools/asset_audit                 audit assets/raw, write cleaned models
--   lune run tools/asset_audit --report-only   audit without writing anything
--   lune run tools/asset_audit <in> <out>      custom folders
--
-- Rejected models (backdoor patterns) are never written. A report is saved to
-- build/asset_audit_report.md. Exit code 1 if anything was rejected.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local AssetAudit = require("./AssetAudit")

local reportOnly = false
local positional = {}
for _, arg in process.args do
	if arg == "--report-only" then
		reportOnly = true
	else
		table.insert(positional, arg)
	end
end
local inputDir = positional[1] or "assets/raw"
local outputDir = positional[2] or "assets/props"

local function collect(dir: string, relative: string, out: { { full: string, relative: string } })
	for _, name in fs.readDir(dir) do
		local full = `{dir}/{name}`
		local rel = if relative == "" then name else `{relative}/{name}`
		if fs.isDir(full) then
			collect(full, rel, out)
		elseif string.match(name, "%.rbxmx?$") then
			table.insert(out, { full = full, relative = rel })
		end
	end
end

if not fs.isDir(inputDir) then
	print(`No input folder {inputDir}`)
	process.exit(1)
end

local files = {}
collect(inputDir, "", files)
table.sort(files, function(a, b)
	return a.relative < b.relative
end)
if #files == 0 then
	print(`No .rbxm / .rbxmx files in {inputDir}. Save models there from Studio first.`)
	process.exit(0)
end

local lines = {
	"# Asset audit report",
	"",
	`Input: {inputDir} · Output: {if reportOnly then "(report only)" else outputDir}`,
	"",
}
local rejected = 0

for _, file in files do
	local ok, roots = pcall(roblox.deserializeModel, fs.readFile(file.full))
	if not ok then
		print(`ERROR   {file.relative}: could not read ({roots})`)
		table.insert(lines, `## {file.relative}\n\nCould not read: {roots}\n`)
		rejected += 1
		continue
	end
	local report = AssetAudit.analyze(roots)
	local summary =
		`{report.parts} parts ({report.meshParts} mesh, {report.unions} union), {#report.scripts} scripts, {#report.remotes} remotes, {report.sounds} sounds, {report.textures} textures`
	print(`{string.upper(report.verdict)}  {file.relative}: {summary}`)

	table.insert(lines, `## {file.relative}: {report.verdict}`)
	table.insert(lines, "")
	table.insert(lines, `- {summary}`)
	for _, finding in report.suspicious do
		table.insert(lines, `- **SUSPICIOUS** {finding.path}: {finding.reason}`)
		print(`        suspicious: {finding.path}: {finding.reason}`)
	end
	for _, finding in report.scripts do
		table.insert(lines, `- script {finding.path} ({finding.reason})`)
	end
	for _, finding in report.remotes do
		table.insert(lines, `- remote {finding.path} ({finding.reason})`)
	end
	for _, warning in report.warnings do
		table.insert(lines, `- warning: {warning}`)
		print(`        warning: {warning}`)
	end

	if report.verdict == "Rejected" then
		rejected += 1
		table.insert(lines, "- Not written. Delete it and mark it Rejected in ASSET_CATALOG.md.")
	elseif not reportOnly then
		local removed = AssetAudit.clean(roots)
		local target = `{outputDir}/{string.gsub(file.relative, "%.rbxmx$", ".rbxm")}`
		local folder = string.match(target, "^(.*)/[^/]+$")
		if folder and not fs.isDir(folder) then
			fs.writeDir(folder)
		end
		fs.writeFile(target, roblox.serializeModel(roots))
		table.insert(lines, `- Cleaned ({removed} instances removed, all parts anchored) -> {target}`)
	end
	table.insert(lines, "")
end

if not fs.isDir("build") then
	fs.writeDir("build")
end
fs.writeFile("build/asset_audit_report.md", table.concat(lines, "\n"))
print(`\n{#files} file(s) audited, {rejected} rejected. Report: build/asset_audit_report.md`)
if rejected > 0 then
	process.exit(1)
end
