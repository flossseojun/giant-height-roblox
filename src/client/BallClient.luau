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
		throwRemote:FireServer(ray.Direction)
	end)
end

return BallClient
