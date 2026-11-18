-- 펫 고르기 버튼/창, 모든 플레이어의 펫을 내 화면에 따라다니게 그리기
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Logic.Pets)
local Growth = require(ReplicatedStorage.Shared.Logic.Growth)
local Format = require(ReplicatedStorage.Shared.Logic.Format)

local PetClient = {}
local player = Players.LocalPlayer
local FONT = Enum.Font.FredokaOne

local LOOK = {
	cat = { body = Color3.fromRGB(240, 170, 90), ear = Color3.fromRGB(200, 120, 60) },
	otter = { body = Color3.fromRGB(140, 100, 70), ear = Color3.fromRGB(100, 70, 50) },
	squirrel = { body = Color3.fromRGB(190, 110, 50), ear = Color3.fromRGB(250, 220, 170) },
}

-- 파트 몇 개로 만든 동글동글 펫
local function buildPet(id: string): Model
	local look = LOOK[id] or LOOK.cat
	local m = Instance.new("Model")
	m.Name = "Pet_" .. id
	local function p(name, size, offset, color, shape)
		local x = Instance.new("Part")
		x.Name = name
		x.Size = size
		x.Shape = shape or Enum.PartType.Ball
		x.Color = color
		x.Anchored = true
		x.CanCollide = false
		x.CanQuery = false
		x.CanTouch = false
		x.Material = Enum.Material.SmoothPlastic
		x:SetAttribute("Offset", offset)
		x.Parent = m
		return x
	end
	local body = p("Body", Vector3.new(2, 1.8, 2), Vector3.zero, look.body)
	p("EarL", Vector3.new(0.6, 0.6, 0.6), Vector3.new(-0.55, 0.9, 0), look.ear)
	p("EarR", Vector3.new(0.6, 0.6, 0.6), Vector3.new(0.55, 0.9, 0), look.ear)
	p("EyeL", Vector3.new(0.3, 0.3, 0.3), Vector3.new(-0.4, 0.2, -0.9), Color3.new(0, 0, 0))
	p("EyeR", Vector3.new(0.3, 0.3, 0.3), Vector3.new(0.4, 0.2, -0.9), Color3.new(0, 0, 0))
	if id == "squirrel" then
		p("Tail", Vector3.new(1, 2.2, 1), Vector3.new(0, 0.8, 1.1), look.ear)
	elseif id == "otter" then
		p("Tail", Vector3.new(0.6, 0.6, 1.8), Vector3.new(0, -0.5, 1.3), look.ear)
	end
	m.PrimaryPart = body
	return m
end

type Follower = { model: Model, id: string, pos: Vector3 }
local followers: { [Player]: Follower } = {}

local function heightOf(p: Player): number
	local h = p:GetAttribute("Height")
	return if type(h) == "number" then h else Config.START_HEIGHT
end

local function updateFollowers(dt: number)
	for _, p in Players:GetPlayers() do
		local id = p:GetAttribute("Pet")
		local f = followers[p]
		if type(id) ~= "string" then
			if f then
				f.model:Destroy()
				followers[p] = nil
			end
			continue
		end
		if f and f.id ~= id then
			f.model:Destroy()
			f = nil
		end
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end
		if not f then
			local nf: Follower = { model = buildPet(id), id = id, pos = root.Position }
			nf.model.Parent = workspace.CurrentCamera
			followers[p] = nf
			f = nf
		end
		local follower = f :: Follower
		local s = Growth.heightToScale(heightOf(p), Config.SCALE_K, Config.MAX_SCALE)
		local target = (root.CFrame * CFrame.new(3 * s, -1.5 * s, 3 * s)).Position
		follower.pos = follower.pos:Lerp(target, math.clamp(dt * 6, 0, 1))
		local bob = math.sin(os.clock() * 6) * 0.2 * s
		local base = CFrame.lookAt(follower.pos, follower.pos + root.CFrame.LookVector) + Vector3.new(0, bob, 0)
		for _, part in follower.model:GetChildren() do
			if part:IsA("BasePart") then
				local off = part:GetAttribute("Offset") :: Vector3
				part.CFrame = base * CFrame.new(off * s)
				if part:GetAttribute("BaseSize") == nil then
					part:SetAttribute("BaseSize", part.Size)
				end
				part.Size = (part:GetAttribute("BaseSize") :: Vector3) * s
			end
		end
	end
	for p, f in followers do
		if not p.Parent then
			f.model:Destroy()
			followers[p] = nil
		end
	end
end

local function buildPicker()
	local equip = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EquipPet") :: RemoteEvent
	local gui = Instance.new("ScreenGui")
	gui.Name = "PetPicker"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local open = Instance.new("TextButton")
	open.AnchorPoint = Vector2.new(0, 0.5)
	open.Position = UDim2.new(0, 8, 0.25, 0)
	open.Size = UDim2.new(0, 70, 0, 44)
	open.Font = FONT
	open.TextScaled = true
	open.Text = "펫"
	open.BackgroundColor3 = Color3.fromRGB(255, 190, 90)
	open.Parent = gui
	Instance.new("UICorner").Parent = open

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0, 320, 0, 260)
	panel.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	panel.Visible = false
	panel.Parent = gui
	Instance.new("UICorner").Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.Parent = panel

	local buttons: { [string]: TextButton } = {}
	for _, pet in Config.PETS do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0.92, 0, 0, 64)
		b.Font = FONT
		b.TextScaled = true
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Parent = panel
		Instance.new("UICorner").Parent = b
		b.Activated:Connect(function()
			equip:FireServer(pet.id)
			panel.Visible = false
		end)
		buttons[pet.id] = b
	end
	local close = Instance.new("TextButton")
	close.Size = UDim2.new(0.5, 0, 0, 34)
	close.Font = FONT
	close.TextScaled = true
	close.Text = "닫기"
	close.BackgroundColor3 = Color3.fromRGB(120, 120, 140)
	close.Parent = panel
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	local function refresh()
		local h = heightOf(player)
		local current = player:GetAttribute("Pet")
		for _, pet in Config.PETS do
			local b = buttons[pet.id]
			if Pets.isUnlocked(pet, h) then
				local mark = if current == pet.id then "  (함께하는 중)" else ""
				b.Text = pet.name .. mark .. "\n성장 ×" .. pet.mult .. " · 음식 자동 줍기"
				b.BackgroundColor3 = if current == pet.id then Color3.fromRGB(90, 180, 100) else Color3.fromRGB(80, 110, 200)
				b.AutoButtonColor = true
				b.Active = true
			else
				b.Text = "잠김: " .. pet.name .. "\n키 " .. Format.height(pet.minHeight) .. " 필요"
				b.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
				b.AutoButtonColor = false
				b.Active = false
			end
		end
	end
	open.Activated:Connect(function()
		refresh()
		panel.Visible = not panel.Visible
	end)
	player:GetAttributeChangedSignal("Pet"):Connect(refresh)
end

function PetClient.start()
	task.spawn(buildPicker)
	RunService.RenderStepped:Connect(updateFollowers)
end

return PetClient
