-- 코인 표시, 상점 창(종류별 상자·착용), 상자 여는 연출
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local ShopClient = {}
local player = Players.LocalPlayer
local FONT = Enum.Font.FredokaOne
local CC = Config.COSMETICS
local RARITY_COLOR = {
	common = Color3.fromRGB(170, 170, 180),
	rare = Color3.fromRGB(70, 140, 255),
	legendary = Color3.fromRGB(255, 200, 40),
}
local RARITY_NAME = { common = "일반", rare = "희귀", legendary = "전설" }

local function decode(v: any): any
	if type(v) ~= "string" then
		return {}
	end
	local ok, t = pcall(HttpService.JSONDecode, HttpService, v)
	return if ok and type(t) == "table" then t else {}
end

local function corner(p: Instance)
	Instance.new("UICorner").Parent = p
end

local function text(parent: Instance, t: string, size: UDim2, pos: UDim2?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos or UDim2.new()
	l.Font = FONT
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.5
	l.Text = t
	l.Parent = parent
	return l
end

local function button(parent: Instance, t: string, size: UDim2, pos: UDim2, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.Font = FONT
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = t
	b.BackgroundColor3 = color
	b.Parent = parent
	corner(b)
	return b
end

local function itemOf(id: string): any?
	for _, it in CC.items do
		if it.id == id then
			return it
		end
	end
	return nil
end

function ShopClient.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local openRemote = remotes:WaitForChild("OpenBox") :: RemoteEvent
	local resultRemote = remotes:WaitForChild("BoxResult") :: RemoteEvent
	local equipRemote = remotes:WaitForChild("EquipCosmetic") :: RemoteEvent
	local gainRemote = remotes:WaitForChild("CoinGain") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "Shop"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- 코인 표시 (오른쪽 위)
	local coinLabel = text(gui, "코인 0", UDim2.new(0, 160, 0, 28), UDim2.new(1, -170, 0, 156))
	coinLabel.TextXAlignment = Enum.TextXAlignment.Right
	coinLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
	local function refreshCoins()
		local c = player:GetAttribute("Coins")
		coinLabel.Text = "코인 " .. tostring(if type(c) == "number" then c else 0)
	end
	player:GetAttributeChangedSignal("Coins"):Connect(refreshCoins)
	refreshCoins()
	gainRemote.OnClientEvent:Connect(function(n: number)
		local pop = text(gui, "+" .. n .. " 코인", UDim2.new(0, 140, 0, 26), UDim2.new(1, -150, 0, 184))
		pop.TextColor3 = Color3.fromRGB(255, 220, 80)
		local tw = TweenService:Create(pop, TweenInfo.new(1.2), { Position = UDim2.new(1, -150, 0, 150), TextTransparency = 1 })
		tw:Play()
		tw.Completed:Connect(function()
			pop:Destroy()
		end)
	end)

	-- 상점 창
	local open = button(gui, "상점", UDim2.new(0, 70, 0, 44), UDim2.new(0, 8, 0.25, 150), Color3.fromRGB(255, 120, 160))
	open.AnchorPoint = Vector2.new(0, 0.5)
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0, 460, 0, 440)
	panel.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	panel.Visible = false
	panel.Parent = gui
	corner(panel)
	text(panel, "꾸미기 뽑기 — 상자 " .. CC.price .. "코인", UDim2.new(1, -20, 0, 30), UDim2.new(0, 10, 0, 8))
	local rates = CC.rates
	local rateText = string.format("일반 %d%% · 희귀 %d%% · 전설 %d%%  (중복이면 %d코인 돌려줌)", rates.common * 100,
		rates.rare * 100, rates.legendary * 100, CC.refund)
	local sub = text(panel, rateText, UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 0, 40))
	sub.TextColor3 = Color3.fromRGB(210, 210, 230)

	local boxLabels: { [string]: TextLabel } = {}
	for i, kind in CC.kinds do
		local x = 10 + (i - 1) * 150
		local card = Instance.new("Frame")
		card.Position = UDim2.new(0, x, 0, 66)
		card.Size = UDim2.new(0, 140, 0, 120)
		card.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
		card.Parent = panel
		corner(card)
		text(card, CC.kindNames[kind] .. " 상자", UDim2.new(1, -10, 0, 28), UDim2.new(0, 5, 0, 4))
		boxLabels[kind] = text(card, "", UDim2.new(1, -10, 0, 18), UDim2.new(0, 5, 0, 34))
		local b = button(card, "열기", UDim2.new(1, -20, 0, 48), UDim2.new(0, 10, 0, 62), Color3.fromRGB(240, 130, 60))
		b.Activated:Connect(function()
			openRemote:FireServer(kind)
		end)
	end

	-- 착용 탭
	local tabKind = "wing"
	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.new(0, 10, 0, 236)
	list.Size = UDim2.new(1, -20, 1, -290)
	list.BackgroundTransparency = 1
	list.ScrollBarThickness = 8
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = list
	local tabs: { [string]: TextButton } = {}

	local function refresh()
		local st = decode(player:GetAttribute("CosmeticState"))
		local eq = decode(player:GetAttribute("Cosmetics"))
		for kind, l in boxLabels do
			local p = (st.pity and st.pity[kind]) or 0
			l.Text = "전설까지 " .. (CC.pity - p) .. "번"
		end
		for kind, t in tabs do
			t.BackgroundColor3 = if kind == tabKind then Color3.fromRGB(90, 170, 100) else Color3.fromRGB(80, 80, 110)
		end
		for _, c in list:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local any = false
		for _, id in st.owned or {} do
			local it = itemOf(id)
			if it and it.kind == tabKind then
				any = true
				local on = eq[tabKind] == id
				local row = button(list, (if on then "[착용 중] " else "") .. it.name .. "  (" .. RARITY_NAME[it.rarity] .. ")",
					UDim2.new(1, -10, 0, 36), UDim2.new(), if on then Color3.fromRGB(90, 170, 100) else RARITY_COLOR[it.rarity])
				row.Activated:Connect(function()
					equipRemote:FireServer(tabKind, if on then nil else id)
				end)
			end
		end
		if not any then
			text(list, "아직 없어요. 상자를 열어 보세요!", UDim2.new(1, -10, 0, 30))
		end
	end
	for i, kind in CC.kinds do
		local t = button(panel, CC.kindNames[kind], UDim2.new(0, 140, 0, 32), UDim2.new(0, 10 + (i - 1) * 150, 0, 196),
			Color3.fromRGB(80, 80, 110))
		t.Activated:Connect(function()
			tabKind = kind
			refresh()
		end)
		tabs[kind] = t
	end
	local close = button(panel, "닫기", UDim2.new(0.4, 0, 0, 38), UDim2.new(0.3, 0, 1, -46), Color3.fromRGB(120, 120, 140))
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	open.Activated:Connect(function()
		refresh()
		panel.Visible = not panel.Visible
	end)
	player:GetAttributeChangedSignal("CosmeticState"):Connect(refresh)
	player:GetAttributeChangedSignal("Cosmetics"):Connect(refresh)

	-- 상자 여는 연출: 빙글빙글 → 등급 색으로 번쩍 → 이름
	local reveal = Instance.new("Frame")
	reveal.AnchorPoint = Vector2.new(0.5, 0.5)
	reveal.Position = UDim2.fromScale(0.5, 0.45)
	reveal.Size = UDim2.new(0, 260, 0, 160)
	reveal.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	reveal.Visible = false
	reveal.ZIndex = 10
	reveal.Parent = gui
	corner(reveal)
	local box = Instance.new("Frame")
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.4)
	box.Size = UDim2.new(0, 70, 0, 70)
	box.BackgroundColor3 = Color3.fromRGB(200, 150, 90)
	box.ZIndex = 11
	box.Parent = reveal
	local result = text(reveal, "", UDim2.new(1, -20, 0, 40), UDim2.new(0, 10, 1, -50))
	result.ZIndex = 11
	resultRemote.OnClientEvent:Connect(function(r: any)
		reveal.Visible = true
		box.Visible = true
		box.Rotation = 0
		box.BackgroundColor3 = Color3.fromRGB(200, 150, 90)
		result.Text = "두근두근..."
		local spin = TweenService:Create(box, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Rotation = 720 })
		spin:Play()
		spin.Completed:Wait()
		local col = RARITY_COLOR[r.rarity] or Color3.new(1, 1, 1)
		box.BackgroundColor3 = col
		result.TextColor3 = col
		result.Text = RARITY_NAME[r.rarity] .. "! " .. r.name .. (if r.dup then "  (중복 +" .. r.refund .. "코인)" else "")
		task.wait(2)
		reveal.Visible = false
	end)
end

return ShopClient
