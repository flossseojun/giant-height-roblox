-- ReplicatedStorage.Remotes 안의 RemoteEvent를 이름으로 만들거나 가져온다
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:FindFirstChild("Remotes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
end

local Remotes = {}

function Remotes.get(name: string): RemoteEvent
	local r = folder:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = folder
	end
	return r :: RemoteEvent
end

-- 한 사람에게 알림
function Remotes.notify(player: Player, text: string)
	Remotes.get("Notify"):FireClient(player, text)
end

-- 모두에게 알림
function Remotes.notifyAll(text: string)
	Remotes.get("Notify"):FireAllClients(text)
end

-- 효과음 신호 (클라이언트가 Config.SOUNDS에서 골라 재생)
function Remotes.sfx(player: Player, name: string, extra: any?)
	Remotes.get("Sfx"):FireClient(player, name, extra)
end

function Remotes.sfxAll(name: string, extra: any?)
	Remotes.get("Sfx"):FireAllClients(name, extra)
end

return Remotes
