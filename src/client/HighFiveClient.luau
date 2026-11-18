-- 하이파이브: 받기 버튼, 내 몸의 버튼은 나한테 안 보이게, 부스트 남은 시간 표시
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HighFiveClient = {}
local player = Players.LocalPlayer
local FONT = Enum.Font.FredokaOne

function HighFiveClient.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local offer = remotes:WaitForChild("HighFiveOffer") :: RemoteEvent
	local accept = remotes:WaitForChild("HighFiveAccept") :: RemoteEvent

	-- 내 몸에 붙은 하이파이브 버튼은 숨김
	local function hideOwn(char: Model)
		local root = char:WaitForChild("HumanoidRootPart", 10)
		local prompt = root and root:WaitForChild("HighFivePrompt", 10)
		if prompt then
			(prompt :: ProximityPrompt).Enabled = false
		end
	end
	player.CharacterAdded:Connect(hideOwn)
	if player.Character then
		task.spawn(hideOwn, player.Character)
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "HighFive"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local box = Instance.new("Frame")
	box.AnchorPoint = Vector2.new(1, 0.5)
	box.Position = UDim2.new(1, -10, 0.55, 0)
	box.Size = UDim2.new(0, 230, 0, 260)
	box.BackgroundTransparency = 1
	box.Parent = gui
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.Parent = box

	offer.OnClientEvent:Connect(function(fromUserId: number, fromName: string)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, 0, 0, 56)
		b.Font = FONT
		b.TextScaled = true
		b.TextColor3 = Color3.new(1, 1, 1)
		b.BackgroundColor3 = Color3.fromRGB(255, 130, 170)
		b.Text = fromName .. "님의 하이파이브!\n눌러서 받기"
		b.Parent = box
		Instance.new("UICorner").Parent = b
		b.Activated:Connect(function()
			accept:FireServer(fromUserId)
			b:Destroy()
		end)
		task.delay(10, function()
			if b.Parent then
				b:Destroy()
			end
		end)
	end)

	-- 부스트 타이머
	local timer = Instance.new("TextLabel")
	timer.AnchorPoint = Vector2.new(1, 0)
	timer.Position = UDim2.new(1, -10, 0, 60)
	timer.Size = UDim2.new(0, 260, 0, 28)
	timer.BackgroundTransparency = 0.3
	timer.BackgroundColor3 = Color3.fromRGB(255, 120, 160)
	timer.TextColor3 = Color3.new(1, 1, 1)
	timer.Font = FONT
	timer.TextScaled = true
	timer.Visible = false
	timer.Parent = gui
	task.spawn(function()
		while true do
			task.wait(0.25)
			local e = player:GetAttribute("BoostEnd")
			local left = if type(e) == "number" then e - workspace:GetServerTimeNow() else 0
			timer.Visible = left > 0
			if left > 0 then
				timer.Text = "하이파이브 성장 ×2  " .. math.ceil(left) .. "초"
			end
		end
	end)
end

return HighFiveClient
