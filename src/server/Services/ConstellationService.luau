-- 4구역 별자리 따라 걷기: StarPoint 별판을 1번부터 순서대로 밟으면 큰 보상
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(ReplicatedStorage.Shared.Logic.Zones)
local Constellation = require(ReplicatedStorage.Shared.Logic.Constellation)
local HeightService = require(script.Parent.HeightService)
local Remotes = require(script.Parent.Remotes)
local Util = require(script.Parent.Util)

local ConstellationService = {}

local trackers: { [Player]: any } = {}
local lastReward: { [Player]: { [string]: number } } = {}
local progressRemote = Remotes.get("StarProgress")

local function tracker(player: Player)
	local t = trackers[player]
	if not t then
		t = Constellation.new(Config.CONSTELLATION.timeLimit)
		trackers[player] = t
	end
	return t
end

local function setupStar(star: Instance)
	if not star:IsA("BasePart") then
		return
	end
	local id = star:GetAttribute("Constellation")
	local index = star:GetAttribute("Index")
	local total = star:GetAttribute("Total")
	local display = star:GetAttribute("DisplayName") or id
	if type(id) ~= "string" or type(index) ~= "number" or type(total) ~= "number" then
		return
	end
	star.Touched:Connect(function(hit)
		local player = Util.playerFromPart(hit)
		if not player then
			return
		end
		local now = os.clock()
		local result = tracker(player).touch(id, index, total, now)
		if result == "same" then
			return
		end
		if result == "progress" then
			progressRemote:FireClient(player, id, index)
			Remotes.sfx(player, "star", index)
		elseif result == "reset" then
			progressRemote:FireClient(player, id, 0)
			Remotes.notify(player, display .. ": 순서가 틀렸어요! 1번 별부터 다시")
		elseif result == "complete" then
			progressRemote:FireClient(player, id, 0)
			local rewards = lastReward[player] or {}
			lastReward[player] = rewards
			if now - (rewards[id] or -math.huge) < Config.CONSTELLATION.cooldown then
				Remotes.notify(player, display .. " 완성! (보상은 " .. Config.CONSTELLATION.cooldown .. "초에 한 번)")
				return
			end
			rewards[id] = now
			local zone = Config.ZONES[Util.zoneOf(star)] or Config.ZONES[#Config.ZONES]
			HeightService.add(player, Zones.bestGain(zone) * Config.CONSTELLATION.rewardMult, "star")
			Remotes.notify(player, display .. " 완성! 별빛 성장 보상")
			Remotes.sfx(player, "victory")
		end
	end)
end

function ConstellationService.start()
	Util.eachTagged("StarPoint", setupStar)
	Players.PlayerRemoving:Connect(function(p)
		trackers[p] = nil
		lastReward[p] = nil
	end)
end

return ConstellationService
