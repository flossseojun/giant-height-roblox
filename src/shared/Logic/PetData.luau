-- 펫 보유 목록·팀·저장 변환 (순수 함수)
-- Data = { owned = { Entry }, team = { uid }, nextId }, Entry = { uid, kind, level, xp }
local PetData = {}
local P: any = nil

export type Entry = { uid: number, kind: string, level: number, xp: number }
export type Data = { owned: { Entry }, team: { number }, nextId: number }

function PetData.setConfig(cfg: any)
	P = cfg
end

local function cfg(): any
	assert(P, "PetData.setConfig(Config.PET)를 먼저 불러야 해요")
	return P
end

function PetData.find(d: Data, uid: any): Entry?
	for _, e in d.owned do
		if e.uid == uid then
			return e
		end
	end
	return nil
end

local function owns(d: Data, kind: string): boolean
	for _, e in d.owned do
		if e.kind == kind then
			return true
		end
	end
	return false
end

function PetData.add(d: Data, kind: string, species: any?): number?
	if #d.owned >= cfg().maxOwned or type(kind) ~= "string" then
		return nil
	end
	if species and not species[kind] then
		return nil
	end
	local uid = d.nextId
	d.nextId += 1
	table.insert(d.owned, { uid = uid, kind = kind, level = 1, xp = 0 })
	return uid
end

function PetData.setTeam(d: Data, uids: any): boolean
	if type(uids) ~= "table" or #uids > cfg().maxTeam then
		return false
	end
	local seen = {}
	local clean = {}
	for i = 1, #uids do
		local u = uids[i]
		if seen[u] or not PetData.find(d, u) then
			return false
		end
		seen[u] = true
		table.insert(clean, u)
	end
	d.team = clean
	return true
end

function PetData.teamEntries(d: Data): { Entry }
	local out = {}
	for _, u in d.team do
		local e = PetData.find(d, u)
		if e then
			table.insert(out, e)
		end
	end
	return out
end

-- 키로 열리는 종 중 아직 없는 것을 넣고, 넣은 종 목록을 돌려줌
function PetData.unlockByHeight(d: Data, species: any, height: number): { string }
	local added = {}
	local ids = {}
	for id, s in species do
		if s.how == "height" then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		return species[a].minHeight < species[b].minHeight
	end)
	for _, id in ids do
		if height >= species[id].minHeight and not owns(d, id) then
			if PetData.add(d, id) then
				table.insert(added, id)
			end
		end
	end
	return added
end

-- 저장된 extra에서 Data를 만든다. 예전 저장(extra.pet = "otter")도 변환.
function PetData.migrate(extra: { [string]: any }, species: any, bestHeight: number): Data
	local saved = extra.pets
	if type(saved) == "table" and type(saved.owned) == "table" then
		local d: Data = { owned = {}, team = {}, nextId = 1 }
		local maxUid = 0
		for _, e in saved.owned do
			if type(e) == "table" and type(e.uid) == "number" and species[e.kind] and #d.owned < cfg().maxOwned then
				local lv = math.clamp(math.floor(tonumber(e.level) or 1), 1, cfg().maxLevel)
				table.insert(d.owned, { uid = e.uid, kind = e.kind, level = lv, xp = math.max(0, tonumber(e.xp) or 0) })
				maxUid = math.max(maxUid, e.uid)
			end
		end
		d.nextId = math.max(tonumber(saved.nextId) or 1, maxUid + 1)
		if type(saved.team) == "table" then
			for _, u in saved.team do
				if PetData.find(d, u) and #d.team < cfg().maxTeam and not table.find(d.team, u) then
					table.insert(d.team, u)
				end
			end
		end
		PetData.unlockByHeight(d, species, bestHeight)
		return d
	end
	local d: Data = { owned = {}, team = {}, nextId = 1 }
	PetData.unlockByHeight(d, species, bestHeight)
	local want = if type(extra.pet) == "string" and species[extra.pet] then extra.pet else "cat"
	for _, e in d.owned do
		if e.kind == want then
			d.team = { e.uid }
		end
	end
	if #d.team == 0 and d.owned[1] then
		d.team = { d.owned[1].uid }
	end
	return d
end

return PetData
