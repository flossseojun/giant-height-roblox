-- 지금 어느 구역에 있는지 판단하고, 키가 모자라면 되돌려 보낸다
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(ReplicatedStorage.Shared.Logic.Zones)
local Format = require(ReplicatedStorage.Shared.Logic.Format)
local HeightService = require(script.Parent.HeightService)
local Remotes = require(script.Parent.Remotes)
local Util = require(script.Parent.Util)

local ZoneService = {}

local lastSafe: { [Player]: CFrame } = {}
local entered: { [Player]: number } = {}
local warnedAt: { [Player]: number } = {}

local function inside(part: BasePart, pos: Vector3): boolean
	local rel = part.CFrame:PointToObjectSpace(pos)
	local h = part.Size / 2
	return math.abs(rel.X) <= h.X and math.abs(rel.Y) <= h.Y and math.abs(rel.Z) <= h.Z
end

local function zoneAt(pos: Vector3): number?
	local found: number? = nil
	for _, area in CollectionService:GetTagged("ZoneArea") do
		if area:IsA("BasePart") and area:IsDescendantOf(workspace) and inside(area, pos) then
			local z = Util.zoneOf(area)
			found = if found then math.max(found, z) else z
		end
	end
	return found
end

local function check(player: Player)
	local root = Util.root(player)
	if not root then
		return
	end
	local z = zoneAt(root.Position)
	if not z then
		return -- 다리 위나 공중: 구역 그대로
	end
	local zone = Config.ZONES[z]
	if zone and not Zones.canEnter(HeightService.get(player), zone) then
		local back = lastSafe[player]
		if back then
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = back
		end
		local now = os.clock()
		if now - (warnedAt[player] or 0) > 3 then
			warnedAt[player] = now
			Remotes.notify(player, "아직 키가 부족해요! " .. Format.height(zone.minHeight) .. " 필요")
		end
		return
	end
	lastSafe[player] = root.CFrame
	if player:GetAttribute("Zone") ~= z then
		player:SetAttribute("Zone", z)
	end
	if z > (entered[player] or 1) then
		entered[player] = z
		Remotes.notifyAll(player.DisplayName .. "님이 " .. zone.name .. "에 입장!")
	end
end

function ZoneService.start()
	HeightService.onChanged(function(player, old, new)
		local a = Zones.highestUnlocked(old, Config.ZONES)
		local b = Zones.highestUnlocked(new, Config.ZONES)
		player:SetAttribute("Unlocked", b)
		if b > a then
			Remotes.notify(player, Config.ZONES[b].name .. " 문이 열렸어요!")
			Remotes.sfx(player, "title")
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		lastSafe[p] = nil
		entered[p] = nil
		warnedAt[p] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, p in Players:GetPlayers() do
				task.spawn(check, p)
			end
		end
	end)
end

return ZoneService
