-- 자는 동안 점프(스페이스/폰 점프 버튼)하면 일어난다
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local BedClient = {}
local player = Players.LocalPlayer

function BedClient.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local state = remotes:WaitForChild("BedState") :: RemoteEvent
	local wake = remotes:WaitForChild("WakeUp") :: RemoteEvent
	local sleeping = false

	local gui = Instance.new("ScreenGui")
	gui.Name = "Bed"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local tip = Instance.new("TextLabel")
	tip.AnchorPoint = Vector2.new(0.5, 1)
	tip.Position = UDim2.new(0.5, 0, 1, -40)
	tip.Size = UDim2.new(0, 320, 0, 36)
	tip.BackgroundTransparency = 0.4
	tip.BackgroundColor3 = Color3.fromRGB(30, 30, 70)
	tip.TextColor3 = Color3.new(1, 1, 1)
	tip.Font = Enum.Font.FredokaOne
	tip.TextScaled = true
	tip.Text = "자는 중... 점프하면 일어나요"
	tip.Parent = gui

	state.OnClientEvent:Connect(function(on: boolean)
		sleeping = on
		gui.Enabled = on
	end)
	UserInputService.JumpRequest:Connect(function()
		if sleeping then
			sleeping = false
			wake:FireServer()
		end
	end)
end

return BedClient
