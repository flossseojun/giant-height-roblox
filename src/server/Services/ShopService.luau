-- 꾸미기 상점: 코인으로 종류별 랜덤 상자 열기, 착용, 모두에게 착용 정보 공개
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.Config)
local Gacha = require(ReplicatedStorage.Shared.Logic.Gacha)
local DataService = require(script.Parent.DataService)
local CoinService = require(script.Parent.CoinService)
local Remotes = require(script.Parent.Remotes)

Gacha.setConfig(Config.COSMETICS)
local CC = Config.COSMETICS

-- 클라이언트가 미리 연결할 수 있게 시작할 때 만들어 둠
local openRemote = Remotes.get("OpenBox")
local resultRemote = Remotes.get("BoxResult")
local equipRemote = Remotes.get("EquipCosmetic")

local ShopService = {}
local states: { [Player]: Gacha.State } = {}
local busy: { [Player]: boolean } = {}

local function publish(player: Player)
	local s = states[player]
	if not s then
		return
	end
	DataService.extra(player).cosmetics = s
	player:SetAttribute("Cosmetics", HttpService:JSONEncode({
		wing = s.equipped.wing or "",
		aura = s.equipped.aura or "",
		trail = s.equipped.trail or "",
	}))
	local owned = {}
	for id in s.owned do
		table.insert(owned, id)
	end
	table.sort(owned)
	player:SetAttribute("CosmeticState", HttpService:JSONEncode({ owned = owned, pity = s.pity }))
end

local function open(player: Player, kind: any)
	local s = states[player]
	if not s or busy[player] or type(kind) ~= "string" or not table.find(CC.kinds, kind) then
		return
	end
	busy[player] = true
	if not CoinService.spend(player, CC.price) then
		busy[player] = nil
		Remotes.notify(player, "코인이 모자라요 (상자 " .. CC.price .. "코인)")
		return
	end
	local r = Gacha.open(s, kind, math.random(), math.random())
	if r then
		local it = Gacha.item(r.id)
		if r.dup then
			CoinService.add(player, r.refund, "refund")
		elseif s.equipped[kind] == nil then
			Gacha.equip(s, kind, r.id) -- 처음 얻었고 빈칸이면 바로 착용
		end
		if r.rarity == "legendary" then
			Remotes.notifyAll(player.DisplayName .. "님이 전설 '" .. it.name .. "' 획득!")
			Remotes.sfxAll("victory")
		end
		publish(player)
		resultRemote:FireClient(player, { id = r.id, kind = kind, rarity = r.rarity, name = it.name, dup = r.dup, refund = r.refund })
	end
	busy[player] = nil
end

local function onPlayer(player: Player)
	local t = os.clock()
	while player.Parent and player:GetAttribute("Height") == nil and os.clock() - t < 30 do
		task.wait(0.2)
	end
	if not player.Parent then
		return
	end
	states[player] = Gacha.clean(DataService.extra(player).cosmetics)
	publish(player)
end

function ShopService.start()
	openRemote.OnServerEvent:Connect(open)
	equipRemote.OnServerEvent:Connect(function(player, kind, id)
		local s = states[player]
		if s and type(kind) == "string" and (id == nil or type(id) == "string") and Gacha.equip(s, kind, id) then
			publish(player)
		end
	end)
	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		busy[player] = nil
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayer, p)
	end
end

return ShopService
