-- 모든 플레이어의 꾸미기(날개·오라·발자국)를 각자 화면에서 그림. 몸 크기에 맞춰 커짐.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.Config)
local Growth = require(ReplicatedStorage.Shared.Logic.Growth)

local Cosmetics = {}
local CC = Config.COSMETICS
local MAX_PRINTS = 20
local PRINT_LIFE = 3

local items: { [string]: any } = {}
for _, it in CC.items do
	items[it.id] = it
end

type Look = {
	key: string,
	wings: { BasePart },
	auraPart: BasePart?,
	emitter: ParticleEmitter?,
	trail: any?,
	prints: { { part: BasePart, at: number } },
	lastStep: Vector3?,
	scale: number,
}
local looks: { [Player]: Look } = {}
local folder: Folder

local function scaleOf(p: Player): number
	local h = p:GetAttribute("Height")
	return Growth.heightToScale(if type(h) == "number" then h else Config.START_HEIGHT, Config.SCALE_K, Config.MAX_SCALE)
end

local function equippedOf(p: Player): { wing: string, aura: string, trail: string }
	local raw = p:GetAttribute("Cosmetics")
	local t: any = {}
	if type(raw) == "string" then
		local ok, v = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(v) == "table" then
			t = v
		end
	end
	return { wing = t.wing or "", aura = t.aura or "", trail = t.trail or "" }
end

local function newPart(color: Color3, material: Enum.Material): Part
	local x = Instance.new("Part")
	x.Anchored = true
	x.CanCollide = false
	x.CanQuery = false
	x.CanTouch = false
	x.CastShadow = false
	x.Color = color
	x.Material = material
	x.Parent = folder
	return x
end

local function clear(l: Look)
	for _, w in l.wings do
		w:Destroy()
	end
	if l.auraPart then
		l.auraPart:Destroy()
	end
	for _, pr in l.prints do
		pr.part:Destroy()
	end
end

local function build(eq: { wing: string, aura: string, trail: string }): Look
	local l: Look = { key = eq.wing .. "|" .. eq.aura .. "|" .. eq.trail, wings = {}, prints = {}, scale = 0 }
	local w = items[eq.wing]
	if w then
		local mat = if w.rarity == "legendary" then Enum.Material.Neon else Enum.Material.SmoothPlastic
		for _ = 1, 2 do -- 왼쪽·오른쪽 바깥 날개
			table.insert(l.wings, newPart(w.color, mat))
		end
		for _ = 1, 2 do -- 안쪽 무늬
			local inner = newPart(w.color2 or w.color, mat)
			inner.Transparency = 0.2
			table.insert(l.wings, inner)
		end
	end
	local a = items[eq.aura]
	if a then
		local part = newPart(a.color, Enum.Material.SmoothPlastic)
		part.Transparency = 1
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(a.color, a.color2 or a.color)
		e.Lifetime = NumberRange.new(1, 1.6)
		e.Rate = if a.rarity == "legendary" then 40 elseif a.rarity == "rare" then 22 else 14
		e.LightEmission = if a.rarity == "legendary" then 1 else 0.4
		e.SpreadAngle = Vector2.new(180, 180)
		e.Transparency = NumberSequence.new(0.1, 1)
		e.Parent = part
		l.auraPart, l.emitter = part, e
	end
	l.trail = items[eq.trail]
	return l
end

local function setScale(l: Look, s: number)
	if math.abs(l.scale - s) < 0.01 then
		return
	end
	l.scale = s
	if l.auraPart and l.emitter then
		l.auraPart.Size = Vector3.new(3, 5, 3) * s
		l.emitter.Size = NumberSequence.new(0.45 * s, 0)
		l.emitter.Speed = NumberRange.new(0.5 * s, 1.5 * s)
	end
	for i, part in l.wings do
		local inner = i > 2
		part.Size = Vector3.new(0.15, if inner then 1.4 else 2.4, if inner then 1.0 else 1.8) * s
	end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function footprint(l: Look, root: BasePart, s: number, now: number)
	local it = l.trail
	if not it then
		return
	end
	local pos = root.Position
	local last = l.lastStep
	if last and ((pos - last) * Vector3.new(1, 0, 1)).Magnitude < 2 * s then
		return
	end
	l.lastStep = pos
	if not last then
		return
	end
	rayParams.FilterDescendantsInstances = { folder, root.Parent :: Instance }
	local hit = workspace:Raycast(pos, Vector3.new(0, -8 * s, 0), rayParams)
	if not hit then
		return
	end
	local mat = if it.rarity ~= "common" then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local p = newPart(it.color, mat)
	p.Size = Vector3.new(0.8 * s, 0.08, 1.2 * s)
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	p.CFrame = CFrame.lookAt(hit.Position + Vector3.new(0, 0.05, 0), hit.Position + Vector3.new(0, 0.05, 0) + (if look.Magnitude > 0.01 then look else Vector3.zAxis))
	table.insert(l.prints, { part = p, at = now })
	while #l.prints > MAX_PRINTS do
		local old = table.remove(l.prints, 1)
		if old then
			old.part:Destroy()
		end
	end
end

local function update()
	local now = os.clock()
	for _, p in Players:GetPlayers() do
		local eq = equippedOf(p)
		local key = eq.wing .. "|" .. eq.aura .. "|" .. eq.trail
		local l = looks[p]
		if l and l.key ~= key then
			clear(l)
			l = nil
		end
		if not l then
			if key == "||" then
				continue
			end
			l = build(eq)
			looks[p] = l
		end
		local look = l :: Look
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		-- 사라진 발자국 정리
		while look.prints[1] and now - look.prints[1].at > PRINT_LIFE do
			local old = table.remove(look.prints, 1)
			if old then
				old.part:Destroy()
			end
		end
		if not root then
			continue
		end
		local s = scaleOf(p)
		setScale(look, s)
		local cf = root.CFrame
		if #look.wings > 0 then
			local flap = math.sin(now * 4) * 0.25
			for i, part in look.wings do
				local side = if i % 2 == 1 then -1 else 1
				local inner = i > 2
				local hinge = cf * CFrame.new(side * 0.35 * s, 0.7 * s, 0.6 * s)
					* CFrame.Angles(0, side * (0.45 + flap), side * 0.25)
				local reach = if inner then 0.75 else 1.0
				part.CFrame = hinge * CFrame.new(side * reach * s, 0, 0.3 * s) * CFrame.Angles(0, math.rad(90), 0)
					* CFrame.new(if inner then 0.1 * side else 0, 0, 0)
			end
		end
		if look.auraPart then
			look.auraPart.CFrame = cf
		end
		footprint(look, root, s, now)
	end
	for p, l in looks do
		if not p.Parent then
			clear(l)
			looks[p] = nil
		end
	end
end

function Cosmetics.start()
	folder = Instance.new("Folder")
	folder.Name = "Cosmetics"
	folder.Parent = workspace.CurrentCamera
	RunService.RenderStepped:Connect(update)
end

return Cosmetics
