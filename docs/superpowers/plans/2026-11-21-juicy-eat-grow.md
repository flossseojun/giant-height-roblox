# 먹는 순간·커지는 순간·음식 모양 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 음식을 진짜 모양으로, 먹을 때 빨려 들어오는 연출과 콤보, 커질 때 부드러운 성장과 키 돌파 연출을 넣는다.

**Architecture:** 돌파·콤보·크기 단계 계산은 `Logic/Juice`(luau 테스트). 서버: 음식 파트를 투명 히트박스로(+`FoodId`/`Golden` 속성), 먹은 사람에게 `Ate` 리모트, `applyBody`의 부드러운 크기. 클라이언트: `FoodVisuals`(모양·회전), `Juice`(먹기·콤보·성장·돌파 연출).

**Tech Stack:** Luau, Rojo, luau CLI 테스트.

**Spec:** `docs/superpowers/specs/2026-11-21-juicy-eat-grow-design.md`

## Global Constraints
- 콤보 창 2초. 크기 부드럽게: 차이 ≥ 5%면 5단계·0.3초, 아니면 즉시. 진행 중 새 크기가 오면 이전 단계 취소.
- 돌파 목록 `Config.MILESTONES` (cm, 문구): 30 고양이, 100 강아지, 200 문, 600 2층집, 1200 상가 건물, 4500 아파트, 11400 오스타 코아루, 23600 남산타워, 115700 용문산, 300000 구름, 880000 에베레스트, 1000000000 달까지 가는 길.
- 접속 후 첫 키 값으로는 돌파 연출 없음(이후 증가분만). 한 번에 여러 개 넘으면 가장 큰 것 하나만 크게 + 나머지 생략.
- 음식 모양 파트는 클라이언트에만, 음식당 최대 8파트.
- 커밋 끝에 Co-Authored-By/Claude-Session 줄.

## Review Focus
- 먹은 음식의 모양이 남지 않는다(히트박스 사라지면 모양도 정리).
- 우유 비(수십 개 한꺼번에)에서 FPS가 크게 떨어지지 않는다(회전은 한 루프에서).
- 빠르게 여러 개 먹을 때 크기 단계가 겹쳐 몸이 들쑥날쑥하지 않다(취소 토큰).
- 환생으로 키가 줄어들 때 돌파 연출 없음, 크기는 바로.

---

### Task 1: Juice 계산
**Files:** Create `src/shared/Logic/Juice.luau`; Modify `src/shared/Config.luau`; Test `tests/juice.spec.luau`
**Interfaces:**
- `Config.MILESTONES = { {cm=30, text="고양이만 해졌어요!"}, ... }` (위 목록, 오름차순)
- `Juice.crossed(old: number, new: number, list): {any}` — old < m.cm ≤ new 인 것들(오름차순), new ≤ old면 {}
- `Juice.combo(lastAt: number?, count: number, now: number, window: number): number` — 창 안이면 count+1, 아니면 1
- `Juice.scaleSteps(from: number, to: number, n: number, minRatio: number): {number}` — |to/from−1| < minRatio면 {to}, 아니면 n개 균등 보간(마지막 = to)

- [ ] Step 1 테스트:
```lua
expect(#Juice.crossed(20, 120, Config.MILESTONES)).toBe(2) -- 30, 100
expect(Juice.crossed(20, 120, Config.MILESTONES)[2].cm).toBe(100)
expect(#Juice.crossed(120, 20, Config.MILESTONES)).toBe(0)
expect(#Juice.crossed(30, 30, Config.MILESTONES)).toBe(0)
expect(Juice.combo(nil, 0, 5, 2)).toBe(1); expect(Juice.combo(4, 3, 5, 2)).toBe(4); expect(Juice.combo(1, 3, 5, 2)).toBe(1)
local st = Juice.scaleSteps(1, 2, 5, 0.05); expect(#st).toBe(5); expect(st[5]).toBe(2); expect(st[1]).toBeCloseTo(1.2)
expect(#Juice.scaleSteps(1, 1.01, 5, 0.05)).toBe(1)
for i = 2, #Config.MILESTONES do expect(Config.MILESTONES[i].cm > Config.MILESTONES[i - 1].cm).toBe(true) end
```
- [ ] Step 2 FAIL 확인 → Step 3 구현 → Step 4 `/home/claude/check.sh` `0 failed` → Step 5 커밋 `feat(juice): 돌파·콤보·크기 단계 계산`

### Task 2: 서버 — 히트박스·Ate·부드러운 크기
**Files:** Modify `src/server/Services/FoodService.luau` (`makeFoodPart`: 투명 히트박스, 속성 `FoodId`·`Golden`, 이름표는 유지; `makeEdible`의 먹기 성공 시 `Ate:FireClient(player, food.id, p.Position)`; 모듈 맨 위 `Remotes.get("Ate")`), `src/server/Services/HeightService.luau` (`applyBody`: `Juice.scaleSteps(applied, s, 5, 0.05)`를 0.3초에 걸쳐, 플레이어별 토큰으로 이전 단계 취소; 각 단계 뒤 기존 바닥 맞추기·이동 능력치 갱신)
- [ ] Step 1 구현 → Step 2 `/home/claude/check.sh`, `python3 -m pytest tests/py -q` 통과 → Step 3 커밋 `feat(juice): 음식 히트박스·먹기 알림·부드럽게 커지기`

### Task 3: FoodVisuals — 음식 모양
**Files:** Create `src/client/FoodVisuals.luau`; Modify `src/client/init.client.luau`
**Interfaces:** `workspace.Foods`의 BasePart(속성 `FoodId`)마다 모양 모델(최대 8파트, 히트박스 크기에 비례)을 카메라 폴더에 만들고, 한 RenderStepped 루프에서 회전·둥실; 히트박스가 사라지면 모양 삭제. `FoodVisuals.shapeOf(id, size): Model` 공개(먹기 연출이 복제해서 씀). 16종 모양 = 12종 + golden_milk(금색 네온 우유팩) + rainmilk(작은 우유팩).
- [ ] Step 1 구현 → Step 2 `/home/claude/check.sh` 통과 → Step 3 커밋 `feat(juice): 진짜 모양 음식`

### Task 4: Juice 클라이언트 — 먹기·콤보·성장·돌파 연출
**Files:** Create `src/client/JuiceFx.luau`; Modify `src/client/Hud.luau` (`Gained` 팝업: 음식 id면 "+N cm 이름", 콤보 2 이상이면 "콤보 ×N"), `src/client/init.client.luau`
**Interfaces:** `Ate(foodId, pos)` → `FoodVisuals.shapeOf` 복제가 0.25초에 머리로 날아오며 작아짐, 음식 색 부스러기 8개, `SoundFx.play("eat", 1 + 0.06·(콤보−1) 최대 1.6)`; 내 `Height` 증가 → 발밑 반짝이(ParticleEmitter Emit), 카메라 FOV 70→74→70(0.4초); `Juice.crossed`로 돌파 → 화면 가운데 배너(문구 + "키 N 돌파!"), 흰 번쩍(0.15초), 충격파 링(커지며 투명), `SoundFx.play("victory")`. 접속 후 첫 Height는 기준값만 저장.
- [ ] Step 1 구현 → Step 2 `/home/claude/check.sh` 통과 → Step 3 커밋 `feat(juice): 먹기·콤보·성장·돌파 연출`

### Task 5: 문서 (Studio 확인은 사용자 연결 때)
**Files:** `docs/PLAYTEST.md` 24번, `README.md`
- [ ] 문서 갱신, `/home/claude/check.sh` 통과, 커밋·푸시
