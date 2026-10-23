--!strict
-- Placeholder rig for The Echo: a tall, thin, dark humanoid built from parts, with long arms
-- and two pale eyes. No animations yet. Replace with a proper model and animations later;
-- the AI only needs a Model with a Humanoid and a HumanoidRootPart.
local EchoRig = {}

local BODY_COLOR = Color3.fromRGB(16, 16, 20)
local EYE_COLOR = Color3.fromRGB(200, 205, 210)

local LEG_LENGTH = 5
local ROOT_HEIGHT = 2

-- Height of the root part's centre above the floor.
EchoRig.RootAboveGround = LEG_LENGTH + ROOT_HEIGHT / 2

export type Rig = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	head: BasePart,
	eyes: { BasePart },
}

local function bodyPart(model: Model, root: BasePart, name: string, size: Vector3, offset: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = BODY_COLOR
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = root.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
	return part
end

-- `groundCFrame` is a point on the floor; the rig stands on it.
function EchoRig.build(groundCFrame: CFrame, parent: Instance): Rig
	local model = Instance.new("Model")
	model.Name = "Echo"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, ROOT_HEIGHT, 1)
	root.Transparency = 1
	root.CanCollide = true
	-- Heavy, so players can't shove it around (all other parts are massless).
	root.CustomPhysicalProperties = PhysicalProperties.new(80, 0.3, 0.5)
	root.CFrame = groundCFrame * CFrame.new(0, LEG_LENGTH + ROOT_HEIGHT / 2, 0)
	root.Parent = model
	model.PrimaryPart = root

	-- Offsets are from the root's centre (LEG_LENGTH + 1 above the floor).
	bodyPart(model, root, "Torso", Vector3.new(2.2, 3.5, 1), CFrame.new(0, 0.75, 0))
	local head = bodyPart(model, root, "Head", Vector3.new(1.4, 1.8, 1.4), CFrame.new(0, 3.4, 0.1))
	bodyPart(model, root, "LeftLeg", Vector3.new(0.8, LEG_LENGTH, 0.8), CFrame.new(-0.55, -3.5, 0))
	bodyPart(model, root, "RightLeg", Vector3.new(0.8, LEG_LENGTH, 0.8), CFrame.new(0.55, -3.5, 0))
	-- Long arms hang past the knees and lean slightly forward.
	bodyPart(
		model,
		root,
		"LeftArm",
		Vector3.new(0.6, 5.5, 0.6),
		CFrame.new(-1.45, -0.45, -0.2) * CFrame.Angles(0.1, 0, 0.05)
	)
	bodyPart(
		model,
		root,
		"RightArm",
		Vector3.new(0.6, 5.5, 0.6),
		CFrame.new(1.45, -0.45, -0.2) * CFrame.Angles(0.1, 0, -0.05)
	)

	local eyes: { BasePart } = {}
	for _, x in { -0.3, 0.3 } do
		local eye = bodyPart(model, root, "Eye", Vector3.new(0.25, 0.12, 0.05), CFrame.new(x, 3.55, -0.62))
		eye.Color = EYE_COLOR
		eye.Material = Enum.Material.Neon
		table.insert(eyes, eye)
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = LEG_LENGTH
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false -- this rig has no neck joint; without this the humanoid would die at once
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = model

	model.Parent = parent
	-- The server simulates the Echo so clients can't move it.
	root:SetNetworkOwner(nil)

	return { model = model, humanoid = humanoid, root = root, head = head, eyes = eyes }
end

return EchoRig
