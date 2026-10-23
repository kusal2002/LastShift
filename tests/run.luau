-- Runs every spec. Usage: lune run tests/run
local process = require("@lune/process")

local H = require("./logic_spec")

if not H.summary() then
	process.exit(1)
end
