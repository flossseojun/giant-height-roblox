-- 실행: luau tests/run.luau
local H = require("./harness")

local specs = {
	"./config.spec",
	"./logic.spec",
	"./saveguard.spec",
	"./food.spec",
}

for _, path in specs do
	local ok, err = pcall(require, path)
	if not ok then
		H.failed += 1
		table.insert(H.failures, path .. " (불러오기 실패)\n    " .. tostring(err))
	end
end

for _, f in H.failures do
	print("FAIL " .. f)
end
print(string.format("%d passed, %d failed", H.passed, H.failed))
if H.failed > 0 then
	error("tests failed", 0)
end
