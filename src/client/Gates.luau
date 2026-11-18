-- 내 키로 열린 문은 내 화면에서만 통과 가능하게, 아니면 필요한 키를 보여 준다
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Logic.Format)

local Gates = {}
local player = Players.LocalPlayer

local function height(): number
	local h = player:GetAttribute("Height")
	return if type(h) == "number" then h else Config.START_HEIGHT
end

local function setup(gate: Instance)
	if not gate:IsA("BasePart") then
		return
	end
	local z = gate:GetAttribute("Zone")
	local zone = Config.ZONES[if type(z) == "number" then z else 2]
	if not zone then
		return
	end
	local origTransparency = gate.Transparency

	local labels = {}
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 10
		sg.Adornee = gate
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 0.4)
		l.Position = UDim2.fromScale(0, 0.3)
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextColor3 = Color3.new(1, 1, 1)
		l.TextStrokeTransparency = 0
		l.Parent = sg
		sg.Parent = player:WaitForChild("PlayerGui")
		table.insert(labels, l)
	end

	local function refresh()
		local open = height() >= zone.minHeight
		gate.CanCollide = not open
		gate.Transparency = if open then 0.8 else origTransparency
		for _, l in labels do
			l.Text = if open then zone.name .. " →" else ("잠김: " .. zone.name .. "\n키 " .. Format.height(zone.minHeight) .. " 필요")
		end
	end
	player:GetAttributeChangedSignal("Height"):Connect(refresh)
	refresh()
end

function Gates.start()
	for _, g in CollectionService:GetTagged("ZoneGate") do
		task.spawn(setup, g)
	end
	CollectionService:GetInstanceAddedSignal("ZoneGate"):Connect(setup)
end

return Gates
