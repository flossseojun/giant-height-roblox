local H = require("./harness")
local Config = require("../src/shared/Config")
local MilkRain = require("../src/shared/Logic/MilkRain")
local describe, it, expect = H.describe, H.it, H.expect

describe("MilkRain", function()
	it("phase", function()
		expect(MilkRain.phase(100, 180, 10)).toBe("idle")
		expect(MilkRain.phase(175, 180, 10)).toBe("warning")
		expect(MilkRain.phase(180.5, 180, 10)).toBe("raining")
		expect(MilkRain.phase(181.5, 180, 10)).toBe("idle")
		expect(MilkRain.phase(0.5, 180, 10)).toBe("idle") -- 서버 켜자마자는 안 내림
	end)
	it("dropGain", function()
		expect(MilkRain.dropGain(Config.ZONES[1], 3)).toBe(9)
		expect(MilkRain.dropGain(Config.ZONES[3], 3)).toBe(1500)
	end)
end)

return nil
