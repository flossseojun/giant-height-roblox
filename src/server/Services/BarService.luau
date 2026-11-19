-- 철봉 매달리기: 연타로 버티는 동안 매초 키가 큰다
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(ReplicatedStorage.Shared.Logic.Zones)
local BarMash = require(ReplicatedStorage.Shared.Logic.BarMash)
local HeightService = require(script.Parent.HeightService)
local Remotes = require(script.Parent.Remotes)
local Util = require(script.Parent.Util)

local BarService = {}

type Session = { bar: BasePart, mash: any, root: BasePart, conn: RBXScriptConnection?, arms: { [Motor6D]: CFrame }, hang: CFrame, pull: number }
local sessions: { [Player]: Session } = {}
local occupied: { [BasePart]: Player } = {}

-- 팔을 머리 위로 (R15: RightShoulder/LeftShoulder, R6: Right/Left Shoulder)
local ARM_POSE = {
	RightShoulder = CFrame.Angles(math.pi, 0, 0),
	LeftShoulder = CFrame.Angles(math.pi, 0, 0),
	["Right Shoulder"] = CFrame.Angles(0, 0, math.pi),
	["Left Shoulder"] = CFrame.Angles(0, 0, -math.pi),
}

local function raiseArms(char: Model): { [Motor6D]: CFrame }
	local saved = {}
	for _, m in char:GetDescendants() do
		if m:IsA("Motor6D") and ARM_POSE[m.Name] then
			saved[m] = m.C0
			m.C0 = m.C0 * ARM_POSE[m.Name]
		end
	end
	return saved
end

local function lowerArms(saved: { [Motor6D]: CFrame })
	for m, c0 in saved do
		if m.Parent then
			m.C0 = c0
		end
	end
end

-- 턱걸이 한 번: 몸이 올라갔다 내려옴
local function pullUp(s: Session)
	if not s.root.Parent then
		return
	end
	local up = s.hang + Vector3.new(0, s.pull, 0)
	local t1 = TweenService:Create(s.root, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = up })
	t1:Play()
	t1.Completed:Connect(function()
		if s.root.Parent and s.root.Anchored then
			TweenService:Create(s.root, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = s.hang }):Play()
		end
	end)
end

local stateRemote = Remotes.get("BarState")
local mashRemote = Remotes.get("BarMash")

local function release(player: Player)
	local s = sessions[player]
	if not s then
		return
	end
	sessions[player] = nil
	occupied[s.bar] = nil
	Util.busy[player] = nil
	if s.conn then
		s.conn:Disconnect()
	end
	lowerArms(s.arms)
	if s.root.Parent then
		s.root.Anchored = false
	end
	if player.Parent then
		stateRemote:FireClient(player, false)
	end
end

local function grab(player: Player, bar: BasePart)
	if sessions[player] or occupied[bar] or Util.busy[player] then
		return
	end
	local root = Util.root(player)
	local char = player.Character
	if not (root and char) then
		return
	end
	local _, size = char:GetBoundingBox()
	-- 손이 가로대에 닿도록: 몸 중심을 가로대 아래로
	root.Anchored = true
	-- 팔을 위로 뻗으니까 몸은 가로대보다 더 아래에 매달림
	local hang = CFrame.new(bar.Position - Vector3.new(0, size.Y * 0.62, 0)) * CFrame.Angles(0, math.rad(90), 0)
	root.CFrame = hang
	local s: Session = {
		bar = bar,
		mash = BarMash.new(Config.BAR.minRate, Config.BAR.maxRate, os.clock()),
		root = root,
		arms = raiseArms(char),
		hang = hang,
		pull = size.Y * 0.3,
	}
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		s.conn = hum.Died:Connect(function()
			release(player)
		end)
	end
	sessions[player] = s
	occupied[bar] = player
	Util.busy[player] = "bar"
	stateRemote:FireClient(player, true)
end

local function setupBar(bar: Instance)
	if not bar:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "매달리기"
	prompt.ObjectText = "철봉"
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = math.max(12, bar.Size.Magnitude)
	prompt.Parent = bar
	prompt.Triggered:Connect(function(player)
		grab(player, bar)
	end)
end

function BarService.start()
	Util.eachTagged("Bar", setupBar)
	mashRemote.OnServerEvent:Connect(function(player)
		local s = sessions[player]
		if s then
			s.mash.press(os.clock())
		end
	end)
	Players.PlayerRemoving:Connect(release)
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for player, s in sessions do
				if not s.root.Parent or not s.bar.Parent then
					release(player)
				elseif s.mash.tick(now) == "hold" then
					local zone = Config.ZONES[Util.zoneOf(s.bar)] or Config.ZONES[1]
					HeightService.add(player, Zones.bestGain(zone), "bar")
					pullUp(s)
				else
					release(player)
					Remotes.notify(player, "힘이 빠져서 떨어졌어요!")
				end
			end
		end
	end)
end

return BarService
