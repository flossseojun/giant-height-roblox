-- 음식 모양: 서버의 투명 히트박스(속성 FoodId) 위에 진짜 음식 모양을 그리고 천천히 돌리며 둥실
local RunService = game:GetService("RunService")

local FoodVisuals = {}

local rad = math.rad
local C = Color3.fromRGB
-- 모양 조각: kind("block"|"ball"|"cyl"(세로 원기둥)), size(음식 크기 1 기준), offset, rot(도), color, mat, transparency
type Piece = { kind: string, size: Vector3, offset: Vector3, rot: Vector3?, color: Color3, mat: Enum.Material?, tr: number? }
local function P(kind, size, offset, color, rot, mat, tr): Piece
	return { kind = kind, size = size, offset = offset, color = color, rot = rot, mat = mat, tr = tr }
end
local V = Vector3.new

local function carton(body: Color3, band: Color3, mat: Enum.Material?): { Piece }
	return {
		P("block", V(0.55, 0.7, 0.55), V(0, -0.05, 0), body, nil, mat),
		P("block", V(0.4, 0.4, 0.55), V(0, 0.3, 0), body, V(0, 0, 45), mat),
		P("block", V(0.57, 0.16, 0.57), V(0, -0.05, 0), band, nil, mat),
		P("cyl", V(0.08, 0.14, 0.14), V(0.12, 0.5, 0), band, nil, mat),
	}
end

local SHAPES: { [string]: { Piece } } = {
	milk = carton(C(250, 250, 250), C(60, 130, 220)),
	rainmilk = carton(C(250, 250, 250), C(90, 170, 240)),
	golden_milk = carton(C(255, 210, 60), C(255, 245, 200), Enum.Material.Neon),
	starmilk = {
		P("block", V(0.55, 0.7, 0.55), V(0, -0.05, 0), C(200, 200, 255)),
		P("block", V(0.4, 0.4, 0.55), V(0, 0.3, 0), C(200, 200, 255), V(0, 0, 45)),
		P("ball", V(0.22, 0.22, 0.22), V(0, -0.05, -0.29), C(255, 230, 90), nil, Enum.Material.Neon),
		P("block", V(0.57, 0.12, 0.57), V(0, -0.3, 0), C(120, 120, 220)),
	},
	eggbread = {
		P("block", V(0.8, 0.42, 0.55), V(0, -0.1, 0), C(225, 170, 90)),
		P("ball", V(0.55, 0.14, 0.42), V(0, 0.13, 0), C(250, 248, 240)),
		P("ball", V(0.24, 0.16, 0.24), V(0, 0.18, 0), C(255, 190, 40)),
	},
	hotteok = {
		P("cyl", V(0.14, 0.9, 0.9), V(0, 0, 0), C(185, 115, 55)),
		P("cyl", V(0.05, 0.7, 0.7), V(0, 0.08, 0), C(210, 145, 70)),
		P("ball", V(0.18, 0.06, 0.18), V(0.15, 0.11, 0.1), C(110, 60, 25)),
	},
	corn = {
		P("ball", V(0.42, 0.95, 0.42), V(0, 0.05, 0), C(255, 215, 60)),
		P("block", V(0.08, 0.6, 0.3), V(0.2, -0.2, 0), C(110, 170, 70), V(0, 0, 18)),
		P("block", V(0.08, 0.6, 0.3), V(-0.2, -0.2, 0), C(110, 170, 70), V(0, 0, -18)),
	},
	lotusdog = {
		P("cyl", V(0.5, 0.07, 0.07), V(0, -0.45, 0), C(225, 200, 160)),
		P("ball", V(0.34, 0.75, 0.34), V(0, 0.1, 0), C(190, 90, 60)),
		P("cyl", V(0.35, 0.4, 0.4), V(0, -0.12, 0), C(90, 160, 80)),
	},
	hanwoo = {
		P("cyl", V(0.07, 0.95, 0.95), V(0, -0.1, 0), C(245, 245, 245)),
		P("block", V(0.6, 0.16, 0.42), V(0, 0.02, 0), C(185, 50, 55)),
		P("block", V(0.55, 0.17, 0.05), V(0, 0.02, 0.07), C(245, 225, 225)),
		P("block", V(0.4, 0.17, 0.04), V(0.05, 0.02, -0.1), C(245, 225, 225)),
	},
	bibimbap = {
		P("cyl", V(0.4, 0.85, 0.85), V(0, -0.15, 0), C(45, 40, 40)),
		P("cyl", V(0.04, 0.75, 0.75), V(0, 0.07, 0), C(240, 240, 235)),
		P("block", V(0.25, 0.08, 0.25), V(-0.18, 0.11, 0.12), C(80, 160, 60)),
		P("block", V(0.22, 0.08, 0.22), V(0.18, 0.11, 0.12), C(240, 130, 40)),
		P("block", V(0.22, 0.08, 0.22), V(-0.15, 0.11, -0.16), C(130, 80, 50)),
		P("block", V(0.2, 0.08, 0.2), V(0.18, 0.11, -0.15), C(200, 40, 40)),
		P("ball", V(0.2, 0.12, 0.2), V(0, 0.14, 0), C(255, 190, 40)),
	},
	ginkgo = {
		P("ball", V(0.38, 0.45, 0.38), V(-0.15, 0, 0), C(245, 200, 60)),
		P("ball", V(0.38, 0.45, 0.38), V(0.17, -0.05, 0.08), C(235, 190, 50)),
		P("ball", V(0.32, 0.4, 0.32), V(0.02, 0.18, -0.1), C(250, 210, 80)),
	},
	spring = {
		P("cyl", V(0.75, 0.38, 0.38), V(0, -0.05, 0), C(150, 210, 255), nil, Enum.Material.Glass, 0.3),
		P("cyl", V(0.55, 0.3, 0.3), V(0, -0.12, 0), C(90, 170, 240), nil, Enum.Material.Glass, 0.2),
		P("cyl", V(0.12, 0.2, 0.2), V(0, 0.38, 0), C(40, 110, 200)),
	},
	starcandy = {
		P("block", V(0.95, 0.24, 0.24), V(0, 0, 0), C(255, 150, 210), V(0, 0, 0), Enum.Material.Neon),
		P("block", V(0.95, 0.24, 0.24), V(0, 0, 0), C(255, 150, 210), V(0, 0, 60), Enum.Material.Neon),
		P("block", V(0.95, 0.24, 0.24), V(0, 0, 0), C(255, 150, 210), V(0, 0, 120), Enum.Material.Neon),
		P("ball", V(0.4, 0.4, 0.4), V(0, 0, 0), C(255, 200, 235)),
	},
	meteor = {
		P("ball", V(0.75, 0.68, 0.72), V(0, 0, 0), C(110, 70, 50), nil, Enum.Material.Slate),
		P("ball", V(0.2, 0.2, 0.2), V(0.25, 0.15, 0.2), C(255, 130, 40), nil, Enum.Material.Neon),
		P("ball", V(0.16, 0.16, 0.16), V(-0.22, 0.2, -0.15), C(255, 160, 50), nil, Enum.Material.Neon),
		P("ball", V(0.14, 0.14, 0.14), V(0.05, -0.25, 0.28), C(255, 110, 30), nil, Enum.Material.Neon),
	},
}

local folder: Folder

type Visual = { parts: { BasePart }, offsets: { CFrame }, phase: number, size: number }
local visuals: { [BasePart]: Visual } = {}

local function buildParts(id: string, d: number, parent: Instance?): ({ BasePart }, { CFrame })
	local pieces = SHAPES[id] or SHAPES.milk
	local parts, offsets = {}, {}
	for _, pc in pieces do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Color = pc.color
		p.Material = pc.mat or Enum.Material.SmoothPlastic
		p.Transparency = pc.tr or 0
		local rot = pc.rot or Vector3.zero
		local cf = CFrame.new(pc.offset * d) * CFrame.Angles(rad(rot.X), rad(rot.Y), rad(rot.Z))
		if pc.kind == "ball" then
			p.Shape = Enum.PartType.Ball
			p.Size = pc.size * d
		elseif pc.kind == "cyl" then
			p.Shape = Enum.PartType.Cylinder
			-- 원기둥 축은 로컬 X → 세워서 위쪽으로
			p.Size = Vector3.new(pc.size.X, pc.size.Y, pc.size.Z) * d
			cf *= CFrame.Angles(0, 0, rad(90))
		else
			p.Size = pc.size * d
		end
		p.Parent = parent or folder
		table.insert(parts, p)
		table.insert(offsets, cf)
	end
	return parts, offsets
end

-- 먹기 연출이 쓰는 복제용 모양 (Model, 기준 CFrame 원점)
function FoodVisuals.shapeOf(id: string, d: number): Model
	local m = Instance.new("Model")
	local parts, offsets = buildParts(id, d, m)
	for i, p in parts do
		p.CFrame = offsets[i]
	end
	m.PrimaryPart = parts[1]
	return m
end

local function track(hitbox: Instance)
	if not hitbox:IsA("BasePart") or visuals[hitbox] then
		return
	end
	local id = hitbox:GetAttribute("FoodId")
	if type(id) ~= "string" then
		return
	end
	local d = hitbox.Size.X * 0.9
	local parts, offsets = buildParts(id, d)
	visuals[hitbox] = { parts = parts, offsets = offsets, phase = math.random() * 6.28, size = d }
end

local function untrack(hitbox: Instance)
	local v = visuals[hitbox :: BasePart]
	if v then
		for _, p in v.parts do
			p:Destroy()
		end
		visuals[hitbox :: BasePart] = nil
	end
end

local function update()
	local t = os.clock()
	local moveParts, moveCFs = {}, {}
	for hitbox, v in visuals do
		if not hitbox.Parent then
			untrack(hitbox)
			continue
		end
		local base = CFrame.new(hitbox.Position + Vector3.new(0, math.sin(t * 2 + v.phase) * 0.12 * v.size, 0))
			* CFrame.Angles(0, t * 1.2 + v.phase, 0)
		for i, p in v.parts do
			table.insert(moveParts, p)
			table.insert(moveCFs, base * v.offsets[i])
		end
	end
	if #moveParts > 0 then
		workspace:BulkMoveTo(moveParts, moveCFs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function FoodVisuals.start()
	folder = Instance.new("Folder")
	folder.Name = "FoodVisuals"
	folder.Parent = workspace.CurrentCamera
	local function hook(inst: Instance)
		-- 속성은 파트가 복제된 직후 도착할 수 있어 한 프레임 미룸
		task.defer(track, inst)
	end
	-- 맵 음식과 우유 비
	for _, name in { "Foods", "MilkRain" } do
		task.spawn(function()
			local f = workspace:WaitForChild(name)
			for _, d in f:GetDescendants() do
				hook(d)
			end
			f.DescendantAdded:Connect(hook)
			f.DescendantRemoving:Connect(untrack)
		end)
	end
	RunService.RenderStepped:Connect(update)
end

return FoodVisuals
