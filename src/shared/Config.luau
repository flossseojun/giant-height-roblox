-- 게임 숫자 설정 (밸런스는 여기만 고치면 됨)
local Config = {}

Config.START_HEIGHT = 150 -- cm
Config.MAX_SCALE = 12 -- 몸 크기 상한 (기본 아바타의 12배)
Config.SCALE_K = 1.5 -- 클수록 몸이 빨리 커짐

Config.ZONES = {
	{
		id = 1,
		name = "동네 놀이터",
		minHeight = 0,
		color = Color3 and Color3.fromRGB(140, 220, 110) or nil,
		foods = {
			{ id = "anchovy", name = "멸치", gain = 1 },
			{ id = "milk", name = "우유", gain = 2 },
			{ id = "egg", name = "계란", gain = 3 },
		},
	},
	{
		id = 2,
		name = "학교 운동장",
		minHeight = 1000,
		color = Color3 and Color3.fromRGB(230, 160, 90) or nil,
		foods = {
			{ id = "soymilk", name = "두유", gain = 15 },
			{ id = "cheese", name = "치즈", gain = 20 },
			{ id = "chicken", name = "닭가슴살", gain = 30 },
		},
	},
	{
		id = 3,
		name = "구름 위",
		minHeight = 100000,
		color = Color3 and Color3.fromRGB(170, 215, 255) or nil,
		foods = {
			{ id = "starcandy", name = "별사탕", gain = 200 },
			{ id = "cloudmilk", name = "구름우유", gain = 300 },
			{ id = "rainbowegg", name = "무지개 계란", gain = 500 },
		},
	},
}

Config.GOLDEN_CHANCE = 0.02
Config.GOLDEN_MULT = 10
Config.FOOD_RESPAWN = 8 -- 초

Config.RAIN = { interval = 180, warn = 10, count = 30, mult = 3, life = 20 }
Config.HOOP = { mult = 5, cooldown = 2, ballLife = 10 }
Config.BAR = { minRate = 4, maxRate = 12 }
Config.BED = { period = 5, mult = 0.5 }

Config.AUTOSAVE = 60 -- 초
Config.BOARD_REFRESH = 60 -- 초

return Config
