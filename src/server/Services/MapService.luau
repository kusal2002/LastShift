--!strict
-- Builds the graybox lobby and station from StationLayout, unless hand-built "Station" /
-- "Lobby" models already exist in Workspace. Gameplay code finds objects by tag, so a
-- hand-built map works as long as it uses the same tags (see Config/Tags).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Tags = require(Shared.Config.Tags)
local MapGrid = require(Shared.Logic.MapGrid)
local Log = require(Shared.Util.Log)
local Layout = require(script.Parent.Parent.Map.StationLayout)

local MapService = {}

local COLORS = {
	Wall = Color3.fromRGB(86, 90, 96),
	Floor = Color3.fromRGB(54, 56, 60),
	Ceiling = Color3.fromRGB(38, 40, 44),
	Door = Color3.fromRGB(118, 42, 36),
	Panel = Color3.fromRGB(70, 74, 64),
	Console = Color3.fromRGB(52, 58, 56),
	Screen = Color3.fromRGB(40, 90, 60),
	Crate = Color3.fromRGB(92, 78, 58),
	Board = Color3.fromRGB(26, 30, 28),
	WarmLight = Color3.fromRGB(255, 178, 102),
	ColdLight = Color3.fromRGB(150, 178, 220),
	Zone = Color3.fromRGB(96, 200, 124),
	Pad = Color3.fromRGB(70, 78, 66),
}

local station: Model
local lobby: Model
local roundFolder: Folder

type PartProps = {
	Name: string,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Parent: Instance,
	Material: Enum.Material?,
	CanCollide: boolean?,
	Transparency: number?,
}

local function makePart(props: PartProps): Part
	local part = Instance.new("Part")
	part.Name = props.Name
	part.Anchored = true
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Color = props.Color
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.CanCollide = if props.CanCollide == nil then true else props.CanCollide
	part.Transparency = props.Transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = props.Parent
	return part
end

-- Invisible, non-interactive point used to place things.
local function makeMarker(name: string, cframe: CFrame, tag: string, parent: Instance): Part
	local marker = makePart({
		Name = name,
		Size = Vector3.new(1, 1, 1),
		CFrame = cframe,
		Color = COLORS.Zone,
		Parent = parent,
		CanCollide = false,
		Transparency = 1,
	})
	marker.CanQuery = false
	marker.CanTouch = false
	CollectionService:AddTag(marker, tag)
	return marker
end

local function makeSign(part: BasePart, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.RobotoMono
	label.Text = text
	label.Parent = gui
	gui.Parent = part
end

local function addLight(parent: BasePart, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = parent
end

local function cellCenter(row: number, col: number): Vector3
	local size = Layout.CellSize
	return Vector3.new(Layout.Origin.X + col * size, Layout.Origin.Y, Layout.Origin.Z + row * size)
end

-- CFrame for an object flush against the wall next to (row, col), its front face toward the room.
local function mountedCFrame(row: number, col: number, depth: number, height: number): CFrame?
	local dRow, dCol = MapGrid.adjacentWall(Layout.Rows, row, col)
	if dRow == nil or dCol == nil then
		return nil
	end
	local toWall = Vector3.new(dCol, 0, dRow)
	local position = cellCenter(row, col)
		+ toWall * (Layout.CellSize / 2 - depth / 2)
		+ Vector3.new(0, height, 0)
	return CFrame.lookAt(position, position - toWall)
end

local function buildMarker(char: string, row: number, col: number, parent: Model)
	local center = cellCenter(row, col)
	local suffix = `r{row}c{col}`
	local cell = Layout.CellSize
	local height = Layout.WallHeight

	if char == "S" then
		makeMarker(
			`StationSpawn_{suffix}`,
			CFrame.new(center + Vector3.new(0, 3, 0)),
			Tags.StationSpawn,
			parent
		)
	elseif char == "F" then
		makePart({
			Name = `Crate_{suffix}`,
			Size = Vector3.new(3, 3, 3),
			CFrame = CFrame.new(center + Vector3.new(0, 1.5, 0)),
			Color = COLORS.Crate,
			Material = Enum.Material.WoodPlanks,
			Parent = parent,
		})
		makeMarker(`FuseSpawn_{suffix}`, CFrame.new(center + Vector3.new(0, 3.8, 0)), Tags.FuseSpawn, parent)
	elseif char == "E" then
		makePart({
			Name = `Desk_{suffix}`,
			Size = Vector3.new(4, 3, 2.5),
			CFrame = CFrame.new(center + Vector3.new(0, 1.5, 0)),
			Color = COLORS.Console,
			Material = Enum.Material.Metal,
			Parent = parent,
		})
		makeMarker(
			`EvidenceSpawn_{suffix}`,
			CFrame.new(center + Vector3.new(0, 3.1, 0)),
			Tags.EvidenceSpawn,
			parent
		)
	elseif char == "P" then
		local cframe = mountedCFrame(row, col, 0.6, 5)
		if cframe then
			local panel = makePart({
				Name = `BreakerPanel_{suffix}`,
				Size = Vector3.new(4, 5, 0.6),
				CFrame = cframe,
				Color = COLORS.Panel,
				Material = Enum.Material.DiamondPlate,
				Parent = parent,
			})
			panel:SetAttribute("PanelId", `GEN-{suffix}`)
			CollectionService:AddTag(panel, Tags.FusePanel)
		end
	elseif char == "R" then
		local cframe = mountedCFrame(row, col, 2.5, 1.75)
		if cframe then
			local console = makePart({
				Name = `RadioConsole_{suffix}`,
				Size = Vector3.new(6, 3.5, 2.5),
				CFrame = cframe,
				Color = COLORS.Console,
				Material = Enum.Material.Metal,
				Parent = parent,
			})
			CollectionService:AddTag(console, Tags.RadioConsole)
			local screen = makePart({
				Name = `ConsoleScreen_{suffix}`,
				Size = Vector3.new(3, 2, 0.3),
				CFrame = console.CFrame * CFrame.new(0, 2.75, 0.8),
				Color = COLORS.Screen,
				Material = Enum.Material.Neon,
				Parent = parent,
			})
			addLight(screen, COLORS.Screen, 10, 0.8)
		end
	elseif char == "B" then
		local cframe = mountedCFrame(row, col, 0.3, 6)
		if cframe then
			local board = makePart({
				Name = `FrequencyBoard_{suffix}`,
				Size = Vector3.new(5, 3.5, 0.3),
				CFrame = cframe,
				Color = COLORS.Board,
				Parent = parent,
			})
			CollectionService:AddTag(board, Tags.FrequencyBoard)
		end
	elseif char == "L" or char == "C" then
		local color = if char == "L" then COLORS.WarmLight else COLORS.ColdLight
		local lamp = makePart({
			Name = `Lamp_{suffix}`,
			Size = Vector3.new(2, 0.4, 2),
			CFrame = CFrame.new(center + Vector3.new(0, height - 0.2, 0)),
			Color = color,
			Material = Enum.Material.Neon,
			Parent = parent,
			CanCollide = false,
		})
		addLight(lamp, color, 24, if char == "L" then 1.2 else 0.9)
	elseif char == "D" then
		local door = makePart({
			Name = `ExitDoor_{suffix}`,
			Size = Vector3.new(cell, height, cell),
			CFrame = CFrame.new(center + Vector3.new(0, height / 2, 0)),
			Color = COLORS.Door,
			Material = Enum.Material.CorrodedMetal,
			Parent = parent,
		})
		CollectionService:AddTag(door, Tags.ExitDoor)
	elseif char == "X" then
		makePart({
			Name = `Pad_{suffix}`,
			Size = Vector3.new(cell, 0.2, cell),
			CFrame = CFrame.new(center + Vector3.new(0, 0.1, 0)),
			Color = COLORS.Pad,
			Material = Enum.Material.DiamondPlate,
			Parent = parent,
		})
		local zone = makePart({
			Name = `ExtractionZone_{suffix}`,
			Size = Vector3.new(cell, height, cell),
			CFrame = CFrame.new(center + Vector3.new(0, height / 2, 0)),
			Color = COLORS.Zone,
			Parent = parent,
			CanCollide = false,
			Transparency = 1,
		})
		zone.CanQuery = false
		zone.CanTouch = false
		CollectionService:AddTag(zone, Tags.ExtractionZone)
	end
end

local function buildStation(): Model
	local problems = MapGrid.validate(Layout.Rows, Layout.MountedChars)
	for _, problem in problems do
		Log.warn("Map", "Station layout problem: %s", problem)
	end

	local model = Instance.new("Model")
	model.Name = "Station"
	local rows = Layout.Rows
	local cell = Layout.CellSize
	local height = Layout.WallHeight
	local width = #rows[1]
	local depth = #rows
	local middle = Vector3.new(
		Layout.Origin.X + (width - 1) * cell / 2,
		Layout.Origin.Y,
		Layout.Origin.Z + (depth - 1) * cell / 2
	)

	makePart({
		Name = "Floor",
		Size = Vector3.new(width * cell, 1, depth * cell),
		CFrame = CFrame.new(middle - Vector3.new(0, 0.5, 0)),
		Color = COLORS.Floor,
		Material = Enum.Material.Concrete,
		Parent = model,
	})
	makePart({
		Name = "Ceiling",
		Size = Vector3.new(width * cell, 1, depth * cell),
		CFrame = CFrame.new(middle + Vector3.new(0, height + 0.5, 0)),
		Color = COLORS.Ceiling,
		Material = Enum.Material.Concrete,
		Parent = model,
	})

	for index, run in MapGrid.wallRuns(rows) do
		local length = (run.colEnd - run.colStart + 1) * cell
		local left = cellCenter(run.row, run.colStart)
		local right = cellCenter(run.row, run.colEnd)
		makePart({
			Name = `Wall_{index}`,
			Size = Vector3.new(length, height, cell),
			CFrame = CFrame.new((left + right) / 2 + Vector3.new(0, height / 2, 0)),
			Color = COLORS.Wall,
			Material = Enum.Material.Concrete,
			Parent = model,
		})
	end

	for _, marker in MapGrid.markers(rows) do
		buildMarker(marker.char, marker.row, marker.col, model)
	end

	model.Parent = Workspace
	Log.info("Map", "Built graybox station (%dx%d cells)", width, depth)
	return model
end

local function buildLobby(): Model
	local model = Instance.new("Model")
	model.Name = "Lobby"
	local origin = Vector3.new(Layout.LobbyOrigin.X, Layout.LobbyOrigin.Y, Layout.LobbyOrigin.Z)
	local size = Layout.LobbySize
	local wallHeight = 10

	makePart({
		Name = "Floor",
		Size = Vector3.new(size, 1, size),
		CFrame = CFrame.new(origin - Vector3.new(0, 0.5, 0)),
		Color = COLORS.Floor,
		Material = Enum.Material.Concrete,
		Parent = model,
	})
	local half = size / 2
	local walls = {
		{ Vector3.new(0, 0, -half), Vector3.new(size, wallHeight, 2) },
		{ Vector3.new(0, 0, half), Vector3.new(size, wallHeight, 2) },
		{ Vector3.new(-half, 0, 0), Vector3.new(2, wallHeight, size) },
		{ Vector3.new(half, 0, 0), Vector3.new(2, wallHeight, size) },
	}
	for index, wall in walls do
		makePart({
			Name = `Wall_{index}`,
			Size = wall[2],
			CFrame = CFrame.new(origin + wall[1] + Vector3.new(0, wallHeight / 2, 0)),
			Color = COLORS.Wall,
			Material = Enum.Material.Concrete,
			Parent = model,
		})
	end

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "LobbySpawn"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(8, 1, 8)
	spawnLocation.CFrame = CFrame.new(origin + Vector3.new(0, 0.5, 0))
	spawnLocation.Color = COLORS.Pad
	spawnLocation.Material = Enum.Material.DiamondPlate
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0 -- no spawn forcefield
	spawnLocation.Parent = model
	CollectionService:AddTag(spawnLocation, Tags.LobbySpawn)

	for _, corner in
		{ Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) }
	do
		local base = origin + corner * (half - 6)
		makePart({
			Name = "LampPost",
			Size = Vector3.new(1, 8, 1),
			CFrame = CFrame.new(base + Vector3.new(0, 4, 0)),
			Color = COLORS.Console,
			Material = Enum.Material.Metal,
			Parent = model,
		})
		local lamp = makePart({
			Name = "Lamp",
			Size = Vector3.new(1.6, 0.6, 1.6),
			CFrame = CFrame.new(base + Vector3.new(0, 8.3, 0)),
			Color = COLORS.WarmLight,
			Material = Enum.Material.Neon,
			Parent = model,
		})
		addLight(lamp, COLORS.WarmLight, 32, 1.4)
	end

	local sign = makePart({
		Name = "Sign",
		Size = Vector3.new(20, 5, 0.5),
		CFrame = CFrame.lookAt(origin + Vector3.new(0, 6, -half + 1.5), origin + Vector3.new(0, 6, 0)),
		Color = COLORS.Board,
		Parent = model,
	})
	makeSign(sign, "LAST SHIFT // RELAY K-7 DEPLOYMENT", COLORS.WarmLight)

	model.Parent = Workspace
	return model
end

local function findModel(name: string): Model?
	local existing = Workspace:FindFirstChild(name)
	if existing and existing:IsA("Model") then
		Log.info("Map", "Using existing %s model from Workspace", name)
		return existing
	end
	return nil
end

function MapService.Init()
	station = findModel("Station") or buildStation()
	lobby = findModel("Lobby") or buildLobby()

	roundFolder = Instance.new("Folder")
	roundFolder.Name = "RoundObjects"
	roundFolder.Parent = station

	-- Only lobby spawns should be active, so respawns always land in the lobby.
	for _, instance in Workspace:GetDescendants() do
		if instance:IsA("SpawnLocation") and not instance:IsDescendantOf(lobby) and instance.Enabled then
			instance.Enabled = false
			Log.warn("Map", "Disabled stray SpawnLocation %s", instance:GetFullName())
		end
	end
end

function MapService.getStation(): Model
	return station
end

function MapService.getRoundFolder(): Folder
	return roundFolder
end

function MapService.clearRoundObjects()
	roundFolder:ClearAllChildren()
end

-- Tagged parts inside the station or lobby, sorted by name so seeded picks are repeatable.
function MapService.getTagged(tag: string): { BasePart }
	local result: { BasePart } = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if
			instance:IsA("BasePart") and (instance:IsDescendantOf(station) or instance:IsDescendantOf(lobby))
		then
			table.insert(result, instance)
		end
	end
	table.sort(result, function(a: BasePart, b: BasePart)
		return a:GetFullName() < b:GetFullName()
	end)
	return result
end

function MapService.getLobbySpawnCFrame(): CFrame
	local spawns = MapService.getTagged(Tags.LobbySpawn)
	if spawns[1] then
		return spawns[1].CFrame + Vector3.new(0, 4, 0)
	end
	return CFrame.new(Layout.LobbyOrigin.X, Layout.LobbyOrigin.Y + 4, Layout.LobbyOrigin.Z)
end

return MapService
