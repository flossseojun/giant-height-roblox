-- 맵 곳곳(FoodSpawn 태그)에 성장 음식을 만들고, 먹으면 키를 더한다
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local FoodSpawner = require(ReplicatedStorage.Shared.Logic.FoodSpawner)
local HeightService = require(script.Parent.HeightService)
local Util = require(script.Parent.Util)

local FoodService = {}

local COLORS = {
	anchovy = Color3.fromRGB(170, 200, 220),
	milk = Color3.fromRGB(255, 255, 255),
	egg = Color3.fromRGB(255, 235, 180),
	soymilk = Color3.fromRGB(240, 225, 170),
	cheese = Color3.fromRGB(255, 205, 60),
	chicken = Color3.fromRGB(240, 190, 150),
	starcandy = Color3.fromRGB(255, 150, 220),
	cloudmilk = Color3.fromRGB(200, 235, 255),
	rainbowegg = Color3.fromRGB(180, 140, 255),
	golden_milk = Color3.fromRGB(255, 200, 40),
}

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

-- 파트를 먹을 수 있게 연결: 한 명만 받고 onEaten 호출
function FoodService.makeEdible(p: BasePart, food, slot, onEaten: (Player) -> ())
	p.Touched:Connect(function(hit)
		local player = Util.playerFromPart(hit)
		if not player or not Util.root(player) then
			return
		end
		if not slot.claim() then
			return
		end
		HeightService.add(player, food.gain, food.id)
		onEaten(player)
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
	Util.eachTagged("FoodSpawn", function(inst)
		if inst:IsA("BasePart") then
			runSpawn(inst)
		end
	end)
end

return FoodService
