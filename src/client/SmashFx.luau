-- 건물이 무너질 때 연출: 잔해 조각이 튀었다 떨어지고 먼지, 가까우면 화면 흔들림
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local SoundFx = require(script.Parent.SoundFx)

local SmashFx = {}
local player = Players.LocalPlayer

local function burst(cf: CFrame, size: Vector3, color: Color3)
	local folder = workspace.CurrentCamera
	local base = cf.Position - Vector3.new(0, size.Y / 2, 0)
	local chunk = math.clamp(math.min(size.X, size.Z) / 6, 0.6, 12)
	for i = 1, Config.SMASH.debris do
		local p = Instance.new("Part")
		p.Size = Vector3.new(chunk, chunk * 0.7, chunk) * (0.6 + math.random() * 0.6)
		p.Color = color:Lerp(Color3.fromRGB(110, 105, 95), math.random() * 0.5)
		p.Material = Enum.Material.Slate
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		local a = (i / Config.SMASH.debris) * math.pi * 2
		local start = base + Vector3.new(math.cos(a) * size.X * 0.25, size.Y * (0.3 + math.random() * 0.5), math.sin(a) * size.Z * 0.25)
		p.CFrame = CFrame.new(start) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		p.AssemblyLinearVelocity = Vector3.new(math.cos(a), 1.2, math.sin(a)) * (chunk * 4 + 10)
		p.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 10
		p.Parent = folder
		Debris:AddItem(p, 2)
	end
	-- 먼지
	local dust = Instance.new("Part")
	dust.Anchored = true
	dust.Transparency = 1
	dust.CanCollide = false
	dust.CanQuery = false
	dust.Size = Vector3.new(size.X, 1, size.Z)
	dust.CFrame = CFrame.new(base)
	dust.Parent = folder
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(200, 190, 175))
	e.Size = NumberSequence.new(chunk * 1.5, chunk * 4)
	e.Transparency = NumberSequence.new(0.2, 1)
	e.Lifetime = NumberRange.new(1, 1.8)
	e.Speed = NumberRange.new(chunk, chunk * 3)
	e.SpreadAngle = Vector2.new(80, 80)
	e.Rate = 0
	e.Parent = dust
	e:Emit(30)
	Debris:AddItem(dust, 2.5)
	-- 가까우면 흔들림
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and SoundFx.shake then
		local d = (root.Position - cf.Position).Magnitude
		local reach = math.max(size.X, size.Z) * 3
		if d < reach then
			SoundFx.shake(0.4 * (1 - d / reach), 0.35)
		end
	end
end

function SmashFx.start()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BuildingBroken") :: RemoteEvent
	remote.OnClientEvent:Connect(burst)
end

return SmashFx
