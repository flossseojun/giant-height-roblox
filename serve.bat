@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo Rojo 서버를 켰어요. 스튜디오에서 Rojo 플러그인의 Connect를 누르세요.
echo 게임 만드는 동안 이 창은 켜 두세요. (끄려면 이 창을 닫으면 돼요)
echo.
rojo.exe serve default.project.json
pause
