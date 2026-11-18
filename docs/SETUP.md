# 처음 한 번만 하는 설치 (Windows 기준, 20~30분)

Mac이면 Claude에게 "Mac이야"라고 말해 줘. 방법이 조금 달라.

## 1. 로블록스 스튜디오 설치
1. https://create.roblox.com 접속 → 로그인 → **Start Creating** (또는 "Studio 다운로드")
2. 설치 후 스튜디오를 켜서 로그인까지 해 두기

## 2. GitHub Desktop으로 프로젝트 받기
코드는 Claude가 깃허브에 올리고, 서준이 컴퓨터는 그걸 받기만 하면 돼.
1. https://desktop.github.com 에서 GitHub Desktop 설치 → flossseojun 계정으로 로그인
2. **File → Clone repository** → `flossseojun/giant-height-roblox` 선택
3. 저장 위치는 기억하기 쉬운 곳으로 (예: `문서\GitHub\giant-height-roblox`) → **Clone**

## 3. Rojo 설치 (자동)
1. 받은 폴더를 열고 **`setup.bat`** 더블클릭
   - "Windows의 PC 보호" 창이 뜨면 **추가 정보 → 실행**
2. "완료!"가 뜨면 아무 키나 눌러 닫기
3. 스튜디오를 켜져 있었다면 껐다 다시 켜기 → 위쪽 **Plugins** 탭에 **Rojo** 버튼이 생겼는지 확인

> setup.bat이 실패하면: 스튜디오 Toolbox(또는 Creator Store)에서 "Rojo"를 검색해 **Rojo (작성자 Rojo)** 플러그인을 설치하고, https://github.com/rojo-rbx/rojo/releases/tag/v7.6.1 에서 `rojo-7.6.1-windows-x86_64.zip`을 받아 안의 `rojo.exe`를 프로젝트 폴더에 넣어도 돼.

## 4. 연결해 보기
1. 스튜디오에서 **새 게임 → Baseplate** 열기
2. 프로젝트 폴더의 **`serve.bat`** 더블클릭 → 까만 창은 켜 둔 채로
3. 스튜디오 **Plugins → Rojo** → 뜨는 창에서 **Connect**
4. 스튜디오 위쪽 **▶ Play** → 아래 **Output** 창(안 보이면 View → Output)에 아래 두 줄이 나오면 성공!
   - `[거인 키 키우기] 서버 시작`
   - `[거인 키 키우기] 클라 시작`
5. 이 게임을 **File → Save to Roblox**로 저장해 두기 (이름: 거인 키 키우기)

## 앞으로 업데이트 받는 법 (매번)
1. GitHub Desktop에서 **Fetch origin → Pull origin**
2. `serve.bat` 켜고 스튜디오에서 Rojo **Connect** → 바뀐 코드가 자동으로 들어감
3. Play로 테스트 → 문제 있으면 Output의 빨간 글자를 복사해서 Claude에게

## 주의
- 코드(스크립트)는 Rojo가 관리하니까 스튜디오 안에서 스크립트를 직접 고치면 다음 Connect 때 덮어써져. 고치고 싶은 건 Claude에게 말해 줘.
- 맵(파트, 장식)은 스튜디오에서 마음대로 만들고 꾸며도 돼. Rojo는 맵을 건드리지 않아.
