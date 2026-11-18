-- 침대에서 자기: 누워 있는 동안 천천히 큰다 (점프하면 일어남)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(ReplicatedStorage.Shared.Logic.Zones)
local HeightService = require(script.Parent.HeightService)
local Remotes = require(script.Parent.Remotes)
local Util = require(script.Parent.Util)

local BedService = {}

type Session = { bed: BasePart, root: BasePart, since: number, zzz: Instance, conn: RBXScriptConnection? }
local sessions: { [Player]: Session } = {}
local occupied: { [BasePart]: Player } = {}

local stateRemote = Remotes.get("BedState")
local wakeRemote = Remotes.get("WakeUp")

local function wake(player: Player)
	local s = sessions[player]
	if not s then
		return
	end
	sessions[player] = nil
	occupied[s.bed] = nil
	Util.busy[player] = nil
	s.zzz:Destroy()
	if s.conn then
		s.conn:Disconnect()
	end
	if s.root.Parent then
		s.root.Anchored = false
		s.root.CFrame = CFrame.new(s.root.Position + Vector3.new(0, s.bed.Size.Y + 3, 0))
	end
	if player.Parent then
		stateRemote:FireClient(player, false)
	end
end

local function sleep(player: Player, bed: BasePart)
	if sessions[player] or occupied[bed] or Util.busy[player] then
		return
	end
	local root = Util.root(player)
	local char = player.Character
	if not (root and char) then
		return
	end
	local _, size = char:GetBoundingBox()
	root.Anchored = true
	local top = bed.CFrame * CFrame.new(0, bed.Size.Y / 2 + size.X * 0.25, 0)
	root.CFrame = top * CFrame.Angles(math.rad(-90), 0, 0)
	local zzz = Util.billboard(bed, "Zzz...", Color3.fromRGB(200, 210, 255), bed.Size.Y + size.Y * 0.5)
	local s: Session = { bed = bed, root = root, since = os.clock(), zzz = zzz }
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		s.conn = hum.Died:Connect(function()
			wake(player)
		end)
	end
	sessions[player] = s
	occupied[bed] = player
	Util.busy[player] = "bed"
	stateRemote:FireClient(player, true)
end

local function setupBed(bed: Instance)
	if not bed:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "자기"
	prompt.ObjectText = "침대"
	prompt.HoldDuration = 0.3
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = math.max(12, bed.Size.Magnitude)
	prompt.Parent = bed
	prompt.Triggered:Connect(function(player)
		sleep(player, bed)
	end)
end

function BedService.start()
	Util.eachTagged("Bed", setupBed)
	wakeRemote.OnServerEvent:Connect(wake)
	Players.PlayerRemoving:Connect(wake)
	task.spawn(function()
		while true do
			task.wait(Config.BED.period)
			for player, s in sessions do
				if not s.root.Parent or not s.bed.Parent then
					wake(player)
				elseif os.clock() - s.since >= Config.BED.period * 0.9 then
					local zone = Config.ZONES[Util.zoneOf(s.bed)] or Config.ZONES[1]
					HeightService.add(player, Zones.bestGain(zone) * Config.BED.mult, "bed")
				end
			end
		end
	end)
end

return BedService
