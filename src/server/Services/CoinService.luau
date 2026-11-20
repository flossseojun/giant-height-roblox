-- 코인: 활동으로 벌고(몬스터·건물·보스·미션) 꾸미기 상자에 씀
local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)
local Remotes = require(script.Parent.Remotes)

-- 클라이언트가 미리 연결할 수 있게 시작할 때 만들어 둠
local gainRemote = Remotes.get("CoinGain")

local CoinService = {}
local coins: { [Player]: number } = {}

local function clean(v: any): number
	if type(v) ~= "number" or v ~= v or v < 0 or v == math.huge then
		return 0
	end
	return math.floor(v)
end

local function publish(player: Player)
	local n = coins[player] or 0
	player:SetAttribute("Coins", n)
	DataService.extra(player).coins = n
end

function CoinService.get(player: Player): number
	return coins[player] or 0
end

function CoinService.add(player: Player, n: number, _reason: string)
	if not player.Parent or coins[player] == nil then
		return
	end
	local amount = math.floor(n)
	if amount <= 0 then
		return
	end
	coins[player] += amount
	publish(player)
	gainRemote:FireClient(player, amount)
end

-- 모자라면 false (상태 그대로)
function CoinService.spend(player: Player, n: number): boolean
	local have = coins[player]
	if have == nil or n <= 0 or have < n then
		return false
	end
	coins[player] = have - n
	publish(player)
	return true
end

local function onPlayer(player: Player)
	-- 저장을 불러올 때까지 기다림 (HeightService가 Height 속성을 붙임)
	local t = os.clock()
	while player.Parent and player:GetAttribute("Height") == nil and os.clock() - t < 30 do
		task.wait(0.2)
	end
	if not player.Parent then
		return
	end
	coins[player] = clean(DataService.extra(player).coins)
	publish(player)
end

function CoinService.start()
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player)
		coins[player] = nil
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayer, p)
	end
end

return CoinService
