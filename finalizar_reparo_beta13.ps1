param(
    [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\')

if (-not (Test-Path (Join-Path $ProjectRoot "project.godot"))) {
    if (Test-Path (Join-Path $PSScriptRoot "project.godot")) {
        $ProjectRoot = [System.IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\')
    } else {
        throw "project.godot nao encontrado. Execute este arquivo na raiz do beta-13."
    }
}

Set-Location $ProjectRoot

Write-Host ""
Write-Host "=== VALIDACAO FINAL BETA-13 ===" -ForegroundColor Cyan
Write-Host "Projeto: $ProjectRoot" -ForegroundColor Green

# ---------------------------------------------------------------------------
# 1. Confere se o cache .godot foi realmente apagado.
# ---------------------------------------------------------------------------
$godotCache = Join-Path $ProjectRoot ".godot"
if (Test-Path $godotCache) {
    Write-Warning ".godot existe novamente. Se o Godot estiver fechado, isso pode ser cache recriado por outro processo."
} else {
    Write-Host "OK: cache .godot esta limpo." -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 2. Confere class_name duplicado usando apenas recursos compativeis
#    com Windows PowerShell 5.1 / .NET Framework.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Verificando class_name duplicado..." -ForegroundColor Cyan

$classMap = @{}
$duplicatesFound = New-Object System.Collections.Generic.List[string]

$gdFiles = Get-ChildItem -Path (Join-Path $ProjectRoot "scripts") -Recurse -File -Filter "*.gd"

foreach ($file in $gdFiles) {
    $match = Select-String -Path $file.FullName -Pattern '^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)\s*$' |
        Select-Object -First 1

    if ($null -eq $match) {
        continue
    }

    $className = $match.Matches[0].Groups[1].Value

    # Compatibilidade com PowerShell 5.1:
    $relative = $file.FullName
    if ($relative.StartsWith($ProjectRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relative = $relative.Substring($ProjectRoot.Length).TrimStart('\')
    }

    if ($classMap.ContainsKey($className)) {
        $duplicatesFound.Add(
            "$className`n  1: $($classMap[$className])`n  2: $relative"
        )
    } else {
        $classMap[$className] = $relative
    }
}

if ($duplicatesFound.Count -gt 0) {
    Write-Host ""
    Write-Host "ERRO: AINDA HA CLASS_NAME DUPLICADO:" -ForegroundColor Red
    foreach ($dup in $duplicatesFound) {
        Write-Host $dup -ForegroundColor Red
        Write-Host ""
    }
    exit 2
}

Write-Host "OK: nenhum class_name duplicado encontrado em scripts/." -ForegroundColor Green

# ---------------------------------------------------------------------------
# 3. Confere as classes essenciais da batalha ativa.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Conferindo classes essenciais..." -ForegroundColor Cyan

$expected = @{
    "BattleStadium3D"          = "scripts\components\battle_stadium_3d.gd"
    "BattleShieldDome3D"       = "scripts\components\battle_shield_dome_3d.gd"
    "CinematicBeastSprite3D"   = "scripts\components\cinematic_beast_sprite_3d.gd"
    "CinematicBeastSprite3DV5" = "scripts\components\cinematic_beast_sprite_3d_v5.gd"
    "BattleStadium3DV2"        = "scripts\components\battle_stadium_3d_v2.gd"
    "PhysicalProjectile"       = "scripts\components\physical_projectile.gd"
    "BattleUIV2"               = "scripts\ui\battle_ui_v2.gd"
}

$missing = $false

foreach ($name in $expected.Keys) {
    if (-not $classMap.ContainsKey($name)) {
        Write-Host "FALTA: $name" -ForegroundColor Red
        $missing = $true
        continue
    }

    $actual = $classMap[$name].Replace("/", "\")
    $want = $expected[$name]

    if ($actual -ieq $want) {
        Write-Host "OK: $name -> $actual" -ForegroundColor Green
    } else {
        Write-Host "ATENCAO: $name esta em $actual; esperado $want" -ForegroundColor Yellow
    }
}

if ($missing) {
    Write-Host ""
    Write-Host "Existem classes essenciais ausentes. Nao abra a batalha ainda." -ForegroundColor Red
    exit 3
}

# ---------------------------------------------------------------------------
# 4. Confere se as duplicatas conhecidas realmente foram removidas.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Conferindo copias antigas..." -ForegroundColor Cyan

$mustNotExist = @(
    "scripts\scenes\battle_stadium_3d_v2.gd",
    "scripts\scenes\cinematic_beast_sprite_3d_v5.gd",
    "scripts\scenes\physical_projectile.gd",
    "scripts\scenes\battle_ui_v2.gd"
)

$badCopy = $false

foreach ($rel in $mustNotExist) {
    $p = Join-Path $ProjectRoot $rel
    if (Test-Path $p) {
        Write-Host "AINDA EXISTE: $rel" -ForegroundColor Red
        $badCopy = $true
    } else {
        Write-Host "OK removido: $rel" -ForegroundColor DarkGreen
    }
}

if ($badCopy) {
    exit 4
}

# ---------------------------------------------------------------------------
# 5. Teste estrutural Python, se disponivel.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Rodando tools\verificar_batalha.py..." -ForegroundColor Cyan

$python = Get-Command python -ErrorAction SilentlyContinue
$verifier = Join-Path $ProjectRoot "tools\verificar_batalha.py"

if ($null -ne $python -and (Test-Path $verifier)) {
    & python $verifier
    $code = $LASTEXITCODE

    if ($code -ne 0) {
        Write-Host ""
        Write-Host "A limpeza de classes esta correta, mas o verificador Python encontrou outro erro do projeto." -ForegroundColor Yellow
        Write-Host "Copie e envie aqui as linhas ERRO: mostradas acima." -ForegroundColor Yellow
        exit $code
    }

    Write-Host "OK: verificar_batalha.py passou." -ForegroundColor Green
} else {
    Write-Warning "Python ou tools\verificar_batalha.py nao encontrado. A validacao de classes passou, mas o teste Python foi pulado."
}

Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host "REPARO VALIDADO COM SUCESSO." -ForegroundColor Green
Write-Host "Agora abra o project.godot no Godot e rode a batalha." -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green
