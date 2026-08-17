@echo off
setlocal EnableExtensions
title Elemental Beasts V9 - Movimento Real

set "PACOTE=%~dp0"
set "PROJETO=%PACOTE%"

if not exist "%PROJETO%project.godot" set "PROJETO=%PACOTE%..\"
if not exist "%PROJETO%project.godot" (
  echo.
  echo ERRO: project.godot nao foi encontrado.
  echo Extraia esta pasta dentro da pasta principal do beta-13 e execute novamente.
  echo.
  pause
  exit /b 1
)

set "MARCA=%DATE:/=-%_%TIME::=-%"
set "MARCA=%MARCA: =0%"
set "BACKUP=%PROJETO%backup_antes_v9_%MARCA:.=-%"

mkdir "%BACKUP%\scripts\components" >nul 2>&1
mkdir "%BACKUP%\scripts\scenes" >nul 2>&1

if exist "%PROJETO%scripts\components\cinematic_beast_sprite_3d_v5.gd" copy /Y "%PROJETO%scripts\components\cinematic_beast_sprite_3d_v5.gd" "%BACKUP%\scripts\components\" >nul
if exist "%PROJETO%scripts\scenes\battle_v2.gd" copy /Y "%PROJETO%scripts\scenes\battle_v2.gd" "%BACKUP%\scripts\scenes\" >nul

xcopy /E /I /Y "%PACOTE%payload\*" "%PROJETO%" >nul
if errorlevel 1 (
  echo.
  echo ERRO ao copiar a atualizacao. Nenhum backup foi apagado.
  pause
  exit /b 1
)

echo.
echo ATUALIZACAO V9 APLICADA COM SUCESSO.
echo Backup criado em:
echo %BACKUP%
echo.
echo Abra o Godot e teste o modo CPU e o duelo local.
pause
exit /b 0
