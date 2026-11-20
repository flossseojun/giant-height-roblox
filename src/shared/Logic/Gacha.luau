-- 꾸미기 뽑기 계산 (순수 함수). 숫자·아이템은 Config.COSMETICS: 시작할 때 Gacha.setConfig(Config.COSMETICS)
local Gacha = {}
local C: any = nil
local byId: { [string]: any } = {}

export type State = { owned: { [string]: boolean }, equipped: { [string]: string }, pity: { [string]: number } }
export type Result = { id: string, rarity: string, dup: boolean, refund: number }

function Gacha.setConfig(cfg: any)
	C = cfg
	byId = {}
	for _, it in cfg.items do
		byId[it.id] = it
	end
end

local function cfg(): any
	assert(C, "Gacha.setConfig(Config.COSMETICS)를 먼저 불러야 해요")
	return C
end

local function isKind(kind: any): boolean
	return type(kind) == "string" and table.find(cfg().kinds, kind) ~= nil
end

function Gacha.item(id: any): any?
	cfg()
	return if type(id) == "string" then byId[id] else nil
end

function Gacha.rarity(r: number): string
	local rates = cfg().rates
	if r < rates.common then
		return "common"
	elseif r < rates.common + rates.rare then
		return "rare"
	end
	return "legendary"
end

function Gacha.newState(): State
	local pity = {}
	for _, k in cfg().kinds do
		pity[k] = 0
	end
	return { owned = {}, equipped = {}, pity = pity }
end

-- 저장된 값을 정리: 없는 아이템·잘못된 착용·이상한 천장 숫자 제거
function Gacha.clean(saved: any): State
	local s = Gacha.newState()
	if type(saved) ~= "table" then
		return s
	end
	if type(saved.owned) == "table" then
		for id, v in saved.owned do
			if v == true and Gacha.item(id) then
				s.owned[id] = true
			end
		end
	end
	if type(saved.equipped) == "table" then
		for kind, id in saved.equipped do
			local it = Gacha.item(id)
			if isKind(kind) and it and it.kind == kind and s.owned[id] then
				s.equipped[kind] = id
			end
		end
	end
	if type(saved.pity) == "table" then
		for _, k in cfg().kinds do
			local n = saved.pity[k]
			if type(n) == "number" and n >= 0 and n == n then
				s.pity[k] = math.min(math.floor(n), cfg().pity - 1)
			end
		end
	end
	return s
end

-- 상자 하나 열기 (r1: 등급 난수, r2: 아이템 난수). 코인 처리는 서버가 함.
function Gacha.open(s: State, kind: string, r1: number, r2: number): Result?
	if not isKind(kind) then
		return nil
	end
	local rarity = if s.pity[kind] >= cfg().pity - 1 then "legendary" else Gacha.rarity(r1)
	local pool = {}
	for _, it in cfg().items do
		if it.kind == kind and it.rarity == rarity then
			table.insert(pool, it)
		end
	end
	local it = pool[math.clamp(math.floor(r2 * #pool) + 1, 1, #pool)]
	s.pity[kind] = if rarity == "legendary" then 0 else s.pity[kind] + 1
	local dup = s.owned[it.id] == true
	s.owned[it.id] = true
	return { id = it.id, rarity = rarity, dup = dup, refund = if dup then cfg().refund else 0 }
end

-- 착용(id) / 해제(nil)
function Gacha.equip(s: State, kind: string, id: string?): boolean
	if not isKind(kind) then
		return false
	end
	if id == nil then
		s.equipped[kind] = nil
		return true
	end
	local it = Gacha.item(id)
	if not (it and it.kind == kind and s.owned[id :: string]) then
		return false
	end
	s.equipped[kind] = id
	return true
end

return Gacha
