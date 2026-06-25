@echo off
cd /d "%~dp0"

echo ========================================
echo  ProcesAI n8n stack launcher
echo ========================================
echo.

del tunnel_url.txt tunnel_url_snippet.txt tunnel_log.txt 2>nul

echo [1/2] Spoustim n8n (port 5678)...
start "n8n" cmd /k "cd /d "%~dp0" && set N8N_CORS_ALLOWED_ORIGINS=https://czvok009.github.io && npx n8n start"

echo       Cekam 5 s, nez n8n nastartuje...
timeout /t 5 /nobreak >nul

echo [2/2] Spoustim cloudflared tunel...
start "cloudflared" powershell -NoExit -ExecutionPolicy Bypass -File "%~dp0run_tunnel.ps1"

echo.
echo Cekam na URL tunelu (max 60 s)...
set /a WAIT=0
:wait_loop
if exist tunnel_url.txt goto url_ready
set /a WAIT+=2
if %WAIT% geq 60 goto url_timeout
timeout /t 2 /nobreak >nul
goto wait_loop

:url_ready
echo.
echo ========================================
echo  Tunel je pripraven!
echo ========================================
echo.
type tunnel_url.txt
echo.
echo Radek pro index.html (radka ~364):
type tunnel_url_snippet.txt
echo.
echo Soubory:
echo   tunnel_url.txt          - jen URL
echo   tunnel_url_snippet.txt  - radek pro vlozeni do index.html
echo.
echo Okna "n8n" a "cloudflared" nechte bezet.
goto end

:url_timeout
echo.
echo URL se zatim nepodarilo zachytit.
echo Podivejte se do okna "cloudflared" nebo do tunnel_log.txt.
echo.

:end
pause
