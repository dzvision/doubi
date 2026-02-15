@echo off
chcp 65001 >nul
:: =============================
:: 自动提权：如果不是管理员，则以管理员身份重新运行自己
:: =============================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo 请求管理员权限...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)
:: 如果已提权，继续执行后续代码
chcp 65001 >nul

set "VPNUI_PATH=C:\Program Files (x86)\Cisco\Cisco AnyConnect Secure Mobility Client\vpnui.exe"

if not exist "%VPNUI_PATH%" (
    echo 错误：未找到 vpnui.exe，请确认 AnyConnect 已安装。
    pause
    exit /b 1
)

:: 检查当前服务状态：是否已运行（STATE 4）
call :IsServiceRunning vpnagent
if %errorlevel% == 0 (
    echo Cisco AnyConnect 服务已在运行。
    goto launch_ui
)

:: 启动服务
echo 正在启动 Cisco AnyConnect 服务...
sc start vpnagent >nul

:: 等待服务进入 RUNNING 状态（最多 15 秒）
set wait_count=0
:wait_loop
timeout /t 1 /nobreak >nul
call :IsServiceRunning vpnagent
if %errorlevel% == 0 (
    echo 服务已成功启动。
    goto launch_ui
)
set /a wait_count+=1
if %wait_count% lss 15 goto wait_loop

echo 错误：超时，vpnagent 服务未能进入运行状态。
pause
exit /b 1

:launch_ui
start "" "%VPNUI_PATH%"
exit /b 0


:: ==============================
:: 函数：IsServiceRunning <service_name>
:: 返回 0 表示正在运行（STATE 4），非 0 表示未运行或启动中/停止中
:: ==============================
:IsServiceRunning
sc query %1 | findstr /r /c:"^.*STATE.*4" >nul
exit /b %errorlevel%