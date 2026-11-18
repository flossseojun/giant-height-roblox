-- 하이파이브: 친구 몸의 "하이파이브" 버튼 → 친구가 받으면 둘 다 30초 성장 ×2
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HighFive = require(ReplicatedStorage.Shared.Logic.HighFive)
local Growth = require(ReplicatedStorage.Shared.Logic.Growth)
local HeightService = require(script.Parent.HeightService)
local Remotes = require(script.Parent.Remotes)
local QuestService = require(script.Parent.QuestService)

local HighFiveService = {}

local hf = HighFive.new(Config.HIGHFIVE)
local offerRemote = Remotes.get("HighFiveOffer")
local acceptRemote = Remotes.get("HighFiveAccept")

local function addPrompt(owner: Player, char: Model)
	local root = char:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not root then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HighFivePrompt"
	prompt.ActionText = "하이파이브"
	prompt.ObjectText = owner.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	local function resize()
		local s = Growth.heightToScale(HeightService.get(owner), Config.SCALE_K, Config.MAX_SCALE)
		prompt.MaxActivationDistance = 10 * s
	end
	local conn = owner:GetAttributeChangedSignal("Height"):Connect(resize)
	prompt.Destroying:Connect(function()
		conn:Disconnect()
	end)
	resize()
	prompt.Triggered:Connect(function(from)
		if from == owner then
			return
		end
		if hf.request(from.UserId, owner.UserId, os.clock()) then
			offerRemote:FireClient(owner, from.UserId, from.DisplayName)
			Remotes.notify(from, owner.DisplayName .. "님에게 하이파이브를 보냈어요!")
		else
			Remotes.notify(from, "같은 친구와는 1분에 한 번만 하이파이브할 수 있어요")
		end
	end)
end

function HighFiveService.start()
	local function onPlayer(p: Player)
		p.CharacterAdded:Connect(function(c)
			addPrompt(p, c)
		end)
		if p.Character then
			task.spawn(addPrompt, p, p.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayer, p)
	end
	acceptRemote.OnServerEvent:Connect(function(player, fromUserId)
		if type(fromUserId) ~= "number" then
			return
		end
		local from = Players:GetPlayerByUserId(fromUserId)
		if not from then
			return
		end
		local ok = hf.accept(player.UserId, fromUserId, os.clock())
		if not ok then
			Remotes.notify(player, "하이파이브 시간이 지났어요")
			return
		end
		local untilT = workspace:GetServerTimeNow() + Config.HIGHFIVE.duration
		for _, pl in { player, from } do
			HeightService.setBoostUntil(pl, untilT)
			Remotes.notify(pl, "하이파이브! " .. Config.HIGHFIVE.duration .. "초 동안 성장 ×2")
			Remotes.sfx(pl, "highfive")
			QuestService.record(pl, "highfive", 1)
		end
	end)
end

return HighFiveService
