-- 맵 곳곳(FoodSpawn 태그)에 성장 음식을 만들고, 먹으면 키를 더한다
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local FoodSpawner = require(ReplicatedStorage.Shared.Logic.FoodSpawner)
local Market = require(ReplicatedStorage.Shared.Logic.Market)
local Players = game:GetService("Players")
local Remotes = require(script.Parent.Remotes)
local HeightService = require(script.Parent.HeightService)
local Util = require(script.Parent.Util)

local FoodService = {}

local COLORS = {
	milk = Color3.fromRGB(255, 255, 255),
	eggbread = Color3.fromRGB(240, 200, 120),
	hotteok = Color3.fromRGB(190, 120, 60),
	corn = Color3.fromRGB(255, 220, 70),
	lotusdog = Color3.fromRGB(120, 170, 90),
	hanwoo = Color3.fromRGB(200, 70, 70),
	bibimbap = Color3.fromRGB(230, 150, 60),
	ginkgo = Color3.fromRGB(250, 210, 60),
	spring = Color3.fromRGB(150, 220, 255),
	starmilk = Color3.fromRGB(220, 230, 255),
	starcandy = Color3.fromRGB(255, 150, 220),
	meteor = Color3.fromRGB(255, 140, 60),
	golden_milk = Color3.fromRGB(255, 200, 40),
}

-- 오늘이 물맑은시장 장날인지 (한국 시간)
function FoodService.isMarketDay(): boolean
	return Market.isMarketDay(Market.kstDay(os.time()))
end

local folder = Instance.new("Folder")
folder.Name = "Foods"
folder.Parent = workspace

-- 음식 파트 하나 만들기 (우유 비에서도 씀)
function FoodService.makeFoodPart(food, size: number): Part
	local p = Instance.new("Part")
	p.Name = food.name
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(size, size, size)
	p.Color = COLORS[food.id] or Color3.new(1, 1, 1)
	p.Material = if food.golden then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanTouch = true
	p.CanQuery = false
	p.Anchored = true
	if food.golden then
		local s = Instance.new("Sparkles")
		s.SparkleColor = Color3.fromRGB(255, 230, 120)
		s.Parent = p
	end
	Util.billboard(p, food.name, if food.golden then Color3.fromRGB(255, 220, 80) else nil, size)
	return p
end

-- 먹을 수 있는 음식 파트 → 먹기 함수 (펫이 대신 먹을 때 씀)
local edible: { [BasePart]: (Player) -> () } = {}

function FoodService.tryEat(p: BasePart, player: Player)
	local fn = edible[p]
	if fn then
		fn(player)
	end
end

-- 지금 맵에 있는 음식 파트들
function FoodService.edibleParts(): { [BasePart]: any }
	return edible
end

-- 파트를 먹을 수 있게 연결: 한 명만 받고 onEaten 호출
function FoodService.makeEdible(p: BasePart, food, slot, onEaten: (Player) -> ())
	local function eat(player: Player)
		if not Util.root(player) or not slot.claim() then
			return
		end
		edible[p] = nil
		HeightService.add(player, food.gain, food.id)
		Remotes.sfx(player, if food.golden then "golden" else "eat")
		onEaten(player)
	end
	edible[p] = eat
	p.Destroying:Connect(function()
		edible[p] = nil
	end)
	p.Touched:Connect(function(hit)
		local player = Util.playerFromPart(hit)
		if player then
			eat(player)
		end
	end)
end

local function runSpawn(spawnPart: BasePart)
	local zone = Config.ZONES[Util.zoneOf(spawnPart)] or Config.ZONES[1]
	local size = math.max(spawnPart.Size.X, 1.5) * 1.2
	local slot = FoodSpawner.newSlot()
	local current: Part? = nil

	local function spawnOne()
		if not spawnPart.Parent then
			return
		end
		local food = FoodSpawner.pick(zone, math.random(), math.random(), Config.GOLDEN_CHANCE, Config.GOLDEN_MULT)
		if zone.id == 1 and FoodService.isMarketDay() then
			food.gain *= Config.MARKET_DAY_MULT
			food.name = food.name .. " ×" .. Config.MARKET_DAY_MULT
		end
		local p = FoodService.makeFoodPart(food, size)
		p.CFrame = spawnPart.CFrame
		slot.reset()
		FoodService.makeEdible(p, food, slot, function()
			p:Destroy()
			current = nil
			task.delay(Config.FOOD_RESPAWN, spawnOne)
		end)
		p.Parent = folder
		current = p
	end

	spawnPart.AncestryChanged:Connect(function()
		if not spawnPart:IsDescendantOf(workspace) and current then
			current:Destroy()
		end
	end)
	spawnOne()
end

function FoodService.start()
	-- 장날 알림 + 화면 배지용 표시
	task.spawn(function()
		while true do
			workspace:SetAttribute("MarketDay", FoodService.isMarketDay())
			task.wait(60)
		end
	end)
	Players.PlayerAdded:Connect(function(p)
		task.delay(8, function()
			if p.Parent and FoodService.isMarketDay() then
				Remotes.notify(p, "오늘은 물맑은시장 장날! 양평읍 음식 ×" .. Config.MARKET_DAY_MULT)
			end
		end)
	end)
	Util.eachTagged("FoodSpawn", function(inst)
		if inst:IsA("BasePart") then
			runSpawn(inst)
		end
	end)
end

return FoodService
