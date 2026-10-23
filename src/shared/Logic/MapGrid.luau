--!strict
-- Reads the text-grid station layout. Pure: no Roblox APIs.
-- '#' is wall; every other character is walkable floor (some also place an object).
-- Grid coordinates are zero-based: row 0 is the first string, col 0 its first character.
export type Marker = { char: string, row: number, col: number }
export type WallRun = { row: number, colStart: number, colEnd: number }

local MapGrid = {}

function MapGrid.charAt(rows: { string }, row: number, col: number): string?
	local line = rows[row + 1]
	if line == nil or col < 0 or col >= #line then
		return nil
	end
	return string.sub(line, col + 1, col + 1)
end

function MapGrid.isWalkable(char: string?): boolean
	return char ~= nil and char ~= "#"
end

-- Horizontal runs of '#' merged into single segments (fewer parts to build).
function MapGrid.wallRuns(rows: { string }): { WallRun }
	local runs = {}
	for rowIndex, line in rows do
		local row = rowIndex - 1
		local start: number? = nil
		-- Walk one past the end so a run touching the right edge is closed.
		for index = 1, #line + 1 do
			local col = index - 1
			local isWall = index <= #line and string.sub(line, index, index) == "#"
			if isWall and start == nil then
				start = col
			elseif not isWall and start ~= nil then
				table.insert(runs, { row = row, colStart = start, colEnd = col - 1 })
				start = nil
			end
		end
	end
	return runs
end

-- Every character that is not plain wall or plain floor.
function MapGrid.markers(rows: { string }): { Marker }
	local result = {}
	for rowIndex, line in rows do
		for col = 0, #line - 1 do
			local char = string.sub(line, col + 1, col + 1)
			if char ~= "#" and char ~= "." then
				table.insert(result, { char = char, row = rowIndex - 1, col = col })
			end
		end
	end
	return result
end

local DIRECTIONS = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }

-- Direction (dRow, dCol) toward the first neighbouring wall; used to mount panels on walls.
function MapGrid.adjacentWall(rows: { string }, row: number, col: number): (number?, number?)
	for _, dir in DIRECTIONS do
		if MapGrid.charAt(rows, row + dir[1], col + dir[2]) == "#" then
			return dir[1], dir[2]
		end
	end
	return nil, nil
end

-- Returns a list of problems; empty means the layout is safe to build.
-- Checks: rectangular grid, solid border, every walkable cell reachable from the first 'S',
-- and wall-mounted markers (mustMount) have a wall beside them.
function MapGrid.validate(rows: { string }, mustMount: { [string]: boolean }?): { string }
	local problems = {}
	local height = #rows
	if height == 0 then
		return { "layout has no rows" }
	end
	local width = #rows[1]
	for rowIndex, line in rows do
		if #line ~= width then
			table.insert(problems, `row {rowIndex - 1} has width {#line}, expected {width}`)
		end
	end
	if #problems > 0 then
		return problems
	end

	for col = 0, width - 1 do
		local top = MapGrid.charAt(rows, 0, col)
		local bottom = MapGrid.charAt(rows, height - 1, col)
		if MapGrid.isWalkable(top) or MapGrid.isWalkable(bottom) then
			table.insert(problems, `border open at column {col}`)
		end
	end
	for row = 0, height - 1 do
		local left = MapGrid.charAt(rows, row, 0)
		local right = MapGrid.charAt(rows, row, width - 1)
		if MapGrid.isWalkable(left) or MapGrid.isWalkable(right) then
			table.insert(problems, `border open at row {row}`)
		end
	end

	-- Flood fill from the first spawn marker.
	local startRow: number? = nil
	local startCol: number? = nil
	for _, marker in MapGrid.markers(rows) do
		if marker.char == "S" then
			startRow, startCol = marker.row, marker.col
			break
		end
	end
	if startRow == nil or startCol == nil then
		table.insert(problems, "no spawn marker 'S'")
		return problems
	end

	local seen: { [number]: boolean } = {}
	local queue: { { number } } = { { startRow, startCol } }
	seen[startRow * width + startCol] = true
	while #queue > 0 do
		local cell = table.remove(queue) :: { number }
		for _, dir in DIRECTIONS do
			local r, c = cell[1] + dir[1], cell[2] + dir[2]
			local key = r * width + c
			if not seen[key] and MapGrid.isWalkable(MapGrid.charAt(rows, r, c)) then
				seen[key] = true
				table.insert(queue, { r, c })
			end
		end
	end
	for row = 0, height - 1 do
		for col = 0, width - 1 do
			local char = MapGrid.charAt(rows, row, col)
			if MapGrid.isWalkable(char) and not seen[row * width + col] then
				table.insert(problems, `cell ({row}, {col}) '{char}' is unreachable from spawn`)
			end
		end
	end

	if mustMount then
		for _, marker in MapGrid.markers(rows) do
			if mustMount[marker.char] and MapGrid.adjacentWall(rows, marker.row, marker.col) == nil then
				table.insert(
					problems,
					`'{marker.char}' at ({marker.row}, {marker.col}) has no wall to mount on`
				)
			end
		end
	end
	return problems
end

return MapGrid
