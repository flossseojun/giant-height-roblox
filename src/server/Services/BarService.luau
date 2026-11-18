-- 철봉 매달리기: 연타로 버티는 동안 매초 키가 큰다
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(ReplicatedStorage.Shared.Logic.Zones)
local BarMash = require(ReplicatedStorage.Shared.Logic.BarMash)
local HeightService = require(script.Parent.HeightService)
local Remotes = require(script.Parent.Remotes)
local Util = require(script.Parent.Util)

local BarService = {}

type Session = { bar: BasePart, mash: any, root: BasePart, conn: RBXScriptConnection? }
local sessions: { [Player]: Session } = {}
local occupied: { [BasePart]: Player } = {}

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
	root.CFrame = CFrame.new(bar.Position - Vector3.new(0, size.Y * 0.45, 0)) * CFrame.Angles(0, math.rad(90), 0)
	local s: Session = { bar = bar, mash = BarMash.new(Config.BAR.minRate, Config.BAR.maxRate, os.clock()), root = root }
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
				else
					release(player)
					Remotes.notify(player, "힘이 빠져서 떨어졌어요!")
				end
			end
		end
	end)
end

return BarService
