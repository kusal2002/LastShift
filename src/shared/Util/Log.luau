--!strict
-- Consistent log lines: [Category] message. Debug lines only print in Studio with diagnostics on.
local RunService = game:GetService("RunService")

local DebugConfig = require(script.Parent.Parent.Config.Debug)

local Log = {}

local verbose = DebugConfig.Enabled and RunService:IsStudio()

local function format(category: string, message: string, ...: any): string
	local ok, text = pcall(string.format, message, ...)
	return `[{category}] {if ok then text else message}`
end

function Log.debug(category: string, message: string, ...: any)
	if verbose then
		print(format(category, message, ...))
	end
end

function Log.info(category: string, message: string, ...: any)
	print(format(category, message, ...))
end

function Log.warn(category: string, message: string, ...: any)
	warn(format(category, message, ...))
end

function Log.isVerbose(): boolean
	return verbose
end

return Log
