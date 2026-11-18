-- 게임 숫자 설정 (밸런스는 여기만 고치면 됨)
local Config = {}

Config.START_HEIGHT = 150 -- cm
Config.MAX_SCALE = 12 -- 몸 크기 상한 (기본 아바타의 12배)
Config.SCALE_K = 1.5 -- 클수록 몸이 빨리 커짐

Config.ZONES = {
	{
		id = 1,
		name = "양평읍 시내",
		minHeight = 0,
		color = Color3 and Color3.fromRGB(140, 220, 110) or nil,
		foods = {
			{ id = "milk", name = "시장 우유", gain = 1 },
			{ id = "eggbread", name = "계란빵", gain = 2 },
			{ id = "hotteok", name = "호떡", gain = 3 },
		},
	},
	{
		id = 2,
		name = "두물머리",
		minHeight = 1000,
		color = Color3 and Color3.fromRGB(230, 160, 90) or nil,
		foods = {
			{ id = "corn", name = "찐 옥수수", gain = 15 },
			{ id = "lotusdog", name = "연잎 핫도그", gain = 20 },
			{ id = "hanwoo", name = "개군 한우", gain = 30 },
		},
	},
	{
		id = 3,
		name = "용문산",
		minHeight = 100000,
		color = Color3 and Color3.fromRGB(170, 215, 255) or nil,
		foods = {
			{ id = "bibimbap", name = "산채비빔밥", gain = 200 },
			{ id = "ginkgo", name = "은행", gain = 300 },
			{ id = "spring", name = "신비한 약수", gain = 500 },
		},
	},
}

-- 칭호 (announce = 처음 넘으면 서버 전체 알림)
Config.TITLES = {
	{ minHeight = 0, name = "양평 새싹" },
	{ minHeight = 1000, name = "강변 산책러" },
	{ minHeight = 100000, name = "등산가" },
	{ minHeight = 115700, name = "용문산보다 큰 사람", announce = true }, -- 용문산 1,157m
	{ minHeight = 884886, name = "에베레스트 정복자", announce = true }, -- 8,848.86m
	{ minHeight = 1e8, name = "지구 밖 거인", announce = true }, -- 1,000km
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
