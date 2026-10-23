--!strict
-- Random picks that never repeat an item. Pure: the random source is passed in.
local Selection = {}

-- nextInt(a, b) must return a whole number in [a, b].
function Selection.pickN<T>(items: { T }, count: number, nextInt: (number, number) -> number): { T }
	local pool = table.clone(items)
	local result = {}
	for index = 1, math.min(count, #pool) do
		local swap = nextInt(index, #pool)
		pool[index], pool[swap] = pool[swap], pool[index]
		table.insert(result, pool[index])
	end
	return result
end

function Selection.pickOne<T>(items: { T }, nextInt: (number, number) -> number): T?
	if #items == 0 then
		return nil
	end
	return items[nextInt(1, #items)]
end

return Selection
