-- 손맛 연출: 먹을 때(입으로 쏙·부스러기·콤보·냠), 커질 때(반짝이·카메라), 키 돌파(배너·번쩍·충격파·팡파레)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Juice = require(ReplicatedStorage.Shared.Logic.Juice)
local Format = require(ReplicatedStorage.Shared.Logic.Format)
local Growth = require(ReplicatedStorage.Shared.Logic.Growth)
local SoundFx = require(script.Parent.SoundFx)
local FoodVisuals = require(script.Parent.FoodVisuals)

local JuiceFx = {}
local player = Players.LocalPlayer
local FONT = Enum.Font.FredokaOne
local COMBO_WINDOW = 2

local comboCount, comboAt = 0, nil :: number?
local gui: ScreenGui
local comboLabel: TextLabel

local function root(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function head(): BasePart?
	local c = player.Character
	return c and (c:FindFirstChild("Head") :: BasePart?) or root()
end

-- 음식이 입으로 날아오며 작아짐 + 부스러기
local function eatFx(foodId: string, pos: Vector3, size: number)
	local h = head()
	local model = FoodVisuals.shapeOf(foodId, size * 0.9)
	model.Parent = workspace.CurrentCamera
	local color = model.PrimaryPart and model.PrimaryPart.Color or Color3.new(1, 1, 1)
	model:PivotTo(CFrame.new(pos))
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - t0) / 0.25, 0, 1)
		local target = if h and h.Parent then h.Position else pos
		model:PivotTo(CFrame.new(pos:Lerp(target, a * a)) * CFrame.Angles(0, a * 6, 0))
		pcall(function()
			model:ScaleTo(math.max(0.05, 1 - 0.9 * a))
		end)
		if a >= 1 then
			conn:Disconnect()
			model:Destroy()
		end
	end)
	-- 부스러기
	for i = 1, 8 do
		local c = Instance.new("Part")
		c.Size = Vector3.new(1, 1, 1) * size * 0.12
		c.Color = color
		c.CanCollide = false
		c.CanQuery = false
		c.CanTouch = false
		c.Position = pos
		local ang = i / 8 * math.pi * 2
		c.AssemblyLinearVelocity = Vector3.new(math.cos(ang), 1.4, math.sin(ang)) * (6 + size * 3)
		c.Parent = workspace.CurrentCamera
		Debris:AddItem(c, 0.7)
	end
	-- 콤보
	local now = os.clock()
	comboCount = Juice.combo(comboAt, comboCount, now, COMBO_WINDOW)
	comboAt = now
	SoundFx.play("eat", math.min(1.6, 1 + 0.06 * (comboCount - 1)))
	if comboCount >= 2 then
		comboLabel.Text = "콤보 ×" .. comboCount
		comboLabel.Visible = true
		comboLabel.TextSize = 46
		TweenService:Create(comboLabel, TweenInfo.new(0.25, Enum.EasingStyle.Back), { TextSize = 36 }):Play()
		local my = comboAt
		task.delay(COMBO_WINDOW, function()
			if comboAt == my then
				comboLabel.Visible = false
			end
		end)
	end
end

-- 커질 때: 발밑 반짝이 + 카메라 살짝 물러남
local lastGrowFx = 0
local function growFx(scale: number)
	local now = os.clock()
	if now - lastGrowFx < 0.4 then
		return
	end
	lastGrowFx = now
	local r = root()
	if r then
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Transparency = 1
		p.Size = Vector3.new(3, 0.2, 3) * scale
		p.CFrame = r.CFrame - Vector3.new(0, 2.8 * scale, 0)
		p.Parent = workspace.CurrentCamera
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(Color3.fromRGB(255, 255, 200), Color3.fromRGB(140, 255, 160))
		e.LightEmission = 1
		e.Size = NumberSequence.new(0.35 * scale, 0)
		e.Speed = NumberRange.new(4 * scale, 8 * scale)
		e.SpreadAngle = Vector2.new(25, 25)
		e.EmissionDirection = Enum.NormalId.Top
		e.Lifetime = NumberRange.new(0.5, 0.9)
		e.Rate = 0
		e.Parent = p
		e:Emit(14)
		Debris:AddItem(p, 1.2)
	end
	local cam = workspace.CurrentCamera
	local tw = TweenService:Create(cam, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = 74 })
	tw:Play()
	tw.Completed:Connect(function()
		TweenService:Create(cam, TweenInfo.new(0.3), { FieldOfView = 70 }):Play()
	end)
end

-- 키 돌파: 배너 + 번쩍 + 충격파 + 팡파레
local function milestoneFx(m: any, height: number)
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 0.3
	flash.BorderSizePixel = 0
	flash.ZIndex = 20
	flash.Parent = gui
	TweenService:Create(flash, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
	Debris:AddItem(flash, 0.5)

	local banner = Instance.new("TextLabel")
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.3)
	banner.Size = UDim2.new(0.7, 0, 0, 90)
	banner.BackgroundTransparency = 1
	banner.Font = FONT
	banner.TextScaled = true
	banner.TextColor3 = Color3.fromRGB(255, 230, 90)
	banner.TextStrokeTransparency = 0.2
	banner.Text = "키 " .. Format.height(m.cm) .. " 돌파!\n" .. m.text
	banner.ZIndex = 21
	banner.Parent = gui
	banner.Size = UDim2.new(0.2, 0, 0, 30)
	TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.new(0.7, 0, 0, 90) }):Play()
	task.delay(2.6, function()
		TweenService:Create(banner, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		Debris:AddItem(banner, 0.6)
	end)

	local r = root()
	if r then
		local scale = Growth.heightToScale(height, Config.SCALE_K, Config.MAX_SCALE)
		local ring = Instance.new("Part")
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(255, 240, 150)
		ring.Transparency = 0.3
		ring.Size = Vector3.new(0.3, 2 * scale, 2 * scale)
		ring.CFrame = CFrame.new(r.Position - Vector3.new(0, 2.8 * scale, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Parent = workspace.CurrentCamera
		TweenService:Create(ring, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.new(0.3, 40 * scale, 40 * scale), Transparency = 1 }):Play()
		Debris:AddItem(ring, 0.9)
	end
	SoundFx.play("victory")
end

function JuiceFx.start()
	gui = Instance.new("ScreenGui")
	gui.Name = "Juice"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	comboLabel = Instance.new("TextLabel")
	comboLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	comboLabel.Position = UDim2.fromScale(0.5, 0.56)
	comboLabel.Size = UDim2.new(0, 260, 0, 50)
	comboLabel.BackgroundTransparency = 1
	comboLabel.Font = FONT
	comboLabel.TextSize = 36
	comboLabel.TextColor3 = Color3.fromRGB(255, 170, 60)
	comboLabel.TextStrokeTransparency = 0.3
	comboLabel.Visible = false
	comboLabel.Parent = gui

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local ate = remotes:WaitForChild("Ate") :: RemoteEvent
	ate.OnClientEvent:Connect(eatFx)

	-- 접속 후 첫 키 값은 기준으로만 (저장 불러올 때 돌파 연출이 줄줄이 뜨지 않게)
	local last: number? = nil
	local function onHeight()
		local h = player:GetAttribute("Height")
		if type(h) ~= "number" then
			return
		end
		if last == nil then
			last = h
			return
		end
		local old = last :: number
		last = h
		if h <= old then
			return
		end
		local s0 = Growth.heightToScale(old, Config.SCALE_K, Config.MAX_SCALE)
		local s1 = Growth.heightToScale(h, Config.SCALE_K, Config.MAX_SCALE)
		if s1 - s0 >= 0.02 then
			growFx(s1)
		end
		local crossed = Juice.crossed(old, h, Config.MILESTONES)
		if #crossed > 0 then
			milestoneFx(crossed[#crossed], h) -- 여러 개면 가장 큰 것만
		end
	end
	player:GetAttributeChangedSignal("Height"):Connect(onHeight)
	onHeight()
end

return JuiceFx
