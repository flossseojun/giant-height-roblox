-- 몬스터 전투 계산 (순수 함수). 위치는 .X/.Z를 가진 값(Vector3 또는 표), 거리는 수평 거리.
local MonsterCombat = {}
local P: any = nil

export type PetState = { hp: number, maxHp: number, reviveAt: number? }
type Mon = { id: any, pos: any, hp: number }

function MonsterCombat.setConfig(cfg: any)
	P = cfg
end

local function cfg(): any
	assert(P, "MonsterCombat.setConfig(Config.PET)를 먼저 불러야 해요")
	return P
end

local function dist(a: any, b: any): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

function MonsterCombat.pickTarget(monsters: { Mon }, origin: any, range: number, focusId: any?): any?
	if focusId ~= nil then
		for _, m in monsters do
			if m.id == focusId and m.hp > 0 and dist(m.pos, origin) <= range * cfg().focusMult then
				return m.id
			end
		end
	end
	local best, bestD = nil, math.huge
	for _, m in monsters do
		if m.hp > 0 then
			local d = dist(m.pos, origin)
			if d <= range and d < bestD then
				best, bestD = m.id, d
			end
		end
	end
	return best
end

function MonsterCombat.newPetState(maxHp: number): PetState
	return { hp = maxHp, maxHp = maxHp, reviveAt = nil }
end

function MonsterCombat.alive(s: PetState): boolean
	return s.hp > 0
end

-- 이번 공격으로 기절했으면 true
function MonsterCombat.damagePet(s: PetState, dmg: number, now: number): boolean
	if s.hp <= 0 or dmg <= 0 then
		return false
	end
	s.hp = math.max(0, s.hp - dmg)
	if s.hp <= 0 then
		s.reviveAt = now + cfg().faintTime
		return true
	end
	return false
end

-- 지금 회복했으면 true
function MonsterCombat.tickRevive(s: PetState, now: number): boolean
	if s.hp <= 0 and s.reviveAt and now >= s.reviveAt then
		s.hp = s.maxHp
		s.reviveAt = nil
		return true
	end
	return false
end

function MonsterCombat.skillReady(last: number?, cooldown: number, now: number): boolean
	return last == nil or now - last >= cooldown
end

-- → 몬스터별 데미지, 팀 회복 비율
function MonsterCombat.skillEffect(kind: string, atk: number, target: any?, monsters: { Mon }, origin: any): ({ [any]: number }, number)
	local out = {}
	if kind == "burst" then
		for _, m in monsters do
			if m.id == target and m.hp > 0 then
				out[m.id] = 5 * atk
			end
		end
	elseif kind == "aoe" then
		for _, m in monsters do
			if m.hp > 0 and dist(m.pos, origin) <= 10 then
				out[m.id] = 2 * atk
			end
		end
	elseif kind == "heal" then
		return out, 0.4
	end
	return out, 0
end

-- 거인 밟기: 반경 3·scale 안의 살아 있는 몬스터에 damage
function MonsterCombat.stomp(monsters: { Mon }, at: any, scale: number, damage: number): { [any]: number }
	local out = {}
	for _, m in monsters do
		if m.hp > 0 and dist(m.pos, at) <= 3 * scale then
			out[m.id] = damage
		end
	end
	return out
end

function MonsterCombat.monsterStats(sp: any, zoneK: number): (number, number, number)
	return sp.monster.hp * zoneK, sp.monster.atk * zoneK, sp.monster.xp
end

function MonsterCombat.tameRoll(chance: number, r: number): boolean
	return r < chance
end

return MonsterCombat
