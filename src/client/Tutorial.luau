-- 처음 온 사람 안내: 화살표(빔)로 다음 할 일을 가리킨다
--   1) 음식 5개 먹기 → 2) 철봉·농구·침대 중 하나 해 보기 → 3) 키 1,000cm 모아 두물머리 문으로
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)

local Tutorial = {}
local player = Players.LocalPlayer

function Tutorial.start()
	-- 저장 불러오기가 끝날 때까지 기다림
	while player:GetAttribute("TutorialDone") == nil do
		task.wait(0.5)
	end
	if player:GetAttribute("TutorialDone") == true then
		return
	end
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local gained = remotes:WaitForChild("Gained") :: RemoteEvent
	local doneRemote = remotes:WaitForChild("TutorialDone") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "Tutorial"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local box = Instance.new("TextLabel")
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.new(0.5, 0, 1, -170)
	box.Size = UDim2.new(0, 360, 0, 44)
	box.BackgroundColor3 = Color3.fromRGB(255, 250, 220)
	box.TextColor3 = Color3.fromRGB(60, 40, 20)
	box.Font = Enum.Font.FredokaOne
	box.TextScaled = true
	box.Parent = gui
	Instance.new("UICorner").Parent = box

	-- 화살표 빔: 내 몸 → 목표
	local beam = Instance.new("Beam")
	beam.Width0, beam.Width1 = 1.5, 1.5
	beam.FaceCamera = true
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 220, 60))
	beam.LightEmission = 1
	local targetAtt = Instance.new("Attachment")
	targetAtt.Parent = workspace.Terrain
	beam.Attachment1 = targetAtt
	beam.Parent = workspace.Terrain

	local step = 1
	local eaten = 0
	local triedActivity = false
	gained.OnClientEvent:Connect(function(_amount, source: string)
		if source == "bar" or source == "hoop" or source == "bed" then
			triedActivity = true
		elseif source ~= "debug" then
			eaten += 1
		end
	end)

	local function nearestTagged(tags: { string }, from: Vector3): BasePart?
		local best, bestD = nil, math.huge
		for _, tag in tags do
			for _, inst in CollectionService:GetTagged(tag) do
				if inst:IsA("BasePart") and inst:IsDescendantOf(workspace) and (inst:GetAttribute("Zone") or 1) == 1 then
					local d = (inst.Position - from).Magnitude
					if d < bestD then
						best, bestD = inst, d
					end
				end
			end
		end
		return best
	end

	local function nearestFood(from: Vector3): BasePart?
		local foods = workspace:FindFirstChild("Foods")
		local best, bestD = nil, math.huge
		for _, f in (foods and foods:GetChildren() or {}) do
			if f:IsA("BasePart") then
				local d = (f.Position - from).Magnitude
				if d < bestD then
					best, bestD = f, d
				end
			end
		end
		return best
	end

	while step <= 3 do
		task.wait(0.3)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end
		local att = root:FindFirstChild("TutorialAtt") :: Attachment?
		if not att then
			local a = Instance.new("Attachment")
			a.Name = "TutorialAtt"
			a.Parent = root
			att = a
		end
		beam.Attachment0 = att
		local h = player:GetAttribute("Height")
		local height = if type(h) == "number" then h else Config.START_HEIGHT
		local target: BasePart?
		if step == 1 then
			box.Text = "① 맵의 음식을 먹어 키를 키워요! (" .. math.min(eaten, 5) .. "/5)"
			target = nearestFood(root.Position)
			if eaten >= 5 then
				step = 2
			end
		elseif step == 2 then
			box.Text = "② 철봉·농구 골대·침대 중 하나를 해 봐요!"
			target = nearestTagged({ "Bar", "BallRack", "Bed" }, root.Position)
			if triedActivity then
				step = 3
			end
		else
			local need = Config.ZONES[2].minHeight
			box.Text = "③ 키 " .. need .. "cm를 모아 " .. Config.ZONES[2].name .. " 문으로!"
			for _, g in CollectionService:GetTagged("ZoneGate") do
				if g:IsA("BasePart") and g:GetAttribute("Zone") == 2 then
					target = g
				end
			end
			if height >= need then
				step = 4
			end
		end
		beam.Enabled = target ~= nil
		if target then
			targetAtt.WorldPosition = target.Position
		end
	end
	box.Text = "안내 끝! 이제 친구들보다 먼저 용문산을 넘어 봐요"
	beam:Destroy()
	targetAtt:Destroy()
	doneRemote:FireServer()
	task.wait(6)
	gui:Destroy()
end

return Tutorial
