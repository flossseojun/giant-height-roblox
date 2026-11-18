local H = require("./harness")
local BarMash = require("../src/shared/Logic/BarMash")
local describe, it, expect = H.describe, H.it, H.expect

describe("BarMash", function()
	it("enough presses holds", function()
		local m = BarMash.new(4, 12)
		for i = 1, 5 do
			m.press(10 + i * 0.15)
		end
		expect(m.tick(11)).toBe("hold")
	end)
	it("too few presses falls", function()
		local m = BarMash.new(4, 12)
		for i = 1, 3 do
			m.press(10 + i * 0.2)
		end
		expect(m.tick(11)).toBe("fall")
	end)
	it("old presses expire", function()
		local m = BarMash.new(4, 12)
		for i = 1, 6 do
			m.press(10 + i * 0.1)
		end
		expect(m.tick(12.5)).toBe("fall")
	end)
	it("capsMashRate", function()
		local m = BarMash.new(4, 12)
		for i = 1, 50 do
			m.press(10 + i * 0.01)
		end
		expect(m.count(10.5)).toBe(12)
	end)
	it("grace: first second after grabbing holds", function()
		local m = BarMash.new(4, 12, 20)
		expect(m.tick(20.5)).toBe("hold")
		expect(m.tick(21.2)).toBe("fall")
	end)
end)

return nil
