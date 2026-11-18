-- 키의 유일한 주인: 키를 더하고, 몸 크기·속도·카메라·순위표에 반영한다
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Growth = require(ReplicatedStorage.Shared.Logic.Growth)
local Zones = require(ReplicatedStorage.Shared.Logic.Zones)
local Format = require(ReplicatedStorage.Shared.Logic.Format)
local Remotes = require(script.Parent.Remotes)
local DataService = require(script.Parent.DataService)

local HeightService = {}

local heights: { [Player]: number } = {}
local appliedScale: { [Player]: number } = {}
local listeners: { (Player, number, number) -> () } = {}

local function scaleFor(h: number): number
	return Growth.heightToScale(h, Config.SCALE_K, Config.MAX_SCALE)
end

-- 몸 크기를 바꾸면서 발이 땅에 묻히지 않게 위로 올려 준다
local function applyBody(player: Player, force: boolean?)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (char and hum and char.PrimaryPart) then
		return
	end
	local h = heights[player] or Config.START_HEIGHT
	local s = scaleFor(h)
	if not force and not Growth.shouldRescale(appliedScale[player] or 1, s) then
		return
	end
	local cf0, size0 = char:GetBoundingBox()
	local bottom0 = cf0.Position.Y - size0.Y / 2
	char:ScaleTo(s)
	local cf1, size1 = char:GetBoundingBox()
	local bottom1 = cf1.Position.Y - size1.Y / 2
	char:PivotTo(char:GetPivot() + Vector3.new(0, bottom0 - bottom1 + 0.1, 0))
	appliedScale[player] = s

	local stats = Growth.moveStats(s)
	hum.UseJumpPower = true
	hum.WalkSpeed = stats.walkSpeed
	hum.JumpPower = stats.jumpPower
	player.CameraMaxZoomDistance = math.max(stats.maxZoom, 30)
end

local function refreshDisplay(player: Player)
	local h = heights[player] or Config.START_HEIGHT
	player:SetAttribute("Height", h)
	local ls = player:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild("키")
	if v then
		(v :: StringValue).Value = Format.height(h)
	end
end

function HeightService.get(player: Player): number
	return heights[player] or Config.START_HEIGHT
end

function HeightService.currentZone(player: Player): number
	local z = player:GetAttribute("Zone")
	return if type(z) == "number" then z else 1
end

function HeightService.zoneConfig(player: Player)
	return Config.ZONES[HeightService.currentZone(player)] or Config.ZONES[1]
end

-- 다른 서비스가 "키가 바뀌었을 때" 알고 싶으면 등록
function HeightService.onChanged(fn: (Player, number, number) -> ())
	table.insert(listeners, fn)
end

function HeightService.add(player: Player, amount: number, source: string)
	if heights[player] == nil then
		return -- 아직 불러오는 중이거나 나간 플레이어
	end
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount == math.huge then
		return
	end
	local old = heights[player]
	local new = old + amount
	heights[player] = new
	refreshDisplay(player)
	applyBody(player)
	Remotes.get("Gained"):FireClient(player, amount, source)
	for _, fn in listeners do
		task.spawn(fn, player, old, new)
	end
end

local function onPlayerAdded(player: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local v = Instance.new("StringValue")
	v.Name = "키"
	v.Value = Format.height(Config.START_HEIGHT)
	v.Parent = ls
	ls.Parent = player
	player:SetAttribute("Zone", 1)

	local _, data = DataService.load(player)
	if not player.Parent then
		return
	end
	heights[player] = data.height
	player:SetAttribute("Unlocked", Zones.highestUnlocked(data.height, Config.ZONES))
	refreshDisplay(player)

	local function onChar(char: Model)
		appliedScale[player] = 1
		local hum = char:WaitForChild("Humanoid", 10)
		if not hum then
			return
		end
		task.wait(0.2) -- 캐릭터가 자리잡을 시간
		applyBody(player, true)
	end
	player.CharacterAdded:Connect(onChar)
	if player.Character then
		task.spawn(onChar, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	DataService.save(player)
	DataService.forget(player)
	heights[player] = nil
	appliedScale[player] = nil
end

function HeightService.start()
	DataService.setHeightGetter(HeightService.get)
	DataService.start(Players)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end

	-- 테스트용: 스튜디오에서만 /grow 숫자
	local debug = Remotes.get("DebugGrow")
	debug.OnServerEvent:Connect(function(player, amount)
		if RunService:IsStudio() and type(amount) == "number" then
			HeightService.add(player, amount, "debug")
		end
	end)
	Remotes.get("Gained")
	Remotes.get("Notify")
end

return HeightService
