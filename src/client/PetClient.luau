-- 펫: 모든 플레이어의 팀 펫(최대 3) 그리기, 펫 창(팀 짜기), 팀 HUD(체력·필살기),
-- 몬스터 터치(집중 공격), 착지(밟기), 길들이기 버튼
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.Config)
local Growth = require(ReplicatedStorage.Shared.Logic.Growth)

local PetClient = {}
local player = Players.LocalPlayer
local FONT = Enum.Font.FredokaOne
local SPECIES = Config.PET_SPECIES
local STAGE_SIZE = { 1, 1.4, 1.9 }

local LOOK = {
	cat = { body = Color3.fromRGB(240, 170, 90), ear = Color3.fromRGB(200, 120, 60), feature = "ears" },
	otter = { body = Color3.fromRGB(140, 100, 70), ear = Color3.fromRGB(100, 70, 50), feature = "tail_flat" },
	squirrel = { body = Color3.fromRGB(190, 110, 50), ear = Color3.fromRGB(250, 220, 170), feature = "tail_big" },
	pigeon = { body = Color3.fromRGB(150, 155, 170), ear = Color3.fromRGB(90, 160, 140), feature = "beak" },
	duck = { body = Color3.fromRGB(245, 245, 235), ear = Color3.fromRGB(250, 160, 30), feature = "beak" },
	carp = { body = Color3.fromRGB(240, 120, 50), ear = Color3.fromRGB(250, 240, 230), feature = "fin" },
	heron = { body = Color3.fromRGB(200, 205, 215), ear = Color3.fromRGB(230, 200, 60), feature = "beak" },
	boar = { body = Color3.fromRGB(110, 80, 60), ear = Color3.fromRGB(240, 230, 210), feature = "tusk" },
	crow = { body = Color3.fromRGB(35, 35, 45), ear = Color3.fromRGB(60, 60, 60), feature = "beak" },
	star = { body = Color3.fromRGB(255, 230, 120), ear = Color3.fromRGB(180, 200, 255), feature = "glow" },
	hotteok = { body = Color3.fromRGB(200, 140, 70), ear = Color3.fromRGB(120, 70, 30), feature = "flat" },
	catfish = { body = Color3.fromRGB(90, 100, 90), ear = Color3.fromRGB(60, 60, 50), feature = "whisker" },
	cloud = { body = Color3.fromRGB(245, 248, 255), ear = Color3.fromRGB(150, 200, 255), feature = "horn" },
}

local function decode(attr: any): { any }
	if type(attr) ~= "string" then
		return {}
	end
	local ok, v = pcall(HttpService.JSONDecode, HttpService, attr)
	return if ok and type(v) == "table" then v else {}
end

local function stageName(kind: string, stage: number): string
	local sp = SPECIES[kind]
	return sp and sp.stages[stage] or kind
end

-- 파트 몇 개로 만든 동글동글 펫 (진화 3단계면 왕관)
local function buildPet(kind: string, stage: number): Model
	local look = LOOK[kind] or LOOK.cat
	local m = Instance.new("Model")
	m.Name = "Pet_" .. kind
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
		x.Material = if look.feature == "glow" then Enum.Material.Neon else Enum.Material.SmoothPlastic
		x:SetAttribute("Offset", offset)
		x:SetAttribute("BaseSize", size)
		x.Parent = m
		return x
	end
	local flat = look.feature == "flat"
	local body = p("Body", if flat then Vector3.new(2.4, 0.9, 2.4) else Vector3.new(2, 1.8, 2), Vector3.zero, look.body)
	p("EyeL", Vector3.new(0.3, 0.3, 0.3), Vector3.new(-0.4, 0.2, -0.9), Color3.new(0, 0, 0))
	p("EyeR", Vector3.new(0.3, 0.3, 0.3), Vector3.new(0.4, 0.2, -0.9), Color3.new(0, 0, 0))
	local f = look.feature
	if f == "ears" then
		p("EarL", Vector3.new(0.6, 0.6, 0.6), Vector3.new(-0.55, 0.9, 0), look.ear)
		p("EarR", Vector3.new(0.6, 0.6, 0.6), Vector3.new(0.55, 0.9, 0), look.ear)
	elseif f == "tail_big" then
		p("Tail", Vector3.new(1, 2.2, 1), Vector3.new(0, 0.8, 1.1), look.ear)
	elseif f == "tail_flat" then
		p("Tail", Vector3.new(0.6, 0.6, 1.8), Vector3.new(0, -0.5, 1.3), look.ear)
	elseif f == "beak" then
		p("Beak", Vector3.new(0.5, 0.35, 0.7), Vector3.new(0, 0, -1.2), look.ear)
	elseif f == "fin" then
		p("Fin", Vector3.new(0.3, 1, 1.2), Vector3.new(0, 1, 0.2), look.ear)
		p("Tail", Vector3.new(0.3, 1.2, 0.8), Vector3.new(0, 0, 1.3), look.ear)
	elseif f == "tusk" then
		p("TuskL", Vector3.new(0.25, 0.6, 0.25), Vector3.new(-0.4, -0.3, -1), look.ear)
		p("TuskR", Vector3.new(0.25, 0.6, 0.25), Vector3.new(0.4, -0.3, -1), look.ear)
	elseif f == "whisker" then
		p("WhiskerL", Vector3.new(0.15, 0.15, 1.2), Vector3.new(-0.6, -0.2, -1.1), look.ear)
		p("WhiskerR", Vector3.new(0.15, 0.15, 1.2), Vector3.new(0.6, -0.2, -1.1), look.ear)
	elseif f == "horn" then
		p("HornL", Vector3.new(0.3, 0.8, 0.3), Vector3.new(-0.45, 1, -0.2), look.ear)
		p("HornR", Vector3.new(0.3, 0.8, 0.3), Vector3.new(0.45, 1, -0.2), look.ear)
	elseif f == "glow" then
		p("Halo", Vector3.new(0.2, 1.8, 1.8), Vector3.new(0, 1.2, 0), look.ear, Enum.PartType.Cylinder)
	end
	if stage >= 3 then
		p("Crown", Vector3.new(0.9, 0.5, 0.9), Vector3.new(0, 1.15, 0), Color3.fromRGB(255, 205, 60), Enum.PartType.Block)
	end
	m.PrimaryPart = body
	return m
end

type Follower = { model: Model, key: string, pos: Vector3, fainted: boolean }
local followers: { [Player]: { [number]: Follower } } = {}

local function heightOf(p: Player): number
	local h = p:GetAttribute("Height")
	return if type(h) == "number" then h else Config.START_HEIGHT
end

local monstersFolder: Instance? = nil
local function nearestMonster(at: Vector3, range: number): Model?
	monstersFolder = monstersFolder or workspace:FindFirstChild("Monsters")
	if not monstersFolder then
		return nil
	end
	local best, bestD = nil, range
	for _, m in (monstersFolder :: Instance):GetChildren() do
		if m:IsA("Model") and m.PrimaryPart then
			local d = (m.PrimaryPart.Position - at) * Vector3.new(1, 0, 1)
			if d.Magnitude < bestD then
				best, bestD = m, d.Magnitude
			end
		end
	end
	return best
end

local SLOTS = { Vector3.new(3, 0, 3), Vector3.new(-3, 0, 3), Vector3.new(0, 0, 5) }

local function updateFollowers(dt: number)
	for _, p in Players:GetPlayers() do
		local team = decode(p:GetAttribute("PetTeam"))
		local mine = followers[p] or {}
		followers[p] = mine
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local seen = {}
		for i, info in team do
			if i > 3 or not root then
				break
			end
			local uid = info.uid
			seen[uid] = true
			local key = tostring(info.kind) .. ":" .. tostring(info.stage)
			local f = mine[uid]
			if f and f.key ~= key then
				f.model:Destroy()
				f = nil
			end
			if not f then
				local nf: Follower = { model = buildPet(info.kind, info.stage or 1), key = key, pos = root.Position, fainted = false }
				nf.model.Parent = workspace.CurrentCamera
				mine[uid] = nf
				f = nf
			end
			local follower = f :: Follower
			local s = Growth.heightToScale(heightOf(p), Config.SCALE_K, Config.MAX_SCALE)
			local size = s * STAGE_SIZE[info.stage or 1]
			local fainted = (info.hp or 1) <= 0
			local target = (root.CFrame * CFrame.new(SLOTS[i] * s + Vector3.new(0, -1.5 * s, 0))).Position
			local look = root.CFrame.LookVector
			local foe = (not fainted) and nearestMonster(root.Position, Config.PET.baseRange * s)
			if foe and foe.PrimaryPart then
				local fp = foe.PrimaryPart.Position
				local around = Vector3.new(math.cos(i * 2.1), 0, math.sin(i * 2.1)) * (foe.PrimaryPart.Size.X * 0.9 + size)
				target = Vector3.new(fp.X, root.Position.Y - 1.5 * s, fp.Z) + around
				look = (fp - target) * Vector3.new(1, 0, 1)
				if look.Magnitude < 0.01 then
					look = root.CFrame.LookVector
				end
			end
			follower.pos = follower.pos:Lerp(target, math.clamp(dt * (if foe then 10 else 6), 0, 1))
			local bob = if fainted then 0 else math.sin(os.clock() * (if foe then 14 else 6) + i) * 0.2 * size
			local base = CFrame.lookAt(follower.pos, follower.pos + look) + Vector3.new(0, bob, 0)
			if fainted then
				base *= CFrame.Angles(0, 0, math.rad(90))
			end
			for _, part in follower.model:GetChildren() do
				if part:IsA("BasePart") then
					local off = part:GetAttribute("Offset") :: Vector3
					part.CFrame = base * CFrame.new(off * size)
					part.Size = (part:GetAttribute("BaseSize") :: Vector3) * size
					part.Transparency = if fainted then 0.5 else 0
				end
			end
		end
		for uid, f in mine do
			if not seen[uid] then
				f.model:Destroy()
				mine[uid] = nil
			end
		end
	end
	for p, mine in followers do
		if not p.Parent then
			for _, f in mine do
				f.model:Destroy()
			end
			followers[p] = nil
		end
	end
end

local function corner(parent: Instance)
	Instance.new("UICorner").Parent = parent
end

local function label(parent: Instance, text: string, size: UDim2, pos: UDim2?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos or UDim2.new()
	l.Font = FONT
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.5
	l.Text = text
	l.Parent = parent
	return l
end

-- 펫 창: 보유 목록을 눌러 팀(최대 3)에 넣고 빼기
local function buildPanel(gui: ScreenGui, remotes: Instance)
	local setTeam = remotes:WaitForChild("SetTeam") :: RemoteEvent
	local open = Instance.new("TextButton")
	open.AnchorPoint = Vector2.new(0, 0.5)
	open.Position = UDim2.new(0, 8, 0.25, 0)
	open.Size = UDim2.new(0, 70, 0, 44)
	open.Font = FONT
	open.TextScaled = true
	open.Text = "펫"
	open.BackgroundColor3 = Color3.fromRGB(255, 190, 90)
	open.Parent = gui
	corner(open)

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0, 380, 0, 420)
	panel.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	panel.Visible = false
	panel.Parent = gui
	corner(panel)
	local title = label(panel, "", UDim2.new(1, -20, 0, 34), UDim2.new(0, 10, 0, 8))
	local hint = label(panel, "눌러서 팀에 넣기/빼기 (최대 " .. Config.PET.maxTeam .. "마리)", UDim2.new(1, -20, 0, 20),
		UDim2.new(0, 10, 0, 44))
	hint.TextColor3 = Color3.fromRGB(210, 210, 230)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Position = UDim2.new(0, 10, 0, 70)
	scroll.Size = UDim2.new(1, -20, 1, -124)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 8
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(0.5, 1)
	close.Position = UDim2.new(0.5, 0, 1, -8)
	close.Size = UDim2.new(0.5, 0, 0, 38)
	close.Font = FONT
	close.TextScaled = true
	close.Text = "닫기"
	close.BackgroundColor3 = Color3.fromRGB(120, 120, 140)
	close.Parent = panel
	corner(close)
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	local function refresh()
		for _, c in scroll:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local owned = decode(player:GetAttribute("PetOwned"))
		local team = decode(player:GetAttribute("PetTeam"))
		local teamUids = {}
		for _, t in team do
			table.insert(teamUids, t.uid)
		end
		title.Text = "내 펫  (팀 " .. #teamUids .. "/" .. Config.PET.maxTeam .. " · 보유 " .. #owned .. "/" .. Config.PET.maxOwned .. ")"
		table.sort(owned, function(a, b)
			local ta, tb = table.find(teamUids, a.uid) ~= nil, table.find(teamUids, b.uid) ~= nil
			if ta ~= tb then
				return ta
			end
			return a.level > b.level
		end)
		for i, e in owned do
			local inTeam = table.find(teamUids, e.uid) ~= nil
			local row = Instance.new("TextButton")
			row.LayoutOrder = i
			row.Size = UDim2.new(1, -10, 0, 56)
			row.Text = ""
			row.AutoButtonColor = true
			row.BackgroundColor3 = if inTeam then Color3.fromRGB(90, 170, 100) else Color3.fromRGB(70, 90, 160)
			row.Parent = scroll
			corner(row)
			local sp = SPECIES[e.kind]
			local skill = sp and sp.skill.name or ""
			label(row, (if inTeam then "[팀] " else "") .. stageName(e.kind, e.stage or 1) .. "  Lv." .. e.level,
				UDim2.new(1, -16, 0.5, 0), UDim2.new(0, 8, 0, 2))
			local sub = label(row, "필살기 " .. skill .. "  ·  경험치 " .. math.floor(e.xp) .. "/" .. (e.need or 0),
				UDim2.new(1, -16, 0.38, 0), UDim2.new(0, 8, 0.56, 0))
			sub.TextColor3 = Color3.fromRGB(230, 235, 255)
			row.Activated:Connect(function()
				local new = table.clone(teamUids)
				local at = table.find(new, e.uid)
				if at then
					table.remove(new, at)
				elseif #new < Config.PET.maxTeam then
					table.insert(new, e.uid)
				else
					return
				end
				setTeam:FireServer(new)
			end)
		end
	end
	open.Activated:Connect(function()
		refresh()
		panel.Visible = not panel.Visible
	end)
	player:GetAttributeChangedSignal("PetOwned"):Connect(function()
		if panel.Visible then
			refresh()
		end
	end)
	player:GetAttributeChangedSignal("PetTeam"):Connect(function()
		if panel.Visible then
			refresh()
		end
	end)
end

-- 팀 HUD: 오른쪽 가운데, 펫마다 체력바 + 필살기 버튼
local function buildHud(gui: ScreenGui, remotes: Instance)
	local skillRemote = remotes:WaitForChild("PetSkill") :: RemoteEvent
	local box = Instance.new("Frame")
	box.AnchorPoint = Vector2.new(1, 0.5)
	box.Position = UDim2.new(1, -8, 0.5, 0)
	box.Size = UDim2.new(0, 190, 0, 3 * 58)
	box.BackgroundTransparency = 1
	box.Parent = gui
	local readyAt: { [number]: number } = {}
	local cards = {}
	for slot = 1, Config.PET.maxTeam do
		local card = Instance.new("Frame")
		card.Position = UDim2.new(0, 0, 0, (slot - 1) * 58)
		card.Size = UDim2.new(1, 0, 0, 52)
		card.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
		card.BackgroundTransparency = 0.25
		card.Visible = false
		card.Parent = box
		corner(card)
		local name = label(card, "", UDim2.new(0.6, -8, 0.45, 0), UDim2.new(0, 6, 0, 3))
		name.TextXAlignment = Enum.TextXAlignment.Left
		local back = Instance.new("Frame")
		back.Position = UDim2.new(0, 6, 0.58, 0)
		back.Size = UDim2.new(0.6, -10, 0.25, 0)
		back.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		back.BorderSizePixel = 0
		back.Parent = card
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = Color3.fromRGB(90, 210, 110)
		fill.BorderSizePixel = 0
		fill.Parent = back
		local btn = Instance.new("TextButton")
		btn.AnchorPoint = Vector2.new(1, 0.5)
		btn.Position = UDim2.new(1, -4, 0.5, 0)
		btn.Size = UDim2.new(0.38, 0, 1, -8)
		btn.Font = FONT
		btn.TextScaled = true
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.BackgroundColor3 = Color3.fromRGB(230, 120, 40)
		btn.Parent = card
		corner(btn)
		btn.Activated:Connect(function()
			skillRemote:FireServer(slot)
		end)
		cards[slot] = { card = card, name = name, fill = fill, btn = btn, skill = "" }
	end
	local current = {}
	local function refresh()
		current = decode(player:GetAttribute("PetTeam"))
		for slot, c in cards do
			local info = current[slot]
			c.card.Visible = info ~= nil
			if info then
				local sp = SPECIES[info.kind]
				c.name.Text = stageName(info.kind, info.stage or 1) .. " Lv." .. info.level
				c.fill.Size = UDim2.fromScale(math.clamp((info.hp or 0) / math.max(1, info.maxHp or 1), 0, 1), 1)
				c.fill.BackgroundColor3 = if (info.hp or 0) <= 0 then Color3.fromRGB(150, 150, 150) else Color3.fromRGB(90, 210, 110)
				c.skill = sp and sp.skill.name or "필살기"
				readyAt[slot] = os.clock() + (info.skillLeft or 0)
			end
		end
	end
	player:GetAttributeChangedSignal("PetTeam"):Connect(refresh)
	refresh()
	RunService.Heartbeat:Connect(function()
		for slot, c in cards do
			if c.card.Visible then
				local left = (readyAt[slot] or 0) - os.clock()
				local fainted = current[slot] and (current[slot].hp or 1) <= 0
				if fainted then
					c.btn.Text = "기절"
					c.btn.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
				elseif left > 0 then
					c.btn.Text = string.format("%d초", math.ceil(left))
					c.btn.BackgroundColor3 = Color3.fromRGB(110, 90, 70)
				else
					c.btn.Text = c.skill
					c.btn.BackgroundColor3 = Color3.fromRGB(230, 120, 40)
				end
			end
		end
	end)
end

-- 길들이기 버튼 (서버가 TameOffer를 보내면 잠깐 뜸)
local function buildTame(gui: ScreenGui, remotes: Instance)
	local offerRemote = remotes:WaitForChild("TameOffer") :: RemoteEvent
	local tameRemote = remotes:WaitForChild("Tame") :: RemoteEvent
	local btn = Instance.new("TextButton")
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.Position = UDim2.fromScale(0.5, 0.62)
	btn.Size = UDim2.new(0, 280, 0, 64)
	btn.Font = FONT
	btn.TextScaled = true
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.BackgroundColor3 = Color3.fromRGB(240, 90, 150)
	btn.Visible = false
	btn.Parent = gui
	corner(btn)
	local offerId, untilAt, name = nil, 0, ""
	offerRemote.OnClientEvent:Connect(function(id: number, _kind: string, petName: string, window: number)
		offerId, untilAt, name = id, os.clock() + (window or 8), petName
		btn.Visible = true
	end)
	btn.Activated:Connect(function()
		if offerId then
			tameRemote:FireServer(offerId)
			offerId = nil
			btn.Visible = false
		end
	end)
	RunService.Heartbeat:Connect(function()
		if btn.Visible then
			local left = untilAt - os.clock()
			if left <= 0 then
				btn.Visible = false
				offerId = nil
			else
				btn.Text = name .. " 길들이기! (" .. math.ceil(left) .. ")"
			end
		end
	end)
end

-- 몬스터 터치 → 집중 공격 표시 (서버도 ClickDetector로 받음)
local function watchMonsterClicks(remotes: Instance)
	local focusRemote = remotes:WaitForChild("FocusMonster") :: RemoteEvent
	local folder = workspace:WaitForChild("Monsters")
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(255, 220, 60)
	highlight.Parent = workspace.CurrentCamera
	local function hook(m: Instance)
		task.defer(function()
			local body = m:FindFirstChild("Body")
			local click = body and body:FindFirstChildOfClass("ClickDetector")
			if click then
				click.MouseClick:Connect(function()
					highlight.Adornee = m
					local id = m:GetAttribute("MonsterId")
					if type(id) == "number" then
						focusRemote:FireServer(id)
					end
				end)
			end
		end)
	end
	for _, m in folder:GetChildren() do
		hook(m)
	end
	folder.ChildAdded:Connect(hook)
end

-- 착지하면 밟기 (서버가 쿨타임·위치 검증)
local function watchLanding(remotes: Instance)
	local stomp = remotes:WaitForChild("Stomp") :: RemoteEvent
	local function onChar(char: Model)
		local hum = char:WaitForChild("Humanoid") :: Humanoid
		local fallStart = 0
		hum.StateChanged:Connect(function(_old, new)
			if new == Enum.HumanoidStateType.Freefall then
				fallStart = os.clock()
			elseif new == Enum.HumanoidStateType.Landed and os.clock() - fallStart > 0.25 then
				stomp:FireServer()
			end
		end)
	end
	if player.Character then
		task.spawn(onChar, player.Character)
	end
	player.CharacterAdded:Connect(onChar)
end

function PetClient.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local gui = Instance.new("ScreenGui")
	gui.Name = "Pets"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	task.spawn(buildPanel, gui, remotes)
	task.spawn(buildHud, gui, remotes)
	task.spawn(buildTame, gui, remotes)
	task.spawn(watchMonsterClicks, remotes)
	task.spawn(watchLanding, remotes)
	RunService.RenderStepped:Connect(updateFollowers)
end

return PetClient
