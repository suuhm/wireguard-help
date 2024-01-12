@echo off
setlocal enabledelayedexpansion

REM -----------------------
REM WG_HELP_WIN Batch v0.1
REM
REM   (c) 2023 by suuhm
REM -----------------------

:: Check for exec as admin
net session >nul 2>&1
if not %errorlevel% == 0 (
    echo [!!] You need to run this script /w admin rights.
    echo exit - %~dp0wg-help_config.ini 
    pause
    exit /b
)

REM Default variables
set "wgpath=%ProgramFiles%\WireGuard\wireguard.exe"
set "confPath=%tmp%\wg0.conf"
set "device=wg0"

REM Check if the ini file exists, if not, create it
if not exist %~dp0wg-help_config.ini (
    echo [Settings]>%~dp0wg-help_config.ini
    echo wgpath=!wgpath!>>%~dp0wg-help_config.ini
    echo confPath=!confPath!>>%~dp0wg-help_config.ini
    echo device=!device!>>%~dp0wg-help_config.ini
)

REM Function to read values from ini file
:readini
for /f "tokens=1,* delims==" %%a in (%~dp0wg-help_config.ini) do (
    if /i "%%a"=="wgpath" set "wgpath=%%b"
    if /i "%%a"=="confPath" set "confPath=%%b"
    if /i "%%a"=="device" set "device=%%b"
)


REM Display menu
:menu
set /a choice=0 
cls
echo  ***************************
echo  *  W G - H E L P - W I N  *
echo  *  ---------------------  *
echo  *   (c) 2023 by suuhm     *
echo  *                         *
echo  *  WireGuard Control Menu *
echo  *  ---------------------- *
REM DEBUGGING:
REM echo !wgpath! - !confPath!
echo  ***************************
echo\
echo 1. Start tunnel
echo 2. Stop tunnel
echo 3. List / Status
echo 4. Help
echo 5. Exit
echo\

REM Get user input
set /p choice="Enter your choice (1-4): "



if "%choice%"=="1" (
    goto :start
) else if "%choice%"=="2" (
    goto :stop
) else if "%choice%"=="3" (
    goto :list
) else if "%choice%"=="4" (
    goto :help
) else if "%choice%"=="5" (
    REM exit /B 0
    goto exitp
) else (
    echo Invalid choice. Please try again.
    timeout /nobreak /t 2 >nul
    goto menu
)

:start
cls
echo Starting WireGuard...
set /p "confPath=Enter the path of the configuration file [%confPath%]: "
REM set "confPath=!confPathInput!"" || set "confPath=%confPath%"
echo Starting now on path: !confPath!
echo\
"%wgpath%" /installtunnelservice !confPath!
timeout /nobreak /t 3 >nul
goto menu

:stop
cls
echo Stopping WireGuard...
set /p "device=Enter the device name [default is '%device%']: "
REM set "device=!deviceInput!"" || set "device=%device%"
echo Stopping now device: !device!
echo\
"%wgpath%" /uninstalltunnelservice !device!
timeout /nobreak /t 3 >nul
goto menu

:list
cls
echo [*] Get list of wireguard services ^& devices:
echo ----------------------------------------------
echo\
sc query type= service state= all | find "SERVICE_NAME: WireG"
echo\
wg
echo\
echo\
echo Done, press enter to get back to menu. 
pause >nul
goto menu

:help
cls
echo Displaying WireGuard help...
"%wgpath%" -h
timeout /nobreak /t 2 >nul
goto menu

:exitp
echo Done, bye
pause
