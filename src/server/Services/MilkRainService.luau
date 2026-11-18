-- 몇 분마다 한 구역에 우유 비를 내린다
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local MilkRain = require(ReplicatedStorage.Shared.Logic.MilkRain)
local FoodSpawner = require(ReplicatedStorage.Shared.Logic.FoodSpawner)
local FoodService = require(script.Parent.FoodService)
local Remotes = require(script.Parent.Remotes)
local Util = require(script.Parent.Util)

local MilkRainService = {}

local RADIUS = { 40, 80, 120, 160 } -- 구역별 비 내리는 범위(스터드)
local DROP_SIZE = { 2.5, 6, 12, 16 }

local folder = Instance.new("Folder")
folder.Name = "MilkRain"
folder.Parent = workspace

local function pickSpot(): BasePart?
	local spots = {}
	for _, s in CollectionService:GetTagged("MilkRainSpot") do
		if s:IsA("BasePart") and s:IsDescendantOf(workspace) then
			table.insert(spots, s)
		end
	end
	if #spots == 0 then
		return nil
	end
	return spots[math.random(1, #spots)]
end

local function rain(spot: BasePart)
	local zid = Util.zoneOf(spot)
	local zone = Config.ZONES[zid] or Config.ZONES[1]
	local food = { id = "milk", name = "우유", gain = MilkRain.dropGain(zone, Config.RAIN.mult), golden = false }
	local r = RADIUS[zid] or 40
	local size = DROP_SIZE[zid] or 2.5
	for _ = 1, Config.RAIN.count do
		local p = FoodService.makeFoodPart(food, size)
		local a = math.random() * math.pi * 2
		local d = math.sqrt(math.random()) * r
		p.Position = spot.Position + Vector3.new(math.cos(a) * d, 40 + math.random() * 40, math.sin(a) * d)
		p.Anchored = false
		p.CanCollide = true
		local slot = FoodSpawner.newSlot()
		FoodService.makeEdible(p, food, slot, function()
			p:Destroy()
		end)
		p.Parent = folder
		pcall(function()
			p:SetNetworkOwner(nil)
		end)
		task.delay(Config.RAIN.life, function()
			if p.Parent then
				p:Destroy()
			end
		end)
		task.wait(0.05)
	end
end

function MilkRainService.start()
	task.spawn(function()
		local t0 = os.clock()
		local warnedCycle, rainedCycle = -1, -1
		local spot: BasePart? = nil
		while true do
			task.wait(0.25)
			local elapsed = os.clock() - t0
			local interval = Config.RAIN.interval
			local phase = MilkRain.phase(elapsed, interval, Config.RAIN.warn)
			-- 경고는 다음 주기 번호로 셈 (비가 내릴 주기)
			local cycle = math.floor((elapsed + Config.RAIN.warn) / interval)
			if phase == "warning" and warnedCycle ~= cycle then
				warnedCycle = cycle
				spot = pickSpot()
				if spot then
					local zone = Config.ZONES[Util.zoneOf(spot)] or Config.ZONES[1]
					Remotes.notifyAll(Config.RAIN.warn .. "초 뒤 " .. zone.name .. "에 우유 비가 내려요!")
					Remotes.sfxAll("rainWarn")
				end
			elseif phase == "raining" and rainedCycle ~= math.floor(elapsed / interval) then
				rainedCycle = math.floor(elapsed / interval)
				if spot and spot.Parent then
					Remotes.notifyAll("우유 비다!!")
					Remotes.sfxAll("rainStart")
					task.spawn(rain, spot)
				end
				spot = nil
			end
		end
	end)
end

return MilkRainService
