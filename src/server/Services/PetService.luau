-- 펫: 보유·팀(최대 3)·레벨·진화, 성장 배율, 근처 음식 자동 줍기
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.Config)
local PetProgress = require(ReplicatedStorage.Shared.Logic.PetProgress)
local PetData = require(ReplicatedStorage.Shared.Logic.PetData)
local MonsterCombat = require(ReplicatedStorage.Shared.Logic.MonsterCombat)
local Quests = require(ReplicatedStorage.Shared.Logic.Quests)
local Growth = require(ReplicatedStorage.Shared.Logic.Growth)
local HeightService = require(script.Parent.HeightService)
local DataService = require(script.Parent.DataService)
local FoodService = require(script.Parent.FoodService)
local Remotes = require(script.Parent.Remotes)
local Util = require(script.Parent.Util)

PetProgress.setConfig(Config.PET)
PetData.setConfig(Config.PET)
MonsterCombat.setConfig(Config.PET)

local SPECIES = Config.PET_SPECIES

export type Member = {
	entry: PetData.Entry,
	species: any,
	state: MonsterCombat.PetState,
	atk: number,
	skillAt: number?,
}

local PetService = {}
local datas: { [Player]: PetData.Data } = {}
local teams: { [Player]: { Member } } = {}

function PetService.data(player: Player): PetData.Data?
	return datas[player]
end

function PetService.team(player: Player): { Member }
	return teams[player] or {}
end

local function save(player: Player)
	local d = datas[player]
	if d then
		DataService.extra(player).pets = d
	end
end

-- 팀 목록을 다시 만든다 (체력 비율·필살기 쿨타임은 같은 펫이면 유지)
local function rebuild(player: Player)
	local d = datas[player]
	if not d then
		return
	end
	local old = {}
	for _, m in PetService.team(player) do
		old[m.entry.uid] = m
	end
	local list = {}
	for _, e in PetData.teamEntries(d) do
		local sp = SPECIES[e.kind]
		local maxHp = PetProgress.stat(sp.hp, e.level)
		local st = MonsterCombat.newPetState(maxHp)
		local prev = old[e.uid]
		if prev then
			st.hp = if prev.state.hp <= 0 then 0 else maxHp * (prev.state.hp / prev.state.maxHp)
			st.reviveAt = prev.state.reviveAt
		end
		table.insert(list, {
			entry = e,
			species = sp,
			state = st,
			atk = PetProgress.stat(sp.atk, e.level),
			skillAt = prev and prev.skillAt,
		})
	end
	teams[player] = list
	local members = {}
	for _, m in list do
		table.insert(members, { species = m.species, level = m.entry.level })
	end
	local mult = PetProgress.teamBonus(members)
	HeightService.setPetMult(player, mult)
end

-- 화면용 정보: 플레이어 속성(JSON)으로 내보냄
function PetService.publish(player: Player)
	local d = datas[player]
	if not d then
		return
	end
	local team = {}
	for _, m in PetService.team(player) do
		table.insert(team, {
			uid = m.entry.uid,
			kind = m.entry.kind,
			level = m.entry.level,
			stage = PetProgress.stage(m.entry.level),
			hp = math.ceil(m.state.hp),
			maxHp = math.ceil(m.state.maxHp),
			skillLeft = if m.skillAt then math.max(0, m.skillAt + m.species.skill.cooldown - os.clock()) else 0,
		})
	end
	local owned = {}
	for _, e in d.owned do
		table.insert(owned, {
			uid = e.uid,
			kind = e.kind,
			level = e.level,
			xp = e.xp,
			need = PetProgress.xpToNext(e.level),
			stage = PetProgress.stage(e.level),
		})
	end
	player:SetAttribute("PetTeam", HttpService:JSONEncode(team))
	player:SetAttribute("PetOwned", HttpService:JSONEncode(owned))
end

function PetService.giveXp(player: Player, uids: { number }?, amount: number)
	local d = datas[player]
	if not d or amount <= 0 then
		return
	end
	local targets = uids or d.team
	local changed = false
	for _, uid in targets do
		local e = PetData.find(d, uid)
		if e then
			local oldStage = PetProgress.stage(e.level)
			local lv, xp, up = PetProgress.addXp(e.level, e.xp, amount)
			e.level, e.xp = lv, xp
			if up > 0 then
				changed = true
				local sp = SPECIES[e.kind]
				local stage = PetProgress.stage(lv)
				if stage > oldStage then
					Remotes.notify(player, sp.stages[oldStage] .. "이(가) " .. sp.stages[stage] .. "(으)로 진화했어요!")
					Remotes.sfx(player, "victory")
				else
					Remotes.notify(player, sp.stages[stage] .. " 레벨 " .. lv .. "!")
					Remotes.sfx(player, "goal")
				end
			end
		end
	end
	if changed then
		rebuild(player)
	end
	save(player)
	PetService.publish(player)
end

function PetService.addPet(player: Player, kind: string): boolean
	local d = datas[player]
	local sp = SPECIES[kind]
	if not (d and sp) then
		return false
	end
	local uid = PetData.add(d, kind, SPECIES)
	if not uid then
		Remotes.notify(player, "펫이 가득 찼어요 (최대 " .. Config.PET.maxOwned .. "마리)")
		return false
	end
	-- 팀에 빈자리가 있으면 바로 데려감
	if #d.team < Config.PET.maxTeam then
		table.insert(d.team, uid)
		rebuild(player)
	end
	Remotes.notify(player, "새 펫 " .. sp.name .. "을(를) 얻었어요! '펫' 버튼에서 팀을 짜 보세요")
	Remotes.sfx(player, "victory")
	save(player)
	PetService.publish(player)
	return true
end

local function onPlayer(player: Player)
	-- HeightService가 저장을 불러올 때까지 기다림
	local t = os.clock()
	while player.Parent and player:GetAttribute("Height") == nil and os.clock() - t < 30 do
		task.wait(0.2)
	end
	if not player.Parent then
		return
	end
	datas[player] = PetData.migrate(DataService.extra(player), SPECIES, HeightService.best(player))
	save(player)
	rebuild(player)
	PetService.publish(player)
end

local function pickup(player: Player)
	local root = Util.root(player)
	local team = teams[player]
	if not (root and team and #team > 0) then
		return
	end
	local members = {}
	for _, m in team do
		table.insert(members, { species = m.species, level = m.entry.level })
	end
	local _, radius = PetProgress.teamBonus(members)
	local scale = Growth.heightToScale(HeightService.get(player), Config.SCALE_K, Config.MAX_SCALE)
	local r = radius * scale
	for part in FoodService.edibleParts() do
		if part.Parent and (part.Position - root.Position).Magnitude <= r then
			FoodService.tryEat(part, player)
			return -- 한 번에 하나씩 (펫이 "주워 오는" 느낌)
		end
	end
end

local FOOD_KINDS = { food = true, golden_milk = true, rainmilk = true }

function PetService.start()
	Remotes.get("SetTeam").OnServerEvent:Connect(function(player, uids)
		local d = datas[player]
		if d and PetData.setTeam(d, uids) then
			rebuild(player)
			save(player)
			PetService.publish(player)
		end
	end)
	-- 음식을 먹으면 팀 펫 전원 경험치
	HeightService.onGain(function(player, _amount, source)
		if FOOD_KINDS[Quests.kindOf(source)] then
			local zone = HeightService.currentZone(player)
			PetService.giveXp(player, nil, Config.PET.foodXp * (Config.PET.zoneK[zone] or 1))
		end
	end)
	-- 키로 열리는 펫
	HeightService.onChanged(function(player, _old, new)
		local d = datas[player]
		if not d then
			return
		end
		for _, kind in PetData.unlockByHeight(d, SPECIES, new) do
			Remotes.notify(player, "새 펫 " .. SPECIES[kind].name .. " 획득! 왼쪽 '펫' 버튼에서 팀에 넣어 보세요")
			save(player)
			PetService.publish(player)
		end
	end)
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		datas[player] = nil
		teams[player] = nil
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayer, p)
	end
	task.spawn(function()
		while true do
			task.wait(0.4)
			for _, p in Players:GetPlayers() do
				task.spawn(pickup, p)
			end
		end
	end)
end

return PetService
