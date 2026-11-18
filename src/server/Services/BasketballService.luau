-- 농구: 공 받기 → 화면 탭으로 던지기 → 골대 통과하면 키가 큰다
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

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

local throwRemote = Remotes.get("ThrowBall")

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

local function giveBall(player: Player, rack: BasePart)
	if balls[player] then
		return
	end
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
	ball.Size = Vector3.one * 1.6 * scale
	ball.Color = Color3.fromRGB(240, 120, 40)
	ball.Material = Enum.Material.SmoothPlastic
	ball.Massless = true
	ball.CanCollide = false
	ball.CFrame = hand.CFrame
	ball:SetAttribute("Owner", player.UserId)
	ball:SetAttribute("Zone", Util.zoneOf(rack))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = ball
	weld.Parent = ball
	ball.Parent = folder
	balls[player] = ball
	player:SetAttribute("HasBall", true)
	Remotes.notify(player, "화면을 탭(클릭)한 방향으로 던져요!")
end

local function throw(player: Player, dir: any)
	local ball = balls[player]
	local root = Util.root(player)
	if not (ball and ball.Parent and root) then
		return
	end
	if typeof(dir) ~= "Vector3" or dir ~= dir or dir.Magnitude < 1e-3 or dir.Magnitude > 1e6 then
		return
	end
	local scale = Growth.heightToScale(HeightService.get(player), Config.SCALE_K, Config.MAX_SCALE)
	local d = (dir.Unit + Vector3.new(0, 0.35, 0)).Unit -- 살짝 위로 포물선
	local weld = ball:FindFirstChildOfClass("WeldConstraint")
	if weld then
		weld:Destroy()
	end
	local _, size = (player.Character :: Model):GetBoundingBox()
	ball.Massless = false
	ball.CanCollide = true
	ball.CFrame = CFrame.new(root.Position + Vector3.new(0, size.Y * 0.45, 0) + d * ball.Size.X)
	ball.Parent = folder
	pcall(function()
		ball:SetNetworkOwner(nil)
	end)
	ball.AssemblyLinearVelocity = d * 70 * math.sqrt(scale)
	balls[player] = nil
	player:SetAttribute("HasBall", false)
	Debris:AddItem(ball, Config.HOOP.ballLife)
end

local function setupHoop(sensor: Instance)
	if not sensor:IsA("BasePart") then
		return
	end
	sensor.Touched:Connect(function(hit)
		if hit.Name ~= "Basketball" or hit:GetAttribute("Scored") then
			return
		end
		if hit.AssemblyLinearVelocity.Y >= 0 then
			return -- 아래에서 위로 통과한 건 골 아님
		end
		local owner = Players:GetPlayerByUserId(hit:GetAttribute("Owner") or 0)
		if not owner then
			return
		end
		local now = os.clock()
		if now - (lastGoal[owner] or 0) < Config.HOOP.cooldown then
			return
		end
		lastGoal[owner] = now
		hit:SetAttribute("Scored", true)
		local zone = Config.ZONES[Util.zoneOf(sensor)] or Config.ZONES[1]
		HeightService.add(owner, Zones.bestGain(zone) * Config.HOOP.mult, "hoop")
		Remotes.notify(owner, "골!!")
		Remotes.sfx(owner, "goal")
		local fx = Instance.new("ParticleEmitter")
		fx.Rate = 0
		fx.Speed = NumberRange.new(10, 20)
		fx.Parent = sensor
		fx:Emit(30)
		Debris:AddItem(fx, 2)
		Debris:AddItem(hit, 1)
	end)
end

local function setupRack(rack: Instance)
	if not rack:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "공 받기"
	prompt.ObjectText = "농구공"
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = math.max(12, rack.Size.Magnitude * 2)
	prompt.Parent = rack
	prompt.Triggered:Connect(function(player)
		giveBall(player, rack)
	end)
end

function BasketballService.start()
	Util.eachTagged("Hoop", setupHoop)
	Util.eachTagged("BallRack", setupRack)
	throwRemote.OnServerEvent:Connect(throw)
	Players.PlayerRemoving:Connect(function(p)
		dropBall(p)
		lastGoal[p] = nil
	end)
	Players.PlayerAdded:Connect(function(p)
		p.CharacterRemoving:Connect(function()
			dropBall(p)
		end)
	end)
	for _, p in Players:GetPlayers() do
		p.CharacterRemoving:Connect(function()
			dropBall(p)
		end)
	end
end

return BasketballService
