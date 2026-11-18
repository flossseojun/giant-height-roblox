-- 일일 미션: 성장 출처를 세어 진행도를 올리고, 깨면 보상
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Quests = require(ReplicatedStorage.Shared.Logic.Quests)
local Zones = require(ReplicatedStorage.Shared.Logic.Zones)
local HeightService = require(script.Parent.HeightService)
local DataService = require(script.Parent.DataService)
local Remotes = require(script.Parent.Remotes)

local QuestService = {}

local stateRemote = Remotes.get("QuestState")

local function today()
	local day = Quests.dayKey(os.time())
	return day, Quests.forDay(day, Config.QUESTS.pool, Config.QUESTS.perDay)
end

local function state(player: Player)
	local extra = DataService.extra(player)
	if type(extra.quests) ~= "table" then
		extra.quests = {}
	end
	return extra.quests
end

local function push(player: Player)
	local day, list = today()
	local st = state(player)
	Quests.record(st, list, day, "__none__", 0) -- 날짜가 바뀌었으면 초기화
	local out = {}
	for i, q in list do
		table.insert(out, { name = q.name, count = q.count, progress = st.progress[i] or 0, done = st.done[i] == true })
	end
	stateRemote:FireClient(player, out)
end

local function rewardBase(player: Player): number
	local z = Zones.highestUnlocked(HeightService.get(player), Config.ZONES)
	return Zones.bestGain(Config.ZONES[z])
end

-- 다른 서비스가 직접 기록할 때 (예: 하이파이브)
function QuestService.record(player: Player, kind: string, amount: number?)
	if player:GetAttribute("Height") == nil then
		return
	end
	local day, list = today()
	local st = state(player)
	local wasAll = Quests.allDone(st, list)
	local finished = Quests.record(st, list, day, kind, amount or 1)
	for _, i in finished do
		Remotes.notify(player, "미션 완료: " .. list[i].name .. "!")
		HeightService.add(player, rewardBase(player) * Config.QUESTS.reward, "quest")
	end
	if not wasAll and Quests.allDone(st, list) then
		Remotes.notify(player, "오늘의 미션 모두 완료! 보너스!")
		HeightService.add(player, rewardBase(player) * Config.QUESTS.allBonus, "quest")
		Remotes.sfx(player, "victory")
	end
	push(player)
end

function QuestService.start()
	HeightService.onGain(function(player, _amount, source)
		local kind = Quests.kindOf(source)
		if kind ~= "debug" and kind ~= "quest" then
			QuestService.record(player, kind, 1)
			-- 황금 우유·우유 비 우유도 "음식"으로 같이 셈
			if kind == "golden_milk" or kind == "rainmilk" then
				QuestService.record(player, "food", 1)
			end
		end
	end)
	local function onPlayer(p: Player)
		local t = os.clock()
		while p.Parent and p:GetAttribute("Height") == nil and os.clock() - t < 30 do
			task.wait(0.5)
		end
		if p.Parent then
			push(p)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayer, p)
	end
	-- 자정에 미션이 바뀌면 화면도 갱신
	task.spawn(function()
		local last = Quests.dayKey(os.time())
		while true do
			task.wait(30)
			local now = Quests.dayKey(os.time())
			if now ~= last then
				last = now
				for _, p in Players:GetPlayers() do
					push(p)
				end
				Remotes.notifyAll("새로운 오늘의 미션이 나왔어요!")
			end
		end
	end)
end

return QuestService
