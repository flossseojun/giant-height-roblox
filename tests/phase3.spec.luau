local H = require("./harness")
local Config = require("../src/shared/Config")
local Market = require("../src/shared/Logic/Market")
local Week = require("../src/shared/Logic/Week")
local Constellation = require("../src/shared/Logic/Constellation")
local describe, it, expect = H.describe, H.it, H.expect

describe("Market day (물맑은시장 3·8일장)", function()
	it("days ending in 3 or 8", function()
		for _, d in { 3, 8, 13, 18, 23, 28 } do
			expect(Market.isMarketDay(d)).toBe(true)
		end
		for _, d in { 1, 2, 4, 7, 9, 10, 30, 31 } do
			expect(Market.isMarketDay(d)).toBe(false)
		end
	end)
	it("KST day from unix time", function()
		-- 2026-11-18 00:30 KST = 2026-11-17 15:30 UTC
		expect(Market.kstDay(1794929400)).toBe(18)
		-- 2026-11-17 23:30 KST = 2026-11-17 14:30 UTC
		expect(Market.kstDay(1794925800)).toBe(17)
	end)
end)

describe("Week", function()
	it("week key starts Monday 00:00 KST", function()
		local mon = Week.key(1794754800) -- 2026-11-16 (월) 00:00 KST
		local sunNight = Week.key(1794754799) -- 2026-11-15 (일) 23:59:59 KST
		local wed = Week.key(1794961800) -- 2026-11-18 (수)
		expect(mon).toBe(wed)
		expect(sunNight == mon).toBe(false)
	end)
	it("gain this week resets on new week", function()
		local extra = {}
		expect(Week.gain(extra, 5000, 100)).toBe(0)
		expect(Week.gain(extra, 8000, 100)).toBe(3000)
		expect(Week.gain(extra, 9000, 101)).toBe(0)
		expect(Week.gain(extra, 9500, 101)).toBe(500)
	end)
end)

describe("Constellation", function()
	it("in order completes", function()
		local c = Constellation.new(30)
		expect(c.touch("bigdipper", 1, 7, 0)).toBe("progress")
		for i = 2, 6 do
			expect(c.touch("bigdipper", i, 7, i)).toBe("progress")
		end
		expect(c.touch("bigdipper", 7, 7, 7)).toBe("complete")
	end)
	it("wrong order resets, same star ignored", function()
		local c = Constellation.new(30)
		c.touch("orion", 1, 7, 0)
		expect(c.touch("orion", 1, 7, 0.5)).toBe("same")
		expect(c.touch("orion", 3, 7, 1)).toBe("reset")
		expect(c.progress("orion")).toBe(0)
		expect(c.touch("orion", 1, 7, 2)).toBe("progress")
	end)
	it("too slow resets", function()
		local c = Constellation.new(30)
		c.touch("cas", 1, 5, 0)
		expect(c.touch("cas", 2, 5, 31)).toBe("reset")
	end)
end)

describe("Night sky zone", function()
	it("zone 4 exists above 용문산", function()
		expect(Config.ZONES[4].name).toBe("양평 밤하늘")
		expect(Config.ZONES[4].minHeight).toBe(1000000)
	end)
end)

return nil
