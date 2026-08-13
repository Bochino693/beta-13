@echo off
setlocal
cd /d "%~dp0"

set "GODOT_EXE="
for %%G in (godot.exe godot4.exe) do (
    where %%G >nul 2>nul && set "GODOT_EXE=%%G"
)

if not defined GODOT_EXE if exist "%LOCALAPPDATA%\Programs\Godot\Godot_v4.6-stable_win64.exe" set "GODOT_EXE=%LOCALAPPDATA%\Programs\Godot\Godot_v4.6-stable_win64.exe"
if not defined GODOT_EXE if exist "%USERPROFILE%\Downloads\Godot_v4.6-stable_win64.exe" set "GODOT_EXE=%USERPROFILE%\Downloads\Godot_v4.6-stable_win64.exe"
if not defined GODOT_EXE for %%G in ("%USERPROFILE%\Downloads\Godot_v4.6*.exe") do if exist "%%~fG" set "GODOT_EXE=%%~fG"
if not defined GODOT_EXE for %%G in ("%USERPROFILE%\Desktop\Godot_v4.6*.exe") do if exist "%%~fG" set "GODOT_EXE=%%~fG"

if not defined GODOT_EXE (
    echo.
    echo GODOT 4.6 NAO FOI ENCONTRADO.
    echo Instale o Godot 4.6 ou coloque o executavel na pasta Downloads.
    echo.
    pause
    exit /b 1
)

echo Executando a batalha diretamente...
"%GODOT_EXE%" --path "%~dp0" "res://scenes/battle.tscn"
if errorlevel 1 pause
