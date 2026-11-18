-- 어깨에 태우기: 나보다 2배 이상 큰 친구의 어깨에 탄다. 점프하면 내림.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Growth = require(ReplicatedStorage.Shared.Logic.Growth)
local HeightService = require(script.Parent.HeightService)
local Remotes = require(script.Parent.Remotes)
local Util = require(script.Parent.Util)

local CarryService = {}

type Ride = { carrier: Player, weld: WeldConstraint, slot: number }
local rides: { [Player]: Ride } = {}
local stateRemote = Remotes.get("CarryState")

local function scaleOf(p: Player): number
	return Growth.heightToScale(HeightService.get(p), Config.SCALE_K, Config.MAX_SCALE)
end

local function ridersOf(carrier: Player): { [number]: Player }
	local out = {}
	for rider, r in rides do
		if r.carrier == carrier then
			out[r.slot] = rider
		end
	end
	return out
end

function CarryService.isRiding(player: Player): boolean
	return rides[player] ~= nil
end

local function dismount(rider: Player)
	local r = rides[rider]
	if not r then
		return
	end
	rides[rider] = nil
	Util.busy[rider] = nil
	if r.weld.Parent then
		r.weld:Destroy()
	end
	local char = rider.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = Util.root(rider)
	if hum then
		hum.Sit = false
	end
	if root then
		pcall(function()
			root:SetNetworkOwner(rider)
		end)
		root.CFrame = root.CFrame + Vector3.new(0, 3, 0)
	end
	if rider.Parent then
		stateRemote:FireClient(rider, false)
	end
end

local function mount(rider: Player, carrier: Player)
	if rider == carrier or rides[rider] or rides[carrier] or Util.busy[rider] or Util.busy[carrier] then
		return
	end
	if scaleOf(carrier) < scaleOf(rider) * Config.CARRY.minRatio then
		Remotes.notify(rider, "나보다 " .. Config.CARRY.minRatio .. "배 이상 큰 친구만 태워 줄 수 있어요")
		return
	end
	local taken = ridersOf(carrier)
	local slot = if not taken[1] then 1 elseif not taken[2] then 2 else nil
	if not slot or slot > Config.CARRY.maxRiders then
		Remotes.notify(rider, carrier.DisplayName .. "님 어깨가 꽉 찼어요")
		return
	end
	local rRoot, cChar = Util.root(rider), carrier.Character
	local head = cChar and cChar:FindFirstChild("Head") :: BasePart?
	if not (rRoot and head) then
		return
	end
	local side = if slot == 1 then -1 else 1
	local _, cSize = (cChar :: Model):GetBoundingBox()
	local _, rSize = (rider.Character :: Model):GetBoundingBox()
	-- 어깨 위: 머리 옆, 살짝 아래
	rRoot.CFrame = head.CFrame * CFrame.new(side * cSize.X * 0.3, -head.Size.Y * 0.2 + rSize.Y * 0.35, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = rRoot
	weld.Parent = rRoot
	local hum = (rider.Character :: Model):FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Sit = true
	end
	rides[rider] = { carrier = carrier, weld = weld, slot = slot }
	Util.busy[rider] = "ride"
	stateRemote:FireClient(rider, true)
	Remotes.notify(carrier, rider.DisplayName .. "님이 어깨에 탔어요!")
	Remotes.notify(rider, carrier.DisplayName .. "님 어깨에 탔어요! 점프하면 내려요")
end

local function addPrompt(owner: Player, char: Model)
	local root = char:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not root then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CarryPrompt"
	prompt.ActionText = "어깨에 타기"
	prompt.ObjectText = owner.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.G
	prompt.HoldDuration = 0.3
	prompt.RequiresLineOfSight = false
	prompt.UIOffset = Vector2.new(0, 60)
	prompt.Parent = root
	local function resize()
		prompt.MaxActivationDistance = 12 * scaleOf(owner)
	end
	local conn = owner:GetAttributeChangedSignal("Height"):Connect(resize)
	prompt.Destroying:Connect(function()
		conn:Disconnect()
	end)
	resize()
	prompt.Triggered:Connect(function(rider)
		mount(rider, owner)
	end)
end

function CarryService.start()
	Remotes.get("Dismount").OnServerEvent:Connect(dismount)
	local function onPlayer(p: Player)
		p.CharacterAdded:Connect(function(c)
			addPrompt(p, c)
		end)
		p.CharacterRemoving:Connect(function()
			dismount(p)
			for rider, r in rides do
				if r.carrier == p then
					dismount(rider)
				end
			end
		end)
		if p.Character then
			task.spawn(addPrompt, p, p.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayer, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		dismount(p)
		for rider, r in rides do
			if r.carrier == p then
				dismount(rider)
			end
		end
	end)
	-- 태운 사람이 너무 작아지면(환생 등) 내림
	task.spawn(function()
		while true do
			task.wait(1)
			for rider, r in rides do
				if not r.weld.Parent or scaleOf(r.carrier) < scaleOf(rider) * Config.CARRY.minRatio then
					dismount(rider)
				end
			end
		end
	end)
end

return CarryService
