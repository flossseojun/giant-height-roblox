-- 밤하늘 구역에선 내 화면만 밤으로, 별자리 진행 표시, 장날 배지
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local World = {}
local player = Players.LocalPlayer
local NIGHT_ZONE = #Config.ZONES

local function nightSky()
	local day = { ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness }
	local function apply()
		local z = player:GetAttribute("Zone")
		local night = z == NIGHT_ZONE
		TweenService:Create(Lighting, TweenInfo.new(2), {
			ClockTime = if night then 0 else day.ClockTime,
			Brightness = if night then 1 else day.Brightness,
		}):Play()
	end
	player:GetAttributeChangedSignal("Zone"):Connect(apply)
	apply()
end

local function starProgress()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StarProgress") :: RemoteEvent
	remote.OnClientEvent:Connect(function(id: string, upTo: number)
		for _, star in CollectionService:GetTagged("StarPoint") do
			if star:IsA("BasePart") and star:GetAttribute("Constellation") == id then
				local i = star:GetAttribute("Index") :: number
				local lit = i <= upTo
				star.Color = if lit then Color3.fromRGB(120, 255, 160) else Color3.fromRGB(255, 230, 120)
				star.Transparency = if lit then 0 else 0.15
			end
		end
	end)
end

local function marketBadge()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MarketBadge"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(1, 0)
	l.Position = UDim2.new(1, -10, 0, 96)
	l.Size = UDim2.new(0, 220, 0, 26)
	l.BackgroundColor3 = Color3.fromRGB(200, 60, 50)
	l.BackgroundTransparency = 0.2
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = "오늘은 물맑은시장 장날! 양평읍 음식 ×" .. Config.MARKET_DAY_MULT
	l.Parent = gui
	local function refresh()
		l.Visible = workspace:GetAttribute("MarketDay") == true
	end
	workspace:GetAttributeChangedSignal("MarketDay"):Connect(refresh)
	refresh()
end

function World.start()
	task.spawn(nightSky)
	task.spawn(starProgress)
	task.spawn(marketBadge)
end

return World
