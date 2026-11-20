-- 효과음, 배경음악, 거인 발소리 + 화면 흔들림
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Growth = require(ReplicatedStorage.Shared.Logic.Growth)

local SoundFx = {}
local player = Players.LocalPlayer

local function makeSound(def, parent: Instance?): Sound
	local s = Instance.new("Sound")
	s.SoundId = def.id
	s.Volume = def.volume or 0.5
	s.PlaybackSpeed = def.pitch or 1
	s.Parent = parent or SoundService
	return s
end

-- 이름으로 재생 (pitchMul: 음 높이 추가 배율)
function SoundFx.play(name: string, pitchMul: number?)
	local def = Config.SOUNDS[name]
	if not def or def.id == "" then
		return
	end
	local function once(delay: number, extraPitch: number)
		task.delay(delay, function()
			local s = makeSound(def)
			local j = def.jitter or 0
			s.PlaybackSpeed = (def.pitch or 1) * (pitchMul or 1) * extraPitch * (1 + (math.random() * 2 - 1) * j)
			s:Play()
			s.Ended:Connect(function()
				s:Destroy()
			end)
			task.delay(5, function()
				if s.Parent then
					s:Destroy()
				end
			end)
		end)
	end
	once(0, 1)
	if def.double then
		once(0.12, 1.26)
	end
end

local function heightOf(p: Player): number
	local h = p:GetAttribute("Height")
	return if type(h) == "number" then h else Config.START_HEIGHT
end

local function scaleOf(p: Player): number
	return Growth.heightToScale(heightOf(p), Config.SCALE_K, Config.MAX_SCALE)
end

-- 화면 흔들림: 세기(스터드)만큼 잠깐 카메라를 흔든다
local shakeUntil, shakePower = 0, 0
local function shake(power: number, duration: number)
	if power <= 0.02 then
		return
	end
	shakePower = math.max(if os.clock() < shakeUntil then shakePower else 0, power)
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
end

local function footsteps()
	local nextStep: { [Player]: number } = {}
	local stepDef = Config.SOUNDS.footstep
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local me = scaleOf(player)
		local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		for _, p in Players:GetPlayers() do
			local s = scaleOf(p)
			local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if not (root and hum) or s < 2.5 then
				continue
			end
			local moving = hum.MoveDirection.Magnitude > 0.1 and hum.FloorMaterial ~= Enum.Material.Air
			if not moving or now < (nextStep[p] or 0) then
				continue
			end
			nextStep[p] = now + 0.35 * math.sqrt(s)
			-- 쿵! (거인 몸에서 나는 3D 소리)
			if stepDef and stepDef.id ~= "" then
				local snd = makeSound(stepDef, root)
				snd.PlaybackSpeed = (stepDef.pitch or 0.45) / math.sqrt(s / 2.5)
				snd.RollOffMaxDistance = 80 * s
				snd.Volume = math.min(1.5, (stepDef.volume or 0.8) * s / 4)
				snd:Play()
				task.delay(3, function()
					snd:Destroy()
				end)
			end
			-- 나보다 훨씬 큰 거인이 가까이 걸으면 내 화면이 흔들림
			if myRoot then
				local ratio = s / me
				local dist = (root.Position - myRoot.Position).Magnitude
				local reach = 40 * s
				-- 내 발걸음으로는 흔들지 않음(계속 떨려서 어지러움). 훨씬 큰 남이 가까이 걸을 때만, 약하게
				if p ~= player and ratio >= 2 and dist < reach then
					shake(math.min(0.15 * math.min(ratio, 6), 0.6) * (1 - dist / reach), 0.3)
				end
			end
		end
	end)
	-- 흔들림 적용 (Humanoid.CameraOffset)
	RunService.RenderStepped:Connect(function()
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not hum then
			return
		end
		local now = os.clock()
		if now < shakeUntil then
			-- 매 프레임 무작위 대신 부드러운 노이즈 + 끝으로 갈수록 약해짐
			local left = math.clamp((shakeUntil - now) / 0.3, 0, 1)
			local m = shakePower * left
			local t = now * 18
			hum.CameraOffset = Vector3.new(math.noise(t, 0.1) * m, math.noise(0.3, t) * m, 0)
		elseif hum.CameraOffset ~= Vector3.zero then
			hum.CameraOffset = Vector3.zero
		end
	end)
end

-- 다른 모듈(건물 무너짐 등)에서도 화면을 흔들 수 있게
SoundFx.shake = shake

function SoundFx.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local sfxRemote = remotes:WaitForChild("Sfx") :: RemoteEvent
	local notifyRemote = remotes:WaitForChild("Notify") :: RemoteEvent
	sfxRemote.OnClientEvent:Connect(function(name: string, extra: any)
		if name == "star" and type(extra) == "number" then
			SoundFx.play("star", 1 + extra * 0.1) -- 별을 밟을수록 음이 올라감
		else
			SoundFx.play(name)
		end
		if name == "knock" then
			shake(1.2, 0.3)
		end
	end)
	notifyRemote.OnClientEvent:Connect(function()
		SoundFx.play("notify")
	end)
	if Config.BGM ~= "" then
		local bgm = Instance.new("Sound")
		bgm.SoundId = Config.BGM
		bgm.Looped = true
		bgm.Volume = 0.25
		bgm.Parent = SoundService
		bgm:Play()
	end
	footsteps()
end

return SoundFx
