-- Runs every spec. Usage: lune run tests/run
local process = require("@lune/process")

local H = require("./harness")
require("./logic_spec")
require("./player_spec")
require("./echo_spec")
require("./anomaly_spec")
require("./evidence_spec")
require("./profile_spec")
require("./audit_spec")
require("./map_spec")

if not H.summary() then
	process.exit(1)
end
