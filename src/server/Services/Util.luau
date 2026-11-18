-- 여러 서비스가 같이 쓰는 도우미
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Util = {}

-- 닿은 파트가 어느 플레이어의 몸인지 (액세서리 포함)
function Util.playerFromPart(part: Instance?): Player?
	local node = part
	for _ = 1, 3 do
		if not node then
			return nil
		end
		local p = Players:GetPlayerFromCharacter(node)
		if p then
			return p
		end
		node = node.Parent
	end
	return nil
end

-- 이미 있는 것 + 나중에 생기는 것 모두에 fn 실행
-- (Workspace 안에 있는 것만: ServerStorage 등에 둔 예비 복사본은 무시)
function Util.eachTagged(tag: string, fn: (Instance) -> ())
	local function run(inst: Instance)
		if inst:IsDescendantOf(workspace) then
			task.spawn(fn, inst)
		end
	end
	for _, inst in CollectionService:GetTagged(tag) do
		run(inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(run)
end

function Util.zoneOf(inst: Instance): number
	local z = inst:GetAttribute("Zone")
	return if type(z) == "number" then z else 1
end

-- 살아 있는 캐릭터의 HumanoidRootPart
function Util.root(player: Player): BasePart?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (char and hum and hum.Health > 0) then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- 머리 위 이름표 (BillboardGui)
function Util.billboard(adornee: BasePart, text: string, color: Color3?, height: number?): BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Adornee = adornee
	bb.AlwaysOnTop = false
	bb.Size = UDim2.new(0, 120, 0, 30)
	bb.StudsOffsetWorldSpace = Vector3.new(0, (height or adornee.Size.Y) * 0.9 + 1, 0)
	bb.MaxDistance = 150
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.2
	l.Text = text
	l.Parent = bb
	bb.Parent = adornee
	return bb
end

return Util
