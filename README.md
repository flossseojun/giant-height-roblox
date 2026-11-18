# 거인 키 키우기 (Roblox)

음식을 주워 먹고, 우유 비를 쟁탈하고, 농구·철봉·침대로 키를 키워 **아바타가 진짜로 거인이 되는** 로블록스 시뮬레이터.

- 처음 설치: [docs/SETUP.md](docs/SETUP.md)
- 테스트 체크리스트: [docs/PLAYTEST.md](docs/PLAYTEST.md)
- 설계서 / 계획: `docs/superpowers/`

## 개발자용
- 순수 로직 테스트: `luau tests/run.luau`
- 기본 맵 만들기: `python3 tools/genmap.py && rojo build map.project.json -o map/BaseMap.rbxm` (검사: `python3 tools/map_check.py`)
