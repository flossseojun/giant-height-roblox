-- 환생: 조건을 넘으면 키 150cm로 돌아가고 영구 성장 배율을 받는다
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Rebirth = require(ReplicatedStorage.Shared.Logic.Rebirth)
local Format = require(ReplicatedStorage.Shared.Logic.Format)
local HeightService = require(script.Parent.HeightService)
local DataService = require(script.Parent.DataService)
local Remotes = require(script.Parent.Remotes)
local Util = require(script.Parent.Util)

local RebirthService = {}

local function updateReady(player: Player)
	local r = HeightService.rebirths(player)
	player:SetAttribute("RebirthNeed", Rebirth.requirement(r, Config.REBIRTH.base))
	player:SetAttribute("RebirthReady", Rebirth.canRebirth(HeightService.get(player), r, Config.REBIRTH.base))
end

local function doRebirth(player: Player)
	local r = HeightService.rebirths(player)
	if not Rebirth.canRebirth(HeightService.get(player), r, Config.REBIRTH.base) or Util.busy[player] then
		return
	end
	r += 1
	DataService.extra(player).rebirths = r
	player:SetAttribute("Rebirths", r)
	HeightService.setHeight(player, Config.START_HEIGHT)
	player:SetAttribute("Zone", 1)
	updateReady(player)
	task.spawn(DataService.save, player)
	-- 출발 지점(양평역)에서 다시 시작
	task.spawn(function()
		local ok = pcall(function()
			(player :: any):LoadCharacterAsync()
		end)
		if not ok then
			pcall(function()
				(player :: any):LoadCharacter()
			end)
		end
	end)
	local mult = Rebirth.multiplier(r, Config.REBIRTH.step)
	Remotes.notifyAll(player.DisplayName .. "님이 환생 " .. r .. "번째! 영구 성장 ×" .. mult)
	Remotes.notify(player, "다음 환생 조건: 키 " .. Format.height(Rebirth.requirement(r, Config.REBIRTH.base)))
	Remotes.sfxAll("victory")
end

function RebirthService.start()
	Remotes.get("Rebirth").OnServerEvent:Connect(doRebirth)
	HeightService.onChanged(function(player)
		local was = player:GetAttribute("RebirthReady")
		updateReady(player)
		if not was and player:GetAttribute("RebirthReady") then
			Remotes.notify(player, "환생할 수 있어요! 왼쪽 '환생' 버튼")
		end
	end)
	-- 접속 직후 상태 표시
	task.spawn(function()
		while true do
			task.wait(3)
			for _, p in game:GetService("Players"):GetPlayers() do
				if p:GetAttribute("Height") ~= nil and p:GetAttribute("RebirthNeed") == nil then
					updateReady(p)
				end
			end
		end
	end)
end

return RebirthService
