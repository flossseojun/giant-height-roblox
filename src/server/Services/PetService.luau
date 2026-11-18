-- 펫: 고른 펫 저장, 성장 배율 적용, 근처 음식 자동 줍기
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Pets = require(ReplicatedStorage.Shared.Logic.Pets)
local Growth = require(ReplicatedStorage.Shared.Logic.Growth)
local HeightService = require(script.Parent.HeightService)
local DataService = require(script.Parent.DataService)
local FoodService = require(script.Parent.FoodService)
local Remotes = require(script.Parent.Remotes)
local Util = require(script.Parent.Util)

local PetService = {}

local function equip(player: Player, id: any, quiet: boolean?)
	local pet = Pets.find(Config.PETS, id)
	if not pet or not Pets.isUnlocked(pet, HeightService.get(player)) then
		return
	end
	DataService.extra(player).pet = pet.id
	HeightService.setPetMult(player, pet.mult)
	player:SetAttribute("Pet", pet.id)
	if not quiet then
		Remotes.notify(player, pet.name .. "와(과) 함께해요! 성장 ×" .. pet.mult)
	end
end

local function onPlayer(player: Player)
	-- HeightService가 저장을 불러올 때까지 기다림
	local t = os.clock()
	while player.Parent and player:GetAttribute("Height") == nil and os.clock() - t < 30 do
		task.wait(0.2)
	end
	if not player.Parent then
		return
	end
	local saved = DataService.extra(player).pet
	equip(player, if Pets.find(Config.PETS, saved) then saved else "cat", true)
end

local function pickup(player: Player)
	local id = player:GetAttribute("Pet")
	local pet = Pets.find(Config.PETS, id)
	local root = Util.root(player)
	if not (pet and root) then
		return
	end
	local scale = Growth.heightToScale(HeightService.get(player), Config.SCALE_K, Config.MAX_SCALE)
	local r = pet.radius * scale
	for part in FoodService.edibleParts() do
		if part.Parent and (part.Position - root.Position).Magnitude <= r then
			FoodService.tryEat(part, player)
			return -- 한 번에 하나씩 (펫이 "주워 오는" 느낌)
		end
	end
end

function PetService.start()
	Remotes.get("EquipPet").OnServerEvent:Connect(function(player, id)
		equip(player, id)
	end)
	-- 새 구역이 열려 새 펫을 얻으면 알려 줌
	HeightService.onChanged(function(player, old, new)
		for _, pet in Config.PETS do
			if old < pet.minHeight and new >= pet.minHeight then
				Remotes.notify(player, "새 펫 " .. pet.name .. " 획득! 왼쪽 '펫' 버튼에서 데려가세요")
			end
		end
	end)
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayer, p)
	end
	task.spawn(function()
		while true do
			task.wait(0.4)
			for _, p in Players:GetPlayers() do
				task.spawn(pickup, p)
			end
		end
	end)
end

return PetService
