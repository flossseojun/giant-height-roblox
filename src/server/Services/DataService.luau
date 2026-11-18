-- 키 저장/불러오기 (DataStore)
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SaveGuard = require(ReplicatedStorage.Shared.Logic.SaveGuard)
local Remotes = require(script.Parent.Remotes)

local DataService = {}

local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore("GiantHeight_v1")
end)

local guards: { [Player]: any } = {}
local extras: { [Player]: { [string]: any } } = {}
local getHeight: ((Player) -> number)? = nil

local function key(player: Player): string
	return "u_" .. player.UserId
end

-- HeightService가 현재 키를 알려 줄 함수를 등록
function DataService.setHeightGetter(fn: (Player) -> number)
	getHeight = fn
end

-- 클라이언트 화면이 준비될 시간을 주고 알림
local function warnLater(player: Player)
	task.delay(4, function()
		if player.Parent then
			Remotes.notify(player, "저장 불러오기 실패 — 이번 판 기록은 저장되지 않아요")
		end
	end)
end

function DataService.load(player: Player): (boolean, { height: number })
	local guard = SaveGuard.new()
	guards[player] = guard
	if not store then
		guard.markLoaded(false)
		extras[player] = {}
		warnLater(player)
		return false, { height = Config.START_HEIGHT }
	end
	local data
	local ok = false
	for attempt = 1, 3 do
		ok = pcall(function()
			data = (store :: DataStore):GetAsync(key(player))
		end)
		if ok then
			break
		end
		task.wait(attempt)
	end
	guard.markLoaded(ok)
	extras[player] = if type(data) == "table" and type(data.extra) == "table" then data.extra else {}
	if not ok then
		warnLater(player)
	end
	return ok, { height = SaveGuard.cleanHeight(data, Config.START_HEIGHT) }
end

function DataService.save(player: Player)
	local guard = guards[player]
	if not (store and guard and guard.canSave() and getHeight) then
		return
	end
	local h = (getHeight :: (Player) -> number)(player)
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key(player), function()
			return { height = h, extra = extras[player] or {}, v = 1 }
		end)
	end)
	if not ok then
		warn("[DataService] 저장 실패", player.Name, err)
	end
end

-- 키 말고 저장할 것들 (예: extra.pet). 바꾸면 다음 저장 때 같이 저장됨
function DataService.extra(player: Player): { [string]: any }
	local e = extras[player]
	if not e then
		e = {}
		extras[player] = e
	end
	return e
end

function DataService.forget(player: Player)
	guards[player] = nil
	extras[player] = nil
end

function DataService.start(players: Players)
	-- 자동 저장
	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE)
			for _, p in players:GetPlayers() do
				task.spawn(DataService.save, p)
			end
		end
	end)
	-- 서버가 꺼질 때 모두 저장
	game:BindToClose(function()
		local pending = 0
		for _, p in players:GetPlayers() do
			pending += 1
			task.spawn(function()
				DataService.save(p)
				pending -= 1
			end)
		end
		local t = os.clock()
		while pending > 0 and os.clock() - t < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
