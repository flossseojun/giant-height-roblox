-- 클라이언트 시작점
local order = {
	"Hud",
	"Gates",
	"BarClient",
	"BallClient",
	"BedClient",
}

for _, name in order do
	local mod = script:FindFirstChild(name)
	if mod then
		task.spawn(function()
			local ok, err = pcall(function()
				require(mod).start()
			end)
			if not ok then
				warn("[거인 키 키우기] " .. name .. " 시작 실패: " .. tostring(err))
			end
		end)
	end
end

print("[거인 키 키우기] 클라 시작")
