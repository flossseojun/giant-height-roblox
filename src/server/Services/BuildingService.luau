-- 건물 부수기: 착지(Stomp)로 내 키보다 작은 건물을 부숨 → 키 보상 → 60초 뒤 복구
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Smash = require(ReplicatedStorage.Shared.Logic.Smash)
local Growth = require(ReplicatedStorage.Shared.Logic.Growth)
local Zones = require(ReplicatedStorage.Shared.Logic.Zones)
local HeightService = require(script.Parent.HeightService)
local CoinService = require(script.Parent.CoinService)
local Remotes = require(script.Parent.Remotes)
local Util = require(script.Parent.Util)

Smash.setConfig(Config.SMASH)
local S = Config.SMASH
-- 클라이언트가 미리 연결할 수 있게 시작할 때 만들어 둠
local brokenRemote = Remotes.get("BuildingBroken")

type Building = {
	id: Model,
	model: Model,
	x: number,
	z: number,
	radius: number,
	floors: number,
	heightCm: number,
	zone: number,
	baseY: number,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	brokenUntil: number?,
	rubble: { BasePart },
}

local BuildingService = {}
local buildings: { Building } = {}
local byModel: { [Model]: Building } = {}
local stompAt: { [Player]: number } = {}
local hintAt: { [Player]: number } = {}
local rubbleFolder: Folder

local function mainColor(model: Model): Color3
	local best, area = nil, -1
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Transparency < 1 then
			local a = p.Size.X * p.Size.Z
			if a > area then
				best, area = p, a
			end
		end
	end
	return if best then best.Color else Color3.fromRGB(200, 200, 200)
end

local function index(inst: Instance)
	if not inst:IsA("Model") or byModel[inst] then
		return
	end
	local cf, size = inst:GetBoundingBox()
	local floors = inst:GetAttribute("Floors")
	local b: Building = {
		id = inst,
		model = inst,
		x = cf.Position.X,
		z = cf.Position.Z,
		radius = 0.5 * math.sqrt(size.X * size.X + size.Z * size.Z),
		floors = if type(floors) == "number" then floors else 1,
		heightCm = (inst:GetAttribute("HeightCm") :: number?) or Smash.heightCm(if type(floors) == "number" then floors else 1),
		zone = Util.zoneOf(inst),
		baseY = cf.Position.Y - size.Y / 2,
		size = size,
		cframe = cf,
		color = mainColor(inst),
		brokenUntil = nil,
		rubble = {},
	}
	byModel[inst] = b
	table.insert(buildings, b)
end

local function hide(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d:GetAttribute("_T") == nil then
				d:SetAttribute("_T", d.Transparency)
				d:SetAttribute("_C", d.CanCollide)
				d:SetAttribute("_Q", d.CanQuery)
			end
			d.Transparency = 1
			d.CanCollide = false
			d.CanQuery = false
		elseif d:IsA("SurfaceGui") then
			if d:GetAttribute("_E") == nil then
				d:SetAttribute("_E", d.Enabled)
			end
			d.Enabled = false
		end
	end
end

local function show(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local t, c, q = d:GetAttribute("_T"), d:GetAttribute("_C"), d:GetAttribute("_Q")
			if type(t) == "number" then
				d.Transparency = t
			end
			if type(c) == "boolean" then
				d.CanCollide = c
			end
			if type(q) == "boolean" then
				d.CanQuery = q
			end
			d:SetAttribute("_T", nil)
			d:SetAttribute("_C", nil)
			d:SetAttribute("_Q", nil)
		elseif d:IsA("SurfaceGui") then
			local e = d:GetAttribute("_E")
			if type(e) == "boolean" then
				d.Enabled = e
			end
			d:SetAttribute("_E", nil)
		end
	end
end

local function makeRubble(b: Building)
	local w = math.max(2, math.min(b.size.X, b.size.Z))
	for i = 1, S.rubble do
		local r = Instance.new("Part")
		r.Name = "Rubble"
		r.Anchored = true
		r.CanCollide = true
		r.Material = Enum.Material.Slate
		r.Color = b.color:Lerp(Color3.fromRGB(120, 115, 105), 0.4)
		local s = w * (0.55 - i * 0.12)
		r.Size = Vector3.new(s, s * 0.35, s * 0.8)
		local a = i * 2.1
		local off = Vector3.new(math.cos(a), 0, math.sin(a)) * w * 0.15
		r.CFrame = CFrame.new(Vector3.new(b.x, b.baseY + r.Size.Y / 2, b.z) + off) * CFrame.Angles(0, a, math.rad(8 * i))
		r.Parent = rubbleFolder
		table.insert(b.rubble, r)
	end
end

local function playerSpots(): { Vector3 }
	local out = {}
	for _, p in Players:GetPlayers() do
		local root = Util.root(p)
		if root then
			table.insert(out, root.Position)
		end
	end
	return out
end

local function tryRestore(b: Building)
	if not b.model.Parent then
		return
	end
	if not Smash.canRestore(b, playerSpots()) then
		task.delay(S.restoreRetry, tryRestore, b)
		return
	end
	for _, r in b.rubble do
		r:Destroy()
	end
	b.rubble = {}
	show(b.model)
	b.brokenUntil = nil
end

local function smash(b: Building, player: Player)
	b.brokenUntil = os.clock() + S.respawn + 3600 -- 복구될 때까지 (복구가 nil로 되돌림)
	hide(b.model)
	makeRubble(b)
	brokenRemote:FireAllClients(b.cframe, b.size, b.color)
	local zoneCfg = Config.ZONES[b.zone] or Config.ZONES[1]
	HeightService.add(player, Smash.reward(Zones.bestGain(zoneCfg), b.floors), "smash")
	CoinService.add(player, Config.COINS.smashPerFloor * b.floors, "smash")
	task.delay(S.respawn, tryRestore, b)
end

local function onStomp(player: Player)
	local now = os.clock()
	local root = Util.root(player)
	if not root or now - (stompAt[player] or 0) < S.cooldown then
		return
	end
	stompAt[player] = now
	local h = HeightService.get(player)
	local scale = Growth.heightToScale(h, Config.SCALE_K, Config.MAX_SCALE)
	local hit, tall = Smash.targets(buildings, root.Position, scale, h, now)
	for _, id in hit do
		local b = byModel[id]
		if b then
			smash(b, player)
		end
	end
	if #hit > 0 then
		Remotes.sfx(player, "bossHit")
	elseif #tall > 0 and now - (hintAt[player] or 0) >= S.hintCooldown then
		hintAt[player] = now
		local b = byModel[tall[1]]
		if b then
			Remotes.notify(player, string.format("건물 %dm — 키가 더 커야 해요!", math.floor(b.heightCm / 100)))
		end
	end
end

function BuildingService.start()
	rubbleFolder = Instance.new("Folder")
	rubbleFolder.Name = "Rubble"
	rubbleFolder.Parent = workspace
	Util.eachTagged("Breakable", index)
	Remotes.get("Stomp").OnServerEvent:Connect(onStomp)
	Players.PlayerRemoving:Connect(function(player)
		stompAt[player] = nil
		hintAt[player] = nil
	end)
end

return BuildingService
