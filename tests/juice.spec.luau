local H = require("./harness")
local Config = require("../src/shared/Config")
local Juice = require("../src/shared/Logic/Juice")
local describe, it, expect = H.describe, H.it, H.expect

describe("Juice", function()
	it("crossed milestones", function()
		expect(#Juice.crossed(20, 120, Config.MILESTONES)).toBe(2)
		expect(Juice.crossed(20, 120, Config.MILESTONES)[2].cm).toBe(100)
		expect(#Juice.crossed(120, 20, Config.MILESTONES)).toBe(0)
		expect(#Juice.crossed(30, 30, Config.MILESTONES)).toBe(0)
		for i = 2, #Config.MILESTONES do
			expect(Config.MILESTONES[i].cm > Config.MILESTONES[i - 1].cm).toBe(true)
		end
	end)
	it("combo", function()
		expect(Juice.combo(nil, 0, 5, 2)).toBe(1)
		expect(Juice.combo(4, 3, 5, 2)).toBe(4)
		expect(Juice.combo(1, 3, 5, 2)).toBe(1)
	end)
	it("scale steps", function()
		local st = Juice.scaleSteps(1, 2, 5, 0.05)
		expect(#st).toBe(5)
		expect(st[5]).toBe(2)
		expect(st[1]).toBeCloseTo(1.2)
		expect(#Juice.scaleSteps(1, 1.01, 5, 0.05)).toBe(1)
	end)
end)

return nil
