-- Runs every spec. Usage: lune run tests/run
local process = require("@lune/process")

local H = require("./harness")
require("./logic_spec")
require("./player_spec")
require("./echo_spec")

if not H.summary() then
	process.exit(1)
end
