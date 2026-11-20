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
	{
		id = 4,
		name = "양평 밤하늘",
		minHeight = 1000000, -- 10km
		color = Color3 and Color3.fromRGB(40, 40, 90) or nil,
		foods = {
			{ id = "starmilk", name = "별빛 우유", gain = 2000 },
			{ id = "starcandy", name = "별사탕", gain = 3000 },
			{ id = "meteor", name = "별똥별 조각", gain = 5000 },
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
	{ minHeight = 1000000, name = "별을 만지는 거인", announce = true }, -- 밤하늘 입장
	{ minHeight = 1e8, name = "지구 밖 거인", announce = true }, -- 1,000km
}

Config.GOLDEN_CHANCE = 0.02
Config.GOLDEN_MULT = 10
Config.FOOD_RESPAWN = 8 -- 초

Config.RAIN = { interval = 180, warn = 10, count = 30, mult = 3, life = 20 }
Config.HOOP = { mult = 5, cooldown = 3 } -- 덩크 1번 보상 = 구역 최고 음식 × mult
Config.BAR = { minRate = 4, maxRate = 12 }
Config.BED = { period = 5, mult = 0.5 }

-- 2차: 펫 (구역 키를 넘으면 해금)
Config.PETS = {
	{ id = "cat", name = "시장 고양이", minHeight = 0, mult = 1.1, radius = 8 },
	{ id = "otter", name = "남한강 수달", minHeight = 1000, mult = 1.25, radius = 14 },
	{ id = "squirrel", name = "용문산 다람쥐", minHeight = 100000, mult = 1.5, radius = 20 },
}

-- 펫 고도화: 레벨·진화·전투
Config.PET = {
	maxLevel = 50,
	evoLevels = { 15, 35 },
	evoMult = { 1, 1.5, 2.2 },
	statPerLevel = 0.12,
	maxTeam = 3,
	maxOwned = 30,
	faintTime = 10,
	attackEvery = 1,
	tick = 0.25,
	baseRange = 14,
	focusMult = 2,
	tameWindow = 8,
	foodXp = 1,
	zoneK = { 1, 4, 15, 40 }, -- 구역별 몬스터 체력·공격 배율
}

local function sp(t)
	return t
end
-- how: height(키 해금) / tame(몬스터 길들이기) / boss(보스 처치)
-- monster: 야생 몬스터일 때 능력치(구역 배율 곱하기 전)
Config.PET_SPECIES = {
	cat = sp({ id = "cat", name = "시장 고양이", stages = { "시장 고양이", "시장 대장 고양이", "물맑은 호랑이" }, zone = 1,
		how = "height", minHeight = 0, atk = 5, hp = 40, mult = 1.1, radius = 8,
		skill = { kind = "burst", cooldown = 12, name = "할퀴기 연타" } }),
	otter = sp({ id = "otter", name = "남한강 수달", stages = { "남한강 수달", "물살 수달", "남한강 수달왕" }, zone = 2,
		how = "height", minHeight = 1000, atk = 7, hp = 50, mult = 1.25, radius = 14,
		skill = { kind = "aoe", cooldown = 15, name = "물대포" } }),
	squirrel = sp({ id = "squirrel", name = "용문산 다람쥐", stages = { "용문산 다람쥐", "도토리 대장", "용문산 산신 다람쥐" }, zone = 3,
		how = "height", minHeight = 100000, atk = 10, hp = 60, mult = 1.5, radius = 20,
		skill = { kind = "aoe", cooldown = 15, name = "도토리 폭격" } }),
	pigeon = sp({ id = "pigeon", name = "시장 비둘기", stages = { "시장 비둘기", "광장 비둘기", "구구 대장" }, zone = 1,
		how = "tame", tameChance = 0.08, atk = 4, hp = 35, mult = 1.05, radius = 10,
		skill = { kind = "burst", cooldown = 12, name = "부리 쪼기" },
		monster = { hp = 30, atk = 2, attackEvery = 1.5, xp = 5, gainMult = 3 } }),
	duck = sp({ id = "duck", name = "양근천 오리", stages = { "양근천 오리", "물장구 오리", "양근천 대장 오리" }, zone = 1,
		how = "tame", tameChance = 0.03, atk = 5, hp = 55, mult = 1.08, radius = 9,
		skill = { kind = "heal", cooldown = 18, name = "꽥꽥 응원" },
		monster = { hp = 50, atk = 3, attackEvery = 1.6, xp = 8, gainMult = 5 } }),
	carp = sp({ id = "carp", name = "두물머리 잉어", stages = { "두물머리 잉어", "황금 잉어", "두물머리 용잉어" }, zone = 2,
		how = "tame", tameChance = 0.08, atk = 8, hp = 60, mult = 1.2, radius = 12,
		skill = { kind = "aoe", cooldown = 16, name = "꼬리 물보라" },
		monster = { hp = 40, atk = 3, attackEvery = 1.5, xp = 12, gainMult = 3 } }),
	heron = sp({ id = "heron", name = "두물머리 왜가리", stages = { "왜가리", "큰 왜가리", "두물머리 학" }, zone = 2,
		how = "tame", tameChance = 0.03, atk = 11, hp = 50, mult = 1.22, radius = 13,
		skill = { kind = "burst", cooldown = 14, name = "부리 창" },
		monster = { hp = 55, atk = 4, attackEvery = 1.4, xp = 18, gainMult = 5 } }),
	boar = sp({ id = "boar", name = "용문산 멧돼지", stages = { "아기 멧돼지", "멧돼지", "용문산 산군 멧돼지" }, zone = 3,
		how = "tame", tameChance = 0.08, atk = 12, hp = 90, mult = 1.4, radius = 15,
		skill = { kind = "burst", cooldown = 15, name = "돌진" },
		monster = { hp = 50, atk = 4, attackEvery = 1.6, xp = 25, gainMult = 3 } }),
	crow = sp({ id = "crow", name = "용문산 까마귀", stages = { "까마귀", "산까마귀", "용문산 까마귀왕" }, zone = 3,
		how = "tame", tameChance = 0.03, atk = 14, hp = 60, mult = 1.42, radius = 18,
		skill = { kind = "aoe", cooldown = 16, name = "깃털 폭풍" },
		monster = { hp = 45, atk = 5, attackEvery = 1.3, xp = 35, gainMult = 5 } }),
	star = sp({ id = "star", name = "별똥별 정령", stages = { "별똥별 정령", "유성 정령", "양평 은하 정령" }, zone = 4,
		how = "tame", tameChance = 0.03, atk = 18, hp = 80, mult = 1.6, radius = 22,
		skill = { kind = "heal", cooldown = 18, name = "별빛 치유" },
		monster = { hp = 60, atk = 6, attackEvery = 1.4, xp = 60, gainMult = 5 } }),
	hotteok = sp({ id = "hotteok", name = "미니 호떡", stages = { "미니 호떡", "꿀 호떡", "황금 대왕 호떡" }, zone = 1,
		how = "boss", atk = 8, hp = 70, mult = 1.15, radius = 12,
		skill = { kind = "aoe", cooldown = 14, name = "뜨거운 시럽" } }),
	catfish = sp({ id = "catfish", name = "미니 메기", stages = { "미니 메기", "수염 메기", "남한강 대왕 메기" }, zone = 2,
		how = "boss", atk = 13, hp = 90, mult = 1.3, radius = 16,
		skill = { kind = "burst", cooldown = 14, name = "수염 채찍" } }),
	cloud = sp({ id = "cloud", name = "미니 구름 용", stages = { "미니 구름 용", "구름 용", "용문산 구름 용왕" }, zone = 3,
		how = "boss", atk = 18, hp = 110, mult = 1.55, radius = 22,
		skill = { kind = "heal", cooldown = 16, name = "구름 이불" } }),
}

-- 2차: 구역 보스
Config.BOSSES = {
	{ zone = 1, name = "물맑은시장 대왕 호떡", maxHp = 3000, attackEvery = 2.5, shockwave = false },
	{ zone = 2, name = "남한강 대왕 메기", maxHp = 20000, attackEvery = 2.0, shockwave = true },
	{ zone = 3, name = "용문산 구름 용", maxHp = 100000, attackEvery = 1.4, shockwave = true },
}
Config.BOSS = {
	timeLimit = 90,
	retryDelay = 30,
	maxHitsPerSec = 8,
	rewardMult = 200, -- 그 구역 최고 음식 × 200
	minShare = 0.05,
	rewardCooldown = 600,
	respawn = 60,
	stun = 0, -- 맞으면 멈추는 시간(초). 0이면 밀려나기만 함
}

-- 2차: 하이파이브
Config.HIGHFIVE = { offerTime = 10, cooldown = 60, duration = 30 }

-- 물맑은시장 장날(3·8일): 1구역 음식 배율
Config.MARKET_DAY_MULT = 2

-- 별자리 따라 걷기 (4구역)
Config.CONSTELLATION = { timeLimit = 40, rewardMult = 40, cooldown = 120 }

-- 효과음: 로블록스에 기본으로 들어 있는 소리(rbxasset://)로 시작.
-- 더 좋은 소리로 바꾸려면 Creator Store(오디오)에서 고른 뒤 "rbxassetid://숫자"로 바꾸면 됨.
-- pitch: 음 높이, volume: 크기
Config.SOUNDS = {
	eat = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.4, pitch = 1.2, jitter = 0.15 },
	golden = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7, pitch = 1.8, double = true },
	goal = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.8, pitch = 0.9, double = true },
	title = { id = "rbxasset://sounds/swoosh.wav", volume = 0.6, pitch = 1.3 },
	bossHit = { id = "rbxasset://sounds/clickfast.wav", volume = 0.6, pitch = 0.8, jitter = 0.2 },
	knock = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.7, pitch = 1.0 },
	victory = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.8, pitch = 1.5, double = true },
	rainWarn = { id = "rbxasset://sounds/button.wav", volume = 0.6, pitch = 0.9, double = true },
	rainStart = { id = "rbxasset://sounds/impact_water.mp3", volume = 0.6, pitch = 1.0 },
	highfive = { id = "rbxasset://sounds/clickfast.wav", volume = 0.8, pitch = 1.4, double = true },
	star = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, pitch = 1.0 },
	notify = { id = "rbxasset://sounds/button.wav", volume = 0.15, pitch = 1.2 },
	footstep = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.8, pitch = 0.45 },
}
Config.BGM = "" -- 배경음악: Creator Store 음악 "rbxassetid://숫자"를 넣으면 계속 재생

-- 환생: 용문산(115,700cm) × (환생 횟수 + 1) 이상이면 가능, 한 번마다 영구 성장 +50%
Config.REBIRTH = { base = 115700, step = 0.5 }

-- 일일 미션 (하나 깰 때마다: 내가 연 가장 높은 구역 최고 음식 × reward, 3개 다 깨면 × allBonus 추가)
Config.QUESTS = {
	perDay = 3,
	reward = 100,
	allBonus = 300,
	pool = {
		{ kind = "food", count = 30, name = "음식 30개 먹기" },
		{ kind = "golden_milk", count = 1, name = "황금 우유 1개 먹기" },
		{ kind = "hoop", count = 5, name = "농구 골 5번 넣기" },
		{ kind = "bar", count = 20, name = "철봉에서 20초 버티기" },
		{ kind = "bed", count = 6, name = "침대에서 30초 자기" },
		{ kind = "rainmilk", count = 5, name = "우유 비 우유 5개 먹기" },
		{ kind = "boss", count = 1, name = "보스 1번 잡기" },
		{ kind = "highfive", count = 1, name = "친구와 하이파이브 1번" },
	},
}

-- 어깨에 태우기: 상대가 나보다 몇 배 커야 탈 수 있나, 최대 몇 명
Config.CARRY = { minRatio = 2, maxRiders = 2 }

Config.AUTOSAVE = 60 -- 초
Config.BOARD_REFRESH = 60 -- 초

return Config
