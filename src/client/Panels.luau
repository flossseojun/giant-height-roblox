-- 환생 버튼, 오늘의 미션 창, 따라잡기 배지, 어깨에 타기(버튼 보이기/내리기)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Rebirth = require(ReplicatedStorage.Shared.Logic.Rebirth)
local Growth = require(ReplicatedStorage.Shared.Logic.Growth)
local Format = require(ReplicatedStorage.Shared.Logic.Format)

local Panels = {}
local player = Players.LocalPlayer
local FONT = Enum.Font.FredokaOne

local function corner(x: Instance)
	Instance.new("UICorner").Parent = x
end

local function button(parent: Instance, text: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Font = FONT
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.BackgroundColor3 = color
	b.Parent = parent
	corner(b)
	return b
end

local function heightOf(p: Player): number
	local h = p:GetAttribute("Height")
	return if type(h) == "number" then h else Config.START_HEIGHT
end

function Panels.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local gui = Instance.new("ScreenGui")
	gui.Name = "Panels"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	---------------------------------------------------------------- 환생
	local rebirthRemote = remotes:WaitForChild("Rebirth") :: RemoteEvent
	local rb = button(gui, "환생", Color3.fromRGB(170, 90, 230))
	rb.AnchorPoint = Vector2.new(0, 0.5)
	rb.Position = UDim2.new(0, 8, 0.25, 50)
	rb.Size = UDim2.new(0, 70, 0, 44)

	local confirm = Instance.new("Frame")
	confirm.AnchorPoint = Vector2.new(0.5, 0.5)
	confirm.Position = UDim2.fromScale(0.5, 0.5)
	confirm.Size = UDim2.new(0, 340, 0, 200)
	confirm.BackgroundColor3 = Color3.fromRGB(45, 35, 70)
	confirm.Visible = false
	confirm.Parent = gui
	corner(confirm)
	local info = Instance.new("TextLabel")
	info.BackgroundTransparency = 1
	info.Position = UDim2.fromScale(0.05, 0.05)
	info.Size = UDim2.fromScale(0.9, 0.6)
	info.Font = FONT
	info.TextScaled = true
	info.TextColor3 = Color3.new(1, 1, 1)
	info.Parent = confirm
	local yes = button(confirm, "환생하기!", Color3.fromRGB(170, 90, 230))
	yes.Position = UDim2.fromScale(0.05, 0.7)
	yes.Size = UDim2.fromScale(0.42, 0.24)
	local no = button(confirm, "취소", Color3.fromRGB(110, 110, 130))
	no.Position = UDim2.fromScale(0.53, 0.7)
	no.Size = UDim2.fromScale(0.42, 0.24)

	local function refreshRebirth()
		local r = player:GetAttribute("Rebirths")
		local rebirths = if type(r) == "number" then r else 0
		local need = Rebirth.requirement(rebirths, Config.REBIRTH.base)
		local ready = player:GetAttribute("RebirthReady") == true
		rb.BackgroundColor3 = if ready then Color3.fromRGB(170, 90, 230) else Color3.fromRGB(90, 80, 110)
		rb.Text = if ready then "환생!" else "환생"
		if ready then
			info.Text = "키가 150cm로 돌아가요.\n대신 영구 성장 ×"
				.. Rebirth.multiplier(rebirths + 1, Config.REBIRTH.step)
				.. "\n(펫·역대 기록은 그대로)"
		else
			info.Text = "환생 조건: 키 " .. Format.height(need) .. "\n지금: " .. Format.height(heightOf(player))
				.. "\n환생하면 영구 성장 ×" .. Rebirth.multiplier(rebirths + 1, Config.REBIRTH.step)
		end
		yes.Visible = ready
	end
	for _, a in { "RebirthReady", "Rebirths", "Height" } do
		player:GetAttributeChangedSignal(a):Connect(refreshRebirth)
	end
	refreshRebirth()
	rb.Activated:Connect(function()
		refreshRebirth()
		confirm.Visible = not confirm.Visible
	end)
	no.Activated:Connect(function()
		confirm.Visible = false
	end)
	yes.Activated:Connect(function()
		confirm.Visible = false
		rebirthRemote:FireServer()
	end)

	---------------------------------------------------------------- 오늘의 미션
	local questRemote = remotes:WaitForChild("QuestState") :: RemoteEvent
	local qb = button(gui, "미션", Color3.fromRGB(70, 160, 110))
	qb.AnchorPoint = Vector2.new(0, 0.5)
	qb.Position = UDim2.new(0, 8, 0.25, 100)
	qb.Size = UDim2.new(0, 70, 0, 44)
	local qPanel = Instance.new("Frame")
	qPanel.Position = UDim2.new(0, 86, 0.25, -10)
	qPanel.Size = UDim2.new(0, 260, 0, 150)
	qPanel.BackgroundColor3 = Color3.fromRGB(30, 50, 40)
	qPanel.BackgroundTransparency = 0.15
	qPanel.Visible = true
	qPanel.Parent = gui
	corner(qPanel)
	local qList = Instance.new("UIListLayout")
	qList.Padding = UDim.new(0, 4)
	qList.Parent = qPanel
	local qPad = Instance.new("UIPadding")
	qPad.PaddingLeft = UDim.new(0, 8)
	qPad.PaddingTop = UDim.new(0, 6)
	qPad.Parent = qPanel
	qb.Activated:Connect(function()
		qPanel.Visible = not qPanel.Visible
	end)
	questRemote.OnClientEvent:Connect(function(list)
		for _, c in qPanel:GetChildren() do
			if c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Size = UDim2.new(1, -8, 0, 26)
		title.Font = FONT
		title.TextScaled = true
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = Color3.fromRGB(255, 240, 160)
		title.Text = "오늘의 미션"
		title.Parent = qPanel
		for _, q in list do
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Size = UDim2.new(1, -8, 0, 32)
			l.Font = FONT
			l.TextScaled = true
			l.TextXAlignment = Enum.TextXAlignment.Left
			l.TextColor3 = if q.done then Color3.fromRGB(140, 255, 150) else Color3.new(1, 1, 1)
			l.Text = (if q.done then "[완료] " else "") .. q.name .. "  " .. q.progress .. "/" .. q.count
			l.Parent = qPanel
		end
	end)

	---------------------------------------------------------------- 따라잡기 배지
	local cu = Instance.new("TextLabel")
	cu.AnchorPoint = Vector2.new(1, 0)
	cu.Position = UDim2.new(1, -10, 0, 126)
	cu.Size = UDim2.new(0, 220, 0, 26)
	cu.BackgroundColor3 = Color3.fromRGB(60, 140, 220)
	cu.BackgroundTransparency = 0.2
	cu.TextColor3 = Color3.new(1, 1, 1)
	cu.Font = FONT
	cu.TextScaled = true
	cu.Visible = false
	cu.Parent = gui
	local function refreshCatchUp()
		local m = player:GetAttribute("CatchUp")
		cu.Visible = type(m) == "number" and m > 1
		if cu.Visible then
			cu.Text = "따라잡기 보너스 ×" .. tostring(m)
		end
	end
	player:GetAttributeChangedSignal("CatchUp"):Connect(refreshCatchUp)
	refreshCatchUp()

	---------------------------------------------------------------- 어깨에 타기
	local carryState = remotes:WaitForChild("CarryState") :: RemoteEvent
	local dismount = remotes:WaitForChild("Dismount") :: RemoteEvent
	local riding = false
	carryState.OnClientEvent:Connect(function(on: boolean)
		riding = on
	end)
	UserInputService.JumpRequest:Connect(function()
		if riding then
			riding = false
			dismount:FireServer()
		end
	end)
	-- 나보다 2배 이상 큰 사람에게만 "어깨에 타기" 버튼이 보이게 (내 몸 것은 항상 숨김)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local me = Growth.heightToScale(heightOf(player), Config.SCALE_K, Config.MAX_SCALE)
			for _, p in Players:GetPlayers() do
				local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				local prompt = root and root:FindFirstChild("CarryPrompt") :: ProximityPrompt?
				if prompt then
					local s = Growth.heightToScale(heightOf(p), Config.SCALE_K, Config.MAX_SCALE)
					prompt.Enabled = p ~= player and not riding and s >= me * Config.CARRY.minRatio
				end
			end
		end
	end)
end

return Panels
