-- 서버 시작점: 서비스들을 순서대로 켠다
local Services = script.Services

local order = {
	"HeightService",
	"FoodService",
}

for _, name in order do
	local mod = Services:FindFirstChild(name)
	if mod then
		local ok, err = pcall(function()
			require(mod).start()
		end)
		if not ok then
			warn("[거인 키 키우기] " .. name .. " 시작 실패: " .. tostring(err))
		end
	end
end

print("[거인 키 키우기] 서버 시작")
