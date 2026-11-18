-- 머리 위 이름+키 표시, 전체 서버 역대 순위판(GlobalBoard)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Growth = require(ReplicatedStorage.Shared.Logic.Growth)
local Format = require(ReplicatedStorage.Shared.Logic.Format)
local Titles = require(ReplicatedStorage.Shared.Logic.Titles)
local Week = require(ReplicatedStorage.Shared.Logic.Week)
local DataService = require(script.Parent.DataService)
local Remotes = require(script.Parent.Remotes)
local HeightService = require(script.Parent.HeightService)

local LeaderboardService = {}

local ordered: OrderedDataStore? = nil
pcall(function()
	ordered = DataStoreService:GetOrderedDataStore("GiantHeight_Top_v1")
end)

local nameCache: { [number]: string } = {}

---------------------------------------------------------------- 머리 위 표시
local function headTag(player: Player, char: Model)
	local head = char:WaitForChild("Head", 10) :: BasePart?
	if not head then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "HeightTag"
	bb.Adornee = head
	bb.AlwaysOnTop = false
	bb.MaxDistance = 400
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.2
	l.Parent = bb
	bb.Parent = head

	local function refresh()
		local h = HeightService.get(player)
		local s = Growth.heightToScale(h, Config.SCALE_K, Config.MAX_SCALE)
		-- 크기를 스터드 단위로: 몸이 커지면 이름표도 커짐
		bb.Size = UDim2.fromScale(7 * s, 2.4 * s)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 2.2 * s, 0)
		l.Text = "[" .. Titles.forHeight(h, Config.TITLES).name .. "]\n" .. player.DisplayName .. "  " .. Format.height(h)
	end
	local conn = player:GetAttributeChangedSignal("Height"):Connect(refresh)
	bb.Destroying:Connect(function()
		conn:Disconnect()
	end)
	refresh()
end

---------------------------------------------------------------- 역대 순위판
local function boardLabels(tag: string): { TextLabel }
	local labels = {}
	for _, board in CollectionService:GetTagged(tag) do
		if board:IsA("BasePart") and board:IsDescendantOf(workspace) then
			for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
				local name = "Board_" .. face.Name
				local sg = board:FindFirstChild(name) :: SurfaceGui?
				if not sg then
					local g = Instance.new("SurfaceGui")
					g.Name = name
					g.Face = face
					g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
					g.PixelsPerStud = 20
					local l = Instance.new("TextLabel")
					l.Name = "Text"
					l.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
					l.Size = UDim2.fromScale(1, 1)
					l.Font = Enum.Font.FredokaOne
					l.TextScaled = true
					l.TextColor3 = Color3.fromRGB(255, 240, 180)
					l.TextXAlignment = Enum.TextXAlignment.Left
					l.TextYAlignment = Enum.TextYAlignment.Top
					l.Parent = g
					local pad = Instance.new("UIPadding")
					pad.PaddingLeft = UDim.new(0.04, 0)
					pad.PaddingTop = UDim.new(0.03, 0)
					pad.Parent = l
					g.Parent = board
					sg = g
				end
				table.insert(labels, (sg :: SurfaceGui):FindFirstChild("Text") :: TextLabel)
			end
		end
	end
	return labels
end

local function nameOf(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local n = if ok and name then name else ("#" .. userId)
	nameCache[userId] = n
	return n
end

-- tag 판에 store의 상위 10명을 표시. value(p): 그 플레이어 점수
local function refreshBoard(tag: string, store: OrderedDataStore?, title: string, value: (Player) -> number)
	local labels = boardLabels(tag)
	if #labels == 0 then
		return
	end
	if not store then
		for _, l in labels do
			l.Text = title .. "\n(게임을 Publish하면 보여요)"
		end
		return
	end
	local st = store :: OrderedDataStore
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Height") ~= nil then
			local v = math.min(math.floor(value(p)), 2 ^ 53)
			pcall(function()
				st:SetAsync("u_" .. p.UserId, v)
			end)
		end
	end
	local ok, pages = pcall(function()
		return st:GetSortedAsync(false, 10)
	end)
	local lines = { title }
	if ok and pages then
		for i, entry in pages:GetCurrentPage() do
			local uid = tonumber(string.sub(entry.key, 3)) or 0
			table.insert(lines, string.format("%d위  %s  —  %s", i, nameOf(uid), Format.height(entry.value)))
		end
	else
		table.insert(lines, "(순위를 불러오지 못했어요)")
	end
	local text = table.concat(lines, "\n")
	for _, l in labels do
		l.Text = text
	end
end

local weekStores: { [number]: OrderedDataStore } = {}
local function weekStore(key: number): OrderedDataStore?
	if not weekStores[key] then
		pcall(function()
			weekStores[key] = DataStoreService:GetOrderedDataStore("GiantHeight_Week_v1_" .. key)
		end)
	end
	return weekStores[key]
end

local function refreshAll()
	refreshBoard("GlobalBoard", ordered, "역대 키 순위 TOP 10", HeightService.get)
	local key = Week.key(os.time())
	refreshBoard("WeeklyBoard", weekStore(key), "이번 주 성장 순위 TOP 10", function(p)
		return Week.gain(DataService.extra(p), HeightService.get(p), key)
	end)
end

function LeaderboardService.start()
	HeightService.onChanged(function(player, old, new)
		local t = Titles.crossed(old, new, Config.TITLES)
		if not t then
			return
		end
		Remotes.notify(player, "칭호 획득: " .. t.name)
		Remotes.sfx(player, "title")
		if t.announce then
			Remotes.notifyAll(player.DisplayName .. "님이 [" .. t.name .. "]이(가) 되었어요!")
		end
	end)
	local function onPlayer(p: Player)
		p.CharacterAdded:Connect(function(c)
			headTag(p, c)
		end)
		if p.Character then
			task.spawn(headTag, p, p.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayer, p)
	end
	task.spawn(function()
		task.wait(5)
		while true do
			refreshAll()
			task.wait(Config.BOARD_REFRESH)
		end
	end)
end

return LeaderboardService
