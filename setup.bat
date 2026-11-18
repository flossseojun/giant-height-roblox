@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo [1/2] Rojo 내려받는 중...
curl -L -o rojo.zip https://github.com/rojo-rbx/rojo/releases/download/v7.6.1/rojo-7.6.1-windows-x86_64.zip
if errorlevel 1 goto fail
tar -xf rojo.zip
del rojo.zip
echo [2/2] 로블록스 스튜디오에 Rojo 플러그인 설치 중...
rojo.exe plugin install
if errorlevel 1 goto fail
echo.
echo 완료! 로블록스 스튜디오를 껐다 켜면 위쪽 Plugins 탭에 Rojo가 보여요.
pause
exit /b 0
:fail
echo.
echo 문제가 생겼어요. 이 창 내용을 사진 찍어서 Claude에게 보내 주세요.
pause
exit /b 1
