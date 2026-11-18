-- 공을 들고 있으면: 화면을 탭/클릭한 방향을 서버에 보낸다 (힘은 서버가 정함)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local BallClient = {}
local player = Players.LocalPlayer

function BallClient.start()
	local throwRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ThrowBall") :: RemoteEvent

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or player:GetAttribute("HasBall") ~= true then
			return
		end
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
			return
		end
		local cam = workspace.CurrentCamera
		local ray = cam:ScreenPointToRay(input.Position.X, input.Position.Y)
		-- 보스를 클릭한 거면 공은 던지지 않음 (보스 공격과 겹치지 않게)
		local bosses = workspace:FindFirstChild("Bosses")
		if bosses then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { bosses }
			if workspace:Raycast(ray.Origin, ray.Direction * 2000, params) then
				return
			end
		end
		throwRemote:FireServer(ray.Direction)
	end)
end

return BallClient
