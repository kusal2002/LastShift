-- Tiny test runner for Lune. Run all tests with: lune run tests/run
local Harness = {}

local passed = 0
local failures: { string } = {}

function Harness.test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		table.insert(failures, `{name}: {err}`)
	end
end

function Harness.eq(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(`{message or "values differ"} (got {tostring(actual)}, expected {tostring(expected)})`, 2)
	end
end

function Harness.ok(value: any, message: string?)
	if not value then
		error(message or "expected a truthy value", 2)
	end
end

function Harness.summary(): boolean
	for _, failure in failures do
		print(`FAIL  {failure}`)
	end
	print(`{passed} passed, {#failures} failed`)
	return #failures == 0
end

return Harness
