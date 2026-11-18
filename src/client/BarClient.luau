-- 철봉에 매달린 동안: 큰 "연타!" 버튼(폰) + 스페이스바(PC), 힘 게이지
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local Config = require(ReplicatedStorage.Shared.Config)

local BarClient = {}
local player = Players.LocalPlayer

function BarClient.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local mash = remotes:WaitForChild("BarMash") :: RemoteEvent
	local state = remotes:WaitForChild("BarState") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "Bar"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local button = Instance.new("TextButton")
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -30)
	button.Size = UDim2.new(0, 220, 0, 110)
	button.BackgroundColor3 = Color3.fromRGB(255, 110, 90)
	button.Font = Enum.Font.FredokaOne
	button.TextScaled = true
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = "연타!\n(스페이스)"
	button.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 20)
	corner.Parent = button

	local gaugeBack = Instance.new("Frame")
	gaugeBack.AnchorPoint = Vector2.new(0.5, 1)
	gaugeBack.Position = UDim2.new(0.5, 0, 1, -150)
	gaugeBack.Size = UDim2.new(0, 260, 0, 18)
	gaugeBack.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	gaugeBack.Parent = gui
	local gauge = Instance.new("Frame")
	gauge.Size = UDim2.fromScale(0, 1)
	gauge.BackgroundColor3 = Color3.fromRGB(120, 255, 120)
	gauge.BorderSizePixel = 0
	gauge.Parent = gaugeBack

	local presses: { number } = {}
	local active = false

	local function press()
		if not active then
			return
		end
		mash:FireServer()
		table.insert(presses, os.clock())
	end

	button.Activated:Connect(press)

	local function onAction(_name, inputState)
		if inputState == Enum.UserInputState.Begin then
			press()
		end
		return Enum.ContextActionResult.Sink
	end

	state.OnClientEvent:Connect(function(on: boolean)
		active = on
		gui.Enabled = on
		table.clear(presses)
		if on then
			ContextActionService:BindActionAtPriority("BarMash", onAction, false, 3000, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
		else
			ContextActionService:UnbindAction("BarMash")
		end
	end)

	-- 게이지: 최근 1초 연타 수 / 필요한 수
	task.spawn(function()
		while true do
			task.wait(0.1)
			if active then
				local now = os.clock()
				local kept = {}
				for _, t in presses do
					if now - t < 1 then
						table.insert(kept, t)
					end
				end
				presses = kept
				local ratio = math.clamp(#presses / Config.BAR.minRate, 0, 1)
				gauge.Size = UDim2.fromScale(ratio, 1)
				gauge.BackgroundColor3 = if ratio >= 1 then Color3.fromRGB(120, 255, 120) else Color3.fromRGB(255, 200, 80)
			end
		end
	end)
end

return BarClient
