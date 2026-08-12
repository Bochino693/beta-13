$ErrorActionPreference = "Stop"

$origem = Split-Path -Parent $MyInvocation.MyCommand.Path
$destino = "C:\Users\LAZER GAMES\Documents\beta-13"
$momento = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Host ""
Write-Host "LAZER BEASTS 4.0 - INSTALADOR VERTICAL" -ForegroundColor Cyan
Write-Host "Origem:  $origem"
Write-Host "Destino: $destino"
Write-Host ""

$origemCompleta = [IO.Path]::GetFullPath($origem).TrimEnd('\')
$destinoCompleto = [IO.Path]::GetFullPath($destino).TrimEnd('\')

if (-not (Test-Path -LiteralPath (Join-Path $origem "project.godot"))) {
    throw "project.godot não encontrado ao lado deste instalador. Extraia o ZIP inteiro antes de executar."
}

if ($origemCompleta -ne $destinoCompleto) {
    if (Test-Path -LiteralPath $destino) {
        $backup = "C:\Users\LAZER GAMES\Documents\beta-13-backup-$momento"
        Write-Host "Criando backup em: $backup" -ForegroundColor Yellow
        Copy-Item -LiteralPath $destino -Destination $backup -Recurse -Force
    }
    New-Item -ItemType Directory -Path $destino -Force | Out-Null
    Write-Host "Copiando o projeto completo..." -ForegroundColor Cyan
    Copy-Item -Path (Join-Path $origem "*") -Destination $destino -Recurse -Force
} else {
    Write-Host "O pacote já está na pasta final; nenhuma cópia foi necessária." -ForegroundColor Yellow
}

$imagens = @(Get-ChildItem -LiteralPath (Join-Path $destino "assets\creatures_hd") -Filter "*.png" -File)
$sprites = @(Get-ChildItem -LiteralPath (Join-Path $destino "assets\sprites\beasts") -Filter "*.png" -File)
$golpes = @(Get-ChildItem -LiteralPath (Join-Path $destino "assets\moves_fx") -Filter "*.png" -File)
$cartas = @(Get-ChildItem -LiteralPath (Join-Path $destino "assets\cards") -Filter "*.png" -File)
$cenas = @(Get-ChildItem -LiteralPath (Join-Path $destino "scenes") -Filter "*.tscn" -File)
$scripts = @(Get-ChildItem -LiteralPath (Join-Path $destino "scripts") -Filter "*.gd" -File -Recurse)

if ($imagens.Count -ne 30) {
    throw "Instalação incompleta: eram esperadas 30 imagens HD; foram encontradas $($imagens.Count)."
}
if ($sprites.Count -ne 30 -or $golpes.Count -ne 80 -or $cartas.Count -ne 30) {
    throw "Assets incompletos: sprites=$($sprites.Count), golpes=$($golpes.Count), cartas=$($cartas.Count)."
}
if ($cenas.Count -ne 7) {
    throw "Instalação incompleta: eram esperadas 7 cenas; foram encontradas $($cenas.Count)."
}
if ($scripts.Count -ne 19) {
    throw "Instalação incompleta: eram esperados 19 scripts; foram encontrados $($scripts.Count)."
}

Write-Host ""
Write-Host "INSTALAÇÃO CONCLUÍDA" -ForegroundColor Green
Write-Host "30 Beasts HD, 30 spritesheets, 80 golpes, 30 cartas, 7 cenas e 19 scripts validados." -ForegroundColor Green
Write-Host "Abra no Godot 4.6:" -ForegroundColor Cyan
Write-Host (Join-Path $destino "project.godot")
Write-Host ""
