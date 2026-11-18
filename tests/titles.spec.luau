local H = require("./harness")
local Config = require("../src/shared/Config")
local Titles = require("../src/shared/Logic/Titles")
local describe, it, expect = H.describe, H.it, H.expect
local T = Config.TITLES

describe("Titles", function()
	it("forHeight", function()
		expect(Titles.forHeight(150, T).name).toBe("양평 새싹")
		expect(Titles.forHeight(1000, T).name).toBe("강변 산책러")
		expect(Titles.forHeight(115699, T).name).toBe("등산가")
		expect(Titles.forHeight(115700, T).name).toBe("용문산보다 큰 사람")
		expect(Titles.forHeight(1e9, T).name).toBe("지구 밖 거인")
	end)
	it("crossed returns the new title only when it changes", function()
		expect(Titles.crossed(100, 120, T)).toBe(nil)
		local t = Titles.crossed(115000, 116000, T)
		expect(t and t.name).toBe("용문산보다 큰 사람")
		expect(t and t.announce).toBe(true)
		local skip = Titles.crossed(500, 200000, T) -- 여러 단계를 한 번에 넘으면 가장 높은 것
		expect(skip and skip.name).toBe("용문산보다 큰 사람")
	end)
end)

describe("Yangpyeong zones", function()
	it("names", function()
		expect(Config.ZONES[1].name).toBe("양평읍 시내")
		expect(Config.ZONES[2].name).toBe("두물머리")
		expect(Config.ZONES[3].name).toBe("용문산")
	end)
end)

return nil
