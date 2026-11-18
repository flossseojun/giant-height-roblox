-- 일일 미션: 날짜마다 모두에게 같은 미션 3개
local Quests = {}

export type Quest = { kind: string, count: number, name: string }

-- 한국 시간 기준 날짜 번호
function Quests.dayKey(unixTime: number): number
	return math.floor((math.floor(unixTime) + 9 * 3600) / 86400)
end

-- 성장 출처(source) → 미션 종류
local SPECIAL = { golden_milk = true, rainmilk = true, hoop = true, bar = true, bed = true, boss = true, star = true,
	highfive = true, debug = true, quest = true }
function Quests.kindOf(source: string): string
	if SPECIAL[source] then
		return source
	end
	return "food"
end

-- 날짜로 섞어서 서로 다른 n개 고르기 (모두에게 같음)
function Quests.forDay(day: number, pool: { Quest }, n: number): { Quest }
	local seed = (day * 2654435761) % 4294967296
	local function rand(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local idx = {}
	for i = 1, #pool do
		idx[i] = i
	end
	for i = #idx, 2, -1 do
		local j = math.floor(rand() * i) + 1
		idx[i], idx[j] = idx[j], idx[i]
	end
	local out = {}
	for i = 1, math.min(n, #pool) do
		table.insert(out, pool[idx[i]])
	end
	return out
end

-- state(저장됨) = { day, progress = {}, done = {} }. 방금 완료된 미션 번호들을 돌려줌
function Quests.record(state, list: { Quest }, day: number, kind: string, amount: number): { number }
	if state.day ~= day or type(state.progress) ~= "table" or type(state.done) ~= "table" then
		state.day = day
		state.progress = {}
		state.done = {}
		for i = 1, #list do
			state.progress[i] = 0
			state.done[i] = false
		end
	end
	local finished = {}
	for i, q in list do
		if q.kind == kind and not state.done[i] then
			state.progress[i] = math.min(q.count, (state.progress[i] or 0) + amount)
			if state.progress[i] >= q.count then
				state.done[i] = true
				table.insert(finished, i)
			end
		end
	end
	return finished
end

function Quests.allDone(state, list: { Quest }): boolean
	if type(state.done) ~= "table" then
		return false
	end
	for i = 1, #list do
		if not state.done[i] then
			return false
		end
	end
	return true
end

return Quests
