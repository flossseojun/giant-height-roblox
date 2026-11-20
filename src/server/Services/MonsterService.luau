-- 야생 몬스터: 출현·배회·펫과 전투·보상·길들이기
-- 몬스터는 펫만 공격한다 (플레이어를 때리거나 멈추게 하지 않음)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MonsterCombat = require(ReplicatedStorage.Shared.Logic.MonsterCombat)
local BossFight = require(ReplicatedStorage.Shared.Logic.BossFight)
local Growth = require(ReplicatedStorage.Shared.Logic.Growth)
local Zones = require(ReplicatedStorage.Shared.Logic.Zones)
local HeightService = require(script.Parent.HeightService)
local PetService = require(script.Parent.PetService)
local Remotes = require(script.Parent.Remotes)
local Util = require(script.Parent.Util)

MonsterCombat.setConfig(Config.PET)

local SPECIES = Config.PET_SPECIES
local MC = Config.MONSTER

local LOOK = {
	pigeon = { body = Color3.fromRGB(150, 155, 170), accent = Color3.fromRGB(90, 160, 140), beak = Color3.fromRGB(240, 180, 60) },
	duck = { body = Color3.fromRGB(245, 245, 235), accent = Color3.fromRGB(40, 130, 70), beak = Color3.fromRGB(250, 160, 30) },
	carp = { body = Color3.fromRGB(240, 120, 50), accent = Color3.fromRGB(250, 240, 230), beak = Color3.fromRGB(240, 90, 60) },
	heron = { body = Color3.fromRGB(200, 205, 215), accent = Color3.fromRGB(60, 65, 80), beak = Color3.fromRGB(230, 200, 60) },
	boar = { body = Color3.fromRGB(110, 80, 60), accent = Color3.fromRGB(70, 50, 40), beak = Color3.fromRGB(240, 230, 210) },
	crow = { body = Color3.fromRGB(35, 35, 45), accent = Color3.fromRGB(70, 70, 95), beak = Color3.fromRGB(60, 60, 60) },
	star = { body = Color3.fromRGB(255, 230, 120), accent = Color3.fromRGB(180, 200, 255), beak = Color3.fromRGB(255, 255, 255) },
}

type Monster = {
	id: number,
	kind: string,
	zone: number,
	spawn: BasePart,
	hp: number,
	maxHp: number,
	atk: number,
	xp: number,
	attackEvery: number,
	gainMult: number,
	size: number,
	pos: Vector3,
	goal: Vector3,
	model: Model,
	setBar: (number) -> (),
	nextAttack: number,
	hitBy: { [Player]: { lastAt: number, uids: { [number]: boolean } } },
}

local MonsterService = {}
local monsters: { [number]: Monster } = {}
local nextId = 1
local folder: Folder
local focus: { [Player]: number } = {}
local offers: { [Player]: { id: number, kind: string, expires: number } } = {}
local stompAt: { [Player]: number } = {}
local petNextAttack: { [Player]: { [number]: number } } = {}

local function scaleOf(player: Player): number
	return Growth.heightToScale(HeightService.get(player), Config.SCALE_K, Config.MAX_SCALE)
end

local function list(): { Monster }
	local out = {}
	for _, m in monsters do
		table.insert(out, m)
	end
	return out
end

local function countIn(zone: number): number
	local n = 0
	for _, m in monsters do
		if m.zone == zone then
			n += 1
		end
	end
	return n
end

local function countAt(spawn: BasePart): number
	local n = 0
	for _, m in monsters do
		if m.spawn == spawn then
			n += 1
		end
	end
	return n
end

local function randomPointNear(spawn: BasePart): Vector3
	local r = (spawn:GetAttribute("Radius") :: number?) or 12
	local a = math.random() * math.pi * 2
	local d = math.sqrt(math.random()) * r
	return spawn.Position + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
end

-- 동글동글 몬스터 모델 (파트 몇 개)
local function buildModel(kind: string, size: number): (Model, BasePart)
	local look = LOOK[kind] or LOOK.pigeon
	local m = Instance.new("Model")
	m.Name = "Monster_" .. kind
	local function p(name: string, sz: Vector3, offset: Vector3, color: Color3, shape: Enum.PartType?): Part
		local x = Instance.new("Part")
		x.Name = name
		x.Size = sz * size
		x.Shape = shape or Enum.PartType.Ball
		x.Color = color
		x.Material = if kind == "star" then Enum.Material.Neon else Enum.Material.SmoothPlastic
		x.Anchored = true
		x.CanCollide = false
		x.CanTouch = false
		x.CanQuery = true
		x:SetAttribute("Offset", offset * size)
		x.Parent = m
		return x
	end
	local body = p("Body", Vector3.new(2.4, 2, 2.6), Vector3.zero, look.body)
	p("Head", Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, 1.1, -1), look.body)
	p("Beak", Vector3.new(0.5, 0.4, 0.7), Vector3.new(0, 1, -1.8), look.beak)
	p("EyeL", Vector3.new(0.3, 0.3, 0.3), Vector3.new(-0.4, 1.35, -1.55), Color3.new(0, 0, 0))
	p("EyeR", Vector3.new(0.3, 0.3, 0.3), Vector3.new(0.4, 1.35, -1.55), Color3.new(0, 0, 0))
	p("WingL", Vector3.new(0.5, 1.2, 1.8), Vector3.new(-1.25, 0.1, 0.1), look.accent)
	p("WingR", Vector3.new(0.5, 1.2, 1.8), Vector3.new(1.25, 0.1, 0.1), look.accent)
	m.PrimaryPart = body
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 400
	click.Parent = body
	return m, body
end

local function place(mon: Monster, look: Vector3?)
	local dir = look or (mon.goal - mon.pos)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	local cf = if flat.Magnitude > 0.01 then CFrame.lookAt(mon.pos, mon.pos + flat) else CFrame.new(mon.pos)
	for _, part in mon.model:GetChildren() do
		if part:IsA("BasePart") then
			local off = part:GetAttribute("Offset") :: Vector3? or Vector3.zero
			part.CFrame = cf * CFrame.new(off)
		end
	end
end

local function hpBar(adornee: BasePart, name: string, size: number): (number) -> ()
	local bb = Instance.new("BillboardGui")
	bb.Adornee = adornee
	bb.Size = UDim2.new(0, 110, 0, 34)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 3 * size, 0)
	bb.MaxDistance = 120 * math.max(1, size / 2)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0.55, 0)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = name
	label.Parent = bb
	local back = Instance.new("Frame")
	back.Position = UDim2.new(0, 0, 0.62, 0)
	back.Size = UDim2.new(1, 0, 0.3, 0)
	back.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	back.BorderSizePixel = 0
	back.Parent = bb
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(230, 70, 70)
	fill.BorderSizePixel = 0
	fill.Parent = back
	bb.Parent = adornee
	return function(frac: number)
		fill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
	end
end

local function spawnAt(spawn: BasePart)
	local kind = spawn:GetAttribute("Species")
	local zone = Util.zoneOf(spawn)
	local sp = type(kind) == "string" and SPECIES[kind]
	if not (sp and sp.monster) then
		return
	end
	local hp, atk, xp = MonsterCombat.monsterStats(sp, Config.PET.zoneK[zone] or 1)
	local size = MC.sizeK[zone] or 1
	local model, body = buildModel(kind, size)
	local id = nextId
	nextId += 1
	model:SetAttribute("MonsterId", id)
	model:SetAttribute("Species", kind)
	model:SetAttribute("Zone", zone)
	model:SetAttribute("MaxHp", hp)
	model:SetAttribute("Hp", hp)
	local start = randomPointNear(spawn) + Vector3.new(0, size * 1.1, 0)
	local mon: Monster = {
		id = id,
		kind = kind,
		zone = zone,
		spawn = spawn,
		hp = hp,
		maxHp = hp,
		atk = atk,
		xp = xp,
		attackEvery = sp.monster.attackEvery,
		gainMult = sp.monster.gainMult,
		size = size,
		pos = start,
		goal = start,
		model = model,
		setBar = hpBar(body, sp.name, size),
		nextAttack = 0,
		hitBy = {},
	}
	monsters[id] = mon
	place(mon)
	model.Parent = folder
	local click = body:FindFirstChildOfClass("ClickDetector")
	if click then
		click.MouseClick:Connect(function(player)
			if monsters[id] then
				focus[player] = id
			end
		end)
	end
end

local function kill(mon: Monster, killer: Player?)
	monsters[mon.id] = nil
	mon.model:Destroy()
	mon.spawn:SetAttribute("NextSpawnAt", os.clock() + MC.respawn)
	local now = os.clock()
	for player, rec in mon.hitBy do
		if player.Parent and now - rec.lastAt <= 30 then
			local uids = {}
			for uid in rec.uids do
				table.insert(uids, uid)
			end
			if #uids > 0 then
				PetService.giveXp(player, uids, mon.xp)
			end
		end
	end
	for player, id in focus do
		if id == mon.id then
			focus[player] = nil
		end
	end
	if killer and killer.Parent then
		local zoneCfg = Config.ZONES[mon.zone] or Config.ZONES[1]
		HeightService.add(killer, Zones.bestGain(zoneCfg) * mon.gainMult, "monster")
		Remotes.sfx(killer, "bossHit")
		local sp = SPECIES[mon.kind]
		if sp.tameChance and MonsterCombat.tameRoll(sp.tameChance, math.random()) then
			local offerId = (offers[killer] and offers[killer].id or 0) + 1
			offers[killer] = { id = offerId, kind = mon.kind, expires = os.clock() + Config.PET.tameWindow }
			Remotes.get("TameOffer"):FireClient(killer, offerId, mon.kind, sp.name, Config.PET.tameWindow)
		end
	end
end

-- 몬스터에 데미지 (who: 때린 플레이어, uid: 때린 펫, 밟기면 nil)
local function hit(mon: Monster, dmg: number, who: Player, uid: number?)
	if not monsters[mon.id] or dmg <= 0 then
		return
	end
	mon.hp -= dmg
	local rec = mon.hitBy[who] or { lastAt = 0, uids = {} }
	rec.lastAt = os.clock()
	if uid then
		rec.uids[uid] = true
	end
	mon.hitBy[who] = rec
	mon.model:SetAttribute("Hp", math.max(0, mon.hp))
	mon.setBar(mon.hp / mon.maxHp)
	if mon.hp <= 0 then
		kill(mon, who)
	end
end

local function applyDamages(dmgs: { [any]: number }, who: Player, uid: number?)
	for id, d in dmgs do
		local mon = monsters[id]
		if mon then
			hit(mon, d, who, uid)
		end
	end
end

local function rangeOf(player: Player): number
	return Config.PET.baseRange * scaleOf(player)
end

-- 펫 공격 + 몬스터 반격 + 기절 회복
local function combatTick(now: number)
	local all = list()
	for _, player in Players:GetPlayers() do
		local root = Util.root(player)
		local team = PetService.team(player)
		if root and #team > 0 then
			local changed = false
			local nexts = petNextAttack[player] or {}
			petNextAttack[player] = nexts
			for _, m in team do
				if MonsterCombat.tickRevive(m.state, now) then
					changed = true
				end
				if MonsterCombat.alive(m.state) and (nexts[m.entry.uid] or 0) <= now then
					local target = MonsterCombat.pickTarget(all, root.Position, rangeOf(player), focus[player])
					local mon = target and monsters[target]
					if mon then
						hit(mon, m.atk, player, m.entry.uid)
						nexts[m.entry.uid] = now + Config.PET.attackEvery
					end
				end
			end
			if changed then
				PetService.publish(player)
			end
		end
	end
	-- 몬스터 반격: 최근에 자기를 때린 플레이어의 살아 있는 펫 하나를 공격
	for _, mon in monsters do
		if now >= mon.nextAttack then
			local victim, victimAt = nil, 0
			for player, rec in mon.hitBy do
				if player.Parent and now - rec.lastAt <= MC.aggroTime and rec.lastAt > victimAt then
					victim, victimAt = player, rec.lastAt
				end
			end
			if victim then
				for _, m in PetService.team(victim) do
					if MonsterCombat.alive(m.state) then
						if MonsterCombat.damagePet(m.state, mon.atk, now) then
							local sp = m.species
							Remotes.notify(victim, sp.name .. "이(가) 기절했어요! " .. Config.PET.faintTime .. "초 뒤에 일어나요")
						end
						PetService.publish(victim)
						break
					end
				end
				mon.nextAttack = now + mon.attackEvery
			end
		end
	end
end

-- 배회: 출현 지점 반경 안에서 천천히 걸어다님
local function wanderTick(dt: number)
	for _, mon in monsters do
		local to = mon.goal - mon.pos
		local step = MC.wanderSpeed * mon.size * dt
		if to.Magnitude <= step then
			mon.pos = mon.goal
			if math.random() < 0.3 then
				local g = randomPointNear(mon.spawn)
				mon.goal = Vector3.new(g.X, mon.pos.Y, g.Z)
			end
		else
			mon.pos += to.Unit * step
		end
		place(mon)
	end
end

local function spawnTick()
	for _, spawn in game:GetService("CollectionService"):GetTagged("MonsterSpawn") do
		if spawn:IsA("BasePart") and spawn:IsDescendantOf(workspace) then
			local zone = Util.zoneOf(spawn)
			local ready = (spawn:GetAttribute("NextSpawnAt") :: number?) or 0
			if os.clock() >= ready and countAt(spawn) < MC.perSpawn and countIn(zone) < (MC.zoneCap[zone] or 12) then
				spawnAt(spawn)
			end
		end
	end
end

function MonsterService.start()
	folder = Instance.new("Folder")
	folder.Name = "Monsters"
	folder.Parent = workspace

	Remotes.get("FocusMonster").OnServerEvent:Connect(function(player, id)
		if type(id) == "number" and monsters[id] then
			focus[player] = id
		end
	end)

	Remotes.get("PetSkill").OnServerEvent:Connect(function(player, slot)
		if type(slot) ~= "number" then
			return
		end
		local m = PetService.team(player)[slot]
		local root = Util.root(player)
		local now = os.clock()
		if not (m and root and MonsterCombat.alive(m.state)) then
			return
		end
		local skill = m.species.skill
		if not MonsterCombat.skillReady(m.skillAt, skill.cooldown, now) then
			return
		end
		local all = list()
		local target = MonsterCombat.pickTarget(all, root.Position, rangeOf(player), focus[player])
		if skill.kind == "burst" and not target then
			return -- 때릴 대상이 없으면 쿨타임을 쓰지 않음
		end
		local dmgs, heal = MonsterCombat.skillEffect(skill.kind, m.atk, target, all, root.Position)
		m.skillAt = now
		applyDamages(dmgs, player, m.entry.uid)
		if heal > 0 then
			for _, other in PetService.team(player) do
				if MonsterCombat.alive(other.state) then
					other.state.hp = math.min(other.state.maxHp, other.state.hp + other.state.maxHp * heal)
				end
			end
		end
		Remotes.sfx(player, "highfive")
		PetService.publish(player)
	end)

	Remotes.get("Stomp").OnServerEvent:Connect(function(player)
		local now = os.clock()
		local root = Util.root(player)
		if not root or now - (stompAt[player] or 0) < MC.stompCooldown then
			return
		end
		stompAt[player] = now
		local scale = scaleOf(player)
		local feet = root.Position - Vector3.new(0, 3 * scale, 0)
		local dmgs = MonsterCombat.stomp(list(), feet, scale, BossFight.damageFor(scale))
		if next(dmgs) then
			applyDamages(dmgs, player, nil)
			Remotes.sfx(player, "bossHit")
		end
	end)

	Remotes.get("Tame").OnServerEvent:Connect(function(player, offerId)
		local o = offers[player]
		if o and o.id == offerId and os.clock() <= o.expires then
			offers[player] = nil
			PetService.addPet(player, o.kind)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		focus[player] = nil
		offers[player] = nil
		stompAt[player] = nil
		petNextAttack[player] = nil
		for _, mon in monsters do
			mon.hitBy[player] = nil
		end
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.1)
			local now = os.clock()
			wanderTick(now - last)
			last = now
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.PET.tick)
			combatTick(os.clock())
		end
	end)
	task.spawn(function()
		while true do
			spawnTick()
			task.wait(1)
		end
	end)
end

return MonsterService
