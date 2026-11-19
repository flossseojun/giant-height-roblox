-- 농구 덩크: 공을 받아 들고, 점프해서 림에 넣으면 키가 큰다
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(ReplicatedStorage.Shared.Logic.Zones)
local Growth = require(ReplicatedStorage.Shared.Logic.Growth)
local HeightService = require(script.Parent.HeightService)
local Remotes = require(script.Parent.Remotes)
local Util = require(script.Parent.Util)

local BasketballService = {}

local balls: { [Player]: BasePart } = {}
local lastGoal: { [Player]: number } = {}

local folder = Instance.new("Folder")
folder.Name = "Balls"
folder.Parent = workspace

local function dropBall(player: Player)
	local b = balls[player]
	balls[player] = nil
	if b and b.Parent then
		b:Destroy()
	end
	if player.Parent then
		player:SetAttribute("HasBall", false)
	end
end

local function giveBall(player: Player)
	local char = player.Character
	local root = Util.root(player)
	if not (char and root) then
		return
	end
	local hand = (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm") or root) :: BasePart
	local scale = Growth.heightToScale(HeightService.get(player), Config.SCALE_K, Config.MAX_SCALE)
	local ball = Instance.new("Part")
	ball.Name = "Basketball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * 1.4 * scale
	ball.Color = Color3.fromRGB(240, 120, 40)
	ball.Material = Enum.Material.SmoothPlastic
	ball.Massless = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = ball
	weld.Parent = ball
	ball.Parent = folder
	balls[player] = ball
	player:SetAttribute("HasBall", true)
	Remotes.notify(player, "공을 들고 점프해서 림에 넣어요! (덩크)")
end

-- 공이 림 근처에 있나 (센서 상자를 위아래로 넉넉하게)
local function inHoop(sensor: BasePart, ball: BasePart): boolean
	local rel = sensor.CFrame:PointToObjectSpace(ball.Position)
	local h = sensor.Size / 2
	local r = ball.Size.X / 2
	local tol = sensor.Size.X / 2 -- 위아래 허용 범위
	return math.abs(rel.X) <= h.X + r and math.abs(rel.Z) <= h.Z + r and math.abs(rel.Y) <= h.Y + tol
end

local function dunk(player: Player, sensor: BasePart)
	local now = os.clock()
	if now - (lastGoal[player] or 0) < Config.HOOP.cooldown then
		return
	end
	lastGoal[player] = now
	local zone = Config.ZONES[Util.zoneOf(sensor)] or Config.ZONES[1]
	HeightService.add(player, Zones.bestGain(zone) * Config.HOOP.mult, "hoop")
	Remotes.notify(player, "덩크!!")
	Remotes.sfx(player, "goal")
	local fx = Instance.new("ParticleEmitter")
	fx.Rate = 0
	fx.Speed = NumberRange.new(10, 20)
	fx.Parent = sensor
	fx:Emit(30)
	Debris:AddItem(fx, 2)
end

local function setupRack(rack: Instance)
	if not rack:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "공 받기 / 내려놓기"
	prompt.ObjectText = "농구공"
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = math.max(12, rack.Size.Magnitude * 2)
	prompt.Parent = rack
	prompt.Triggered:Connect(function(player)
		if balls[player] then
			dropBall(player)
		else
			giveBall(player)
		end
	end)
end

function BasketballService.start()
	Util.eachTagged("BallRack", setupRack)
	Players.PlayerRemoving:Connect(function(p)
		dropBall(p)
		lastGoal[p] = nil
	end)
	local function watch(p: Player)
		p.CharacterRemoving:Connect(function()
			dropBall(p)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	-- 공 든 사람이 "공중에서" 림에 공을 넣었는지 0.1초마다 확인
	task.spawn(function()
		while true do
			task.wait(0.1)
			for player, ball in balls do
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if ball.Parent and hum and hum.FloorMaterial == Enum.Material.Air then
					for _, sensor in CollectionService:GetTagged("Hoop") do
						if sensor:IsA("BasePart") and sensor:IsDescendantOf(workspace) and inHoop(sensor, ball) then
							dunk(player, sensor)
							break
						end
					end
				end
			end
		end
	end)
end

return BasketballService
