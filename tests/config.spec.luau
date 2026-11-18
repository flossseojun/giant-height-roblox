local H = require("./harness")
local Config = require("../src/shared/Config")
local describe, it, expect = H.describe, H.it, H.expect

describe("Config", function()
	it("zones ascend", function()
		expect(#Config.ZONES).toBe(4)
		expect(Config.ZONES[1].minHeight).toBe(0)
		expect(Config.ZONES[2].minHeight).toBe(1000)
		expect(Config.ZONES[3].minHeight).toBe(100000)
	end)

	it("each zone has 3 foods with best gains 3/30/500/5000", function()
		local best = { 3, 30, 500, 5000 }
		for i, zone in Config.ZONES do
			expect(#zone.foods).toBe(3)
			local m = 0
			for _, f in zone.foods do
				m = math.max(m, f.gain)
			end
			expect(m).toBe(best[i])
		end
	end)

	it("start height is 150", function()
		expect(Config.START_HEIGHT).toBe(150)
	end)
end)

return nil
