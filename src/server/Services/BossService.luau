-- 구역 보스: 클릭/탭으로 같이 때리고, 꿀 웅덩이·충격파를 피한다. 90초 안에 못 잡으면 실패.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Zones = require(ReplicatedStorage.Shared.Logic.Zones)
local Growth = require(ReplicatedStorage.Shared.Logic.Growth)
local BossFight = require(ReplicatedStorage.Shared.Logic.BossFight)
local HeightService = require(script.Parent.HeightService)
local Remotes = require(script.Parent.Remotes)
local Util = require(script.Parent.Util)

local BossService = {}

local K = { 1, 3, 6 } -- 구역별 크기 배율
local knockRemote = Remotes.get("Knockback")
local lastReward: { [number]: number } = {}

local folder = Instance.new("Folder")
folder.Name = "Bosses"
folder.Parent = workspace

---------------------------------------------------------------- 모양
local function p(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?, mat: Enum.Material?)
	local x = Instance.new("Part")
	x.Name = name
	x.Size = size
	x.CFrame = cf
	x.Color = color
	x.Shape = shape or Enum.PartType.Block
	x.Material = mat or Enum.Material.SmoothPlastic
	x.Anchored = true
	x.CanCollide = true
	x.Parent = model
	return x
end

local function eyes(model: Model, center: CFrame, k: number, spread: number, fwd: number)
	for _, sx in { -1, 1 } do
		p(model, "Eye", Vector3.one * 1.6 * k, center * CFrame.new(sx * spread * k, 0, -fwd * k), Color3.new(1, 1, 1), Enum.PartType.Ball)
		p(model, "Pupil", Vector3.one * 0.8 * k, center * CFrame.new(sx * spread * k, 0, -(fwd + 0.6) * k), Color3.new(0, 0, 0), Enum.PartType.Ball)
		p(model, "Brow", Vector3.new(1.8, 0.35, 0.35) * k, center * CFrame.new(sx * spread * k, 1.1 * k, -fwd * k) * CFrame.Angles(0, 0, sx * math.rad(-25)), Color3.new(0.15, 0.1, 0.05))
	end
end

local function buildBoss(zone: number, at: Vector3): (Model, BasePart, number)
	local k = K[zone] or 1
	local m = Instance.new("Model")
	local main: BasePart
	local height: number
	if zone == 1 then -- 대왕 호떡
		local c = CFrame.new(at + Vector3.new(0, 6 * k, 0))
		main = p(m, "Body", Vector3.new(3 * k, 14 * k, 14 * k), c * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(190, 120, 60), Enum.PartType.Cylinder)
		eyes(m, c * CFrame.new(0, 1.5 * k, 0), k, 2.5, 1.6)
		p(m, "Syrup", Vector3.new(6, 1, 6) * k, c * CFrame.new(0, -0.8 * k, -3 * k), Color3.fromRGB(150, 70, 20), Enum.PartType.Ball, Enum.Material.Glass)
		height = 12 * k
	elseif zone == 2 then -- 대왕 메기
		local c = CFrame.new(at + Vector3.new(0, 4 * k, 0))
		main = p(m, "Body", Vector3.new(8, 7, 18) * k, c, Color3.fromRGB(110, 115, 120), Enum.PartType.Ball)
		p(m, "Tail", Vector3.new(1, 6, 5) * k, c * CFrame.new(0, 0, 10 * k), Color3.fromRGB(90, 95, 100))
		eyes(m, c * CFrame.new(0, 1.5 * k, -6 * k), k, 2.2, 1.5)
		for _, sx in { -1, 1 } do
			p(m, "Whisker", Vector3.new(7, 0.3, 0.3) * k, c * CFrame.new(sx * 4.5 * k, -1 * k, -8 * k) * CFrame.Angles(0, sx * math.rad(30), 0), Color3.new(0.1, 0.1, 0.1))
		end
		height = 8 * k
	else -- 구름 용
		local c = CFrame.new(at + Vector3.new(0, 10 * k, 0))
		for i = 4, 1, -1 do
			p(m, "Segment", Vector3.one * (6 - i * 0.6) * k, c * CFrame.new(0, -i * 1.5 * k, i * 4 * k), Color3.fromRGB(200, 230, 255), Enum.PartType.Ball, Enum.Material.Neon)
		end
		main = p(m, "Head", Vector3.new(7, 6, 9) * k, c, Color3.fromRGB(230, 245, 255), Enum.PartType.Ball)
		eyes(m, c * CFrame.new(0, 1 * k, -3 * k), k, 2, 1.8)
		for _, sx in { -1, 1 } do
			p(m, "Horn", Vector3.new(0.8, 4, 0.8) * k, c * CFrame.new(sx * 2 * k, 4 * k, 0) * CFrame.Angles(0, 0, sx * math.rad(-20)), Color3.fromRGB(255, 220, 120))
		end
		height = 16 * k
	end
	m.PrimaryPart = main
	m.Name = "Boss" .. zone
	return m, main, height
end

---------------------------------------------------------------- 체력바
local function hpBar(main: BasePart, name: string, k: number, height: number)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(16 * k, 3.5 * k)
	bb.StudsOffsetWorldSpace = Vector3.new(0, height * 0.7 + 2 * k, 0)
	bb.MaxDistance = 600
	bb.Adornee = main
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.45)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 230, 160)
	title.TextStrokeTransparency = 0
	title.Text = name
	title.Parent = bb
	local back = Instance.new("Frame")
	back.Position = UDim2.fromScale(0, 0.5)
	back.Size = UDim2.fromScale(1, 0.25)
	back.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
	back.Parent = bb
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(230, 60, 60)
	fill.BorderSizePixel = 0
	fill.Parent = back
	local info = Instance.new("TextLabel")
	info.BackgroundTransparency = 1
	info.Position = UDim2.fromScale(0, 0.77)
	info.Size = UDim2.fromScale(1, 0.23)
	info.Font = Enum.Font.FredokaOne
	info.TextScaled = true
	info.TextColor3 = Color3.new(1, 1, 1)
	info.TextStrokeTransparency = 0
	info.Parent = bb
	bb.Parent = main
	return function(ratio: number, text: string)
		fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
		info.Text = text
	end
end

---------------------------------------------------------------- 공격
local function flatDisc(pos: Vector3, diameter: number, color: Color3, transparency: number): Part
	local d = Instance.new("Part")
	d.Shape = Enum.PartType.Cylinder
	d.Size = Vector3.new(0.4, diameter, diameter)
	d.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	d.Color = color
	d.Material = Enum.Material.Neon
	d.Transparency = transparency
	d.Anchored = true
	d.CanCollide = false
	d.CanQuery = false
	d.CanTouch = false
	d.Parent = folder
	return d
end

local function knock(player: Player, from: Vector3)
	local root = Util.root(player)
	if not root then
		return
	end
	local away = root.Position - from
	away = Vector3.new(away.X, 0, away.Z)
	away = if away.Magnitude > 0.01 then away.Unit else Vector3.new(1, 0, 0)
	knockRemote:FireClient(player, away, Config.BOSS.stun)
	Remotes.sfx(player, "knock")
end

local function syrupAttack(target: Player, floorY: number, k: number)
	local root = Util.root(target)
	if not root then
		return
	end
	local center = Vector3.new(root.Position.X, floorY + 0.3, root.Position.Z)
	local radius = 6 * k
	local warn = flatDisc(center, radius * 2, Color3.fromRGB(255, 50, 50), 0.5)
	task.wait(1.2)
	warn:Destroy()
	local puddle = flatDisc(center, radius * 2, Color3.fromRGB(200, 110, 20), 0.2)
	Debris:AddItem(puddle, 0.8)
	for _, pl in Players:GetPlayers() do
		local r = Util.root(pl)
		if r then
			local d = Vector3.new(r.Position.X - center.X, 0, r.Position.Z - center.Z).Magnitude
			if d <= radius and math.abs(r.Position.Y - floorY) < 30 * k then
				knock(pl, center)
			end
		end
	end
end

local function shockwave(center: Vector3, k: number)
	local maxR = 40 * k
	local disc = flatDisc(center + Vector3.new(0, 0.3, 0), 2, Color3.fromRGB(255, 255, 255), 0.6)
	TweenService:Create(disc, TweenInfo.new(1.5, Enum.EasingStyle.Linear), { Size = Vector3.new(0.4, maxR * 2, maxR * 2), Transparency = 0.9 }):Play()
	Debris:AddItem(disc, 1.6)
	local hit: { [Player]: boolean } = {}
	local t0 = os.clock()
	while os.clock() - t0 < 1.5 do
		local r = (os.clock() - t0) / 1.5 * maxR
		for _, pl in Players:GetPlayers() do
			local root = Util.root(pl)
			local hum = pl.Character and pl.Character:FindFirstChildOfClass("Humanoid")
			if root and hum and not hit[pl] then
				local d = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z).Magnitude
				local grounded = hum.FloorMaterial ~= Enum.Material.Air
				if grounded and math.abs(d - r) < 3 * k and math.abs(root.Position.Y - center.Y) < 20 * k then
					hit[pl] = true
					knock(pl, center)
				end
			end
		end
		task.wait(0.05)
	end
end

---------------------------------------------------------------- 보스 하나 운영
local function runBoss(spawn: BasePart)
	local zone = Util.zoneOf(spawn)
	local cfg = Config.BOSSES[zone]
	if not cfg then
		return
	end
	local k = K[zone] or 1
	local fight = BossFight.new({
		maxHp = cfg.maxHp,
		timeLimit = Config.BOSS.timeLimit,
		retryDelay = Config.BOSS.retryDelay,
		maxHitsPerSec = Config.BOSS.maxHitsPerSec,
	})
	local floorY = spawn.Position.Y - spawn.Size.Y / 2
	local model, main, height = buildBoss(zone, Vector3.new(spawn.Position.X, floorY, spawn.Position.Z))
	local setBar = hpBar(main, cfg.name, k, height)
	local hitters: { [number]: boolean } = {}
	local lastState = "idle"

	local function refreshBar(now: number)
		local st = fight.state(now)
		local text
		if st == "fighting" then
			text = tostring(math.ceil(fight.hp())) .. " / " .. cfg.maxHp .. "   남은 시간 " .. math.ceil(fight.timeLeft(now)) .. "초"
		elseif st == "failed" then
			text = "재도전 대기 중..."
		else
			text = "클릭(탭)해서 공격 시작! 친구랑 같이 하면 쉬워요"
		end
		setBar(fight.hp() / cfg.maxHp, text)
	end

	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 400
	click.Parent = model
	click.MouseClick:Connect(function(player)
		if not Util.root(player) then
			return
		end
		local now = os.clock()
		local before = fight.state(now)
		local scale = Growth.heightToScale(HeightService.get(player), Config.SCALE_K, Config.MAX_SCALE)
		if fight.hit(player.UserId, BossFight.damageFor(scale), now) then
			hitters[player.UserId] = true
			Remotes.sfx(player, "bossHit")
			if before == "idle" then
				Remotes.notifyAll(player.DisplayName .. "님이 " .. cfg.name .. "에게 도전! 90초 안에 잡아라!")
			end
			main.Color = main.Color:Lerp(Color3.new(1, 1, 1), 0.3)
			task.delay(0.08, function()
				main.Color = main.Color:Lerp(Color3.new(1, 0.3, 0.3), 0.2)
			end)
			refreshBar(now)
		end
	end)
	local baseColor = main.Color
	model.Parent = folder

	local function fighterTargets(): { Player }
		local out = {}
		for uid in hitters do
			local pl = Players:GetPlayerByUserId(uid)
			local r = pl and Util.root(pl)
			if pl and r and (r.Position - main.Position).Magnitude < 200 * k then
				table.insert(out, pl)
			end
		end
		return out
	end

	task.spawn(function()
		local nextAttack = 0
		while spawn.Parent do
			task.wait(0.1)
			local now = os.clock()
			local st = fight.state(now)
			if st ~= lastState then
				if st == "defeated" then
					local zoneCfg = Config.ZONES[zone] or Config.ZONES[1]
					local reward = Zones.bestGain(zoneCfg) * Config.BOSS.rewardMult
					local names = {}
					for _, uid in fight.winners(Config.BOSS.minShare) do
						local pl = Players:GetPlayerByUserId(uid)
						if pl then
							if BossFight.canReward(lastReward[uid], now, Config.BOSS.rewardCooldown) then
								lastReward[uid] = now
								HeightService.add(pl, reward, "boss")
								Remotes.notify(pl, "보스 처치 보상!")
							else
								Remotes.notify(pl, "이 보스 보상은 10분에 한 번이에요")
							end
							table.insert(names, pl.DisplayName)
						end
					end
					Remotes.notifyAll(table.concat(names, ", ") .. " — " .. cfg.name .. " 처치!")
					Remotes.sfxAll("victory")
					model.Parent = nil
					task.delay(Config.BOSS.respawn, function()
						fight.reset()
						table.clear(hitters)
						main.Color = baseColor
						model.Parent = folder
						lastState = "idle"
						refreshBar(os.clock())
					end)
				elseif st == "failed" then
					for _, pl in fighterTargets() do
						Remotes.notify(pl, "실패! " .. cfg.name .. "의 체력이 회복됐어요. " .. Config.BOSS.retryDelay .. "초 뒤 재도전")
					end
					table.clear(hitters)
					main.Color = baseColor
				end
				lastState = st
			end
			if st == "fighting" then
				if now >= nextAttack then
					nextAttack = now + cfg.attackEvery
					local targets = fighterTargets()
					if #targets > 0 then
						local pick = targets[math.random(1, #targets)]
						task.spawn(syrupAttack, pick, floorY, k)
						if cfg.shockwave and math.random() < 0.5 then
							task.spawn(shockwave, Vector3.new(main.Position.X, floorY, main.Position.Z), k)
						end
					end
				end
				refreshBar(now)
			elseif st ~= "defeated" then
				refreshBar(now)
			end
		end
	end)
end

function BossService.start()
	Util.eachTagged("BossSpawn", function(inst)
		if inst:IsA("BasePart") then
			runBoss(inst)
		end
	end)
end

return BossService
