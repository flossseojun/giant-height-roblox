-- 보스 공격에 맞으면: 뒤로 튕겨 나가고 잠깐 기절 (내 캐릭터 물리는 내 컴퓨터가 담당)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossClient = {}
local player = Players.LocalPlayer

function BossClient.start()
	local knock = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Knockback") :: RemoteEvent
	local stunnedUntil = 0
	knock.OnClientEvent:Connect(function(away: Vector3, stun: number)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not (hum and root) or root.Anchored then
			return
		end
		local s = math.sqrt(math.max(hum.WalkSpeed / 16, 1))
		root.AssemblyLinearVelocity = away * 70 * s + Vector3.new(0, 45 * s, 0)
		local until_ = os.clock() + stun
		local alreadyStunned = stunnedUntil > os.clock()
		stunnedUntil = until_
		if alreadyStunned then
			return
		end
		local speed = hum.WalkSpeed
		hum.WalkSpeed = 0
		while os.clock() < stunnedUntil do
			task.wait(0.1)
		end
		-- 그 사이 서버가 몸 크기를 바꿨으면 그 값을 존중
		if hum.WalkSpeed == 0 then
			hum.WalkSpeed = speed
		end
	end)
end

return BossClient
