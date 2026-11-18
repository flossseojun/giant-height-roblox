-- 화면 위 키 표시, 알림 토스트, "+N cm" 팝업, 스튜디오 테스트 버튼
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Logic.Format)

local Hud = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local FONT = Enum.Font.FredokaOne

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.3
	l.TextScaled = true
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

function Hud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- 키 표시
	local heightLabel = label(gui, {
		Name = "Height",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0.5, 0, 0, 56),
		Text = Format.height(Config.START_HEIGHT),
	})
	local zoneLabel = label(gui, {
		Name = "Zone",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.new(0.4, 0, 0, 24),
		TextColor3 = Color3.fromRGB(255, 240, 170),
		Text = Config.ZONES[1].name,
	})

	local function refresh()
		local h = player:GetAttribute("Height")
		if type(h) == "number" then
			heightLabel.Text = Format.height(h)
		end
		local z = player:GetAttribute("Zone")
		local zone = Config.ZONES[if type(z) == "number" then z else 1]
		if zone then
			zoneLabel.Text = zone.name
		end
	end
	player:GetAttributeChangedSignal("Height"):Connect(refresh)
	player:GetAttributeChangedSignal("Zone"):Connect(refresh)
	refresh()

	-- 알림 토스트 (아래에서 위로 쌓임)
	local toastBox = Instance.new("Frame")
	toastBox.BackgroundTransparency = 1
	toastBox.AnchorPoint = Vector2.new(0.5, 0)
	toastBox.Position = UDim2.new(0.5, 0, 0, 96)
	toastBox.Size = UDim2.new(0.7, 0, 0, 120)
	toastBox.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.Parent = toastBox

	remotes:WaitForChild("Notify").OnClientEvent:Connect(function(text: string)
		local t = label(toastBox, {
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 0.35,
			BackgroundColor3 = Color3.fromRGB(40, 40, 60),
			Text = text,
		})
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 10)
		c.Parent = t
		task.delay(4, function()
			t:Destroy()
		end)
	end)

	-- "+N cm" 팝업
	remotes:WaitForChild("Gained").OnClientEvent:Connect(function(amount: number, _source: string)
		local p = label(gui, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5 + (math.random() - 0.5) * 0.2, 0, 0.45, 0),
			Size = UDim2.new(0, 160, 0, 40),
			TextColor3 = Color3.fromRGB(130, 255, 140),
			Text = Format.gain(amount),
		})
		local tw = TweenService:Create(p, TweenInfo.new(0.9), {
			Position = p.Position - UDim2.new(0, 0, 0.12, 0),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		tw:Play()
		tw.Completed:Connect(function()
			p:Destroy()
		end)
	end)

	-- 스튜디오 전용 테스트 버튼
	if RunService:IsStudio() then
		local debug = remotes:WaitForChild("DebugGrow")
		local box = Instance.new("Frame")
		box.BackgroundTransparency = 1
		box.Position = UDim2.new(0, 8, 0.4, 0)
		box.Size = UDim2.new(0, 90, 0, 150)
		box.Parent = gui
		local l2 = Instance.new("UIListLayout")
		l2.Padding = UDim.new(0, 4)
		l2.Parent = box
		for _, pair in { { "+1천", 1000 }, { "+10만", 100000 }, { "+1억", 1e8 }, { "+1경", 1e16 } } do
			local b = Instance.new("TextButton")
			b.Size = UDim2.new(1, 0, 0, 32)
			b.Font = FONT
			b.TextScaled = true
			b.Text = "테스트 " .. pair[1]
			b.BackgroundColor3 = Color3.fromRGB(255, 120, 120)
			b.Parent = box
			b.Activated:Connect(function()
				debug:FireServer(pair[2])
			end)
		end
	end
end

return Hud
