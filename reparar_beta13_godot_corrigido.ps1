param(
    [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Cyan
}

# Permite executar o arquivo de dentro da pasta do projeto ou passar -ProjectRoot.
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
if (-not (Test-Path (Join-Path $ProjectRoot "project.godot"))) {
    if (Test-Path (Join-Path $PSScriptRoot "project.godot")) {
        $ProjectRoot = $PSScriptRoot
    } else {
        throw "project.godot nao encontrado. Execute na raiz do beta-13 ou use -ProjectRoot `"C:\caminho\beta-13`"."
    }
}

Set-Location $ProjectRoot
Write-Host "Projeto: $ProjectRoot" -ForegroundColor Green

$required = @(
    "project.godot",
    "scripts/scenes/battle.gd",
    "scripts/components/battle_stadium_3d.gd",
    "scripts/components/battle_shield_dome_3d.gd",
    "scripts/components/cinematic_beast_sprite_3d.gd"
)

foreach ($rel in $required) {
    if (-not (Test-Path (Join-Path $ProjectRoot $rel))) {
        throw "Arquivo obrigatorio ausente: $rel"
    }
}

# ---------------------------------------------------------------------------
# 1. Backup seguro dos arquivos que serao modificados/removidos
# ---------------------------------------------------------------------------
Write-Step "1/7 - Criando backup de seguranca"

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$parent = Split-Path $ProjectRoot -Parent
$backupRoot = Join-Path $parent ("beta13_repair_backup_" + $stamp)
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

$affected = @(
    ".gitignore",
    "scripts/components/cinematic_beast_sprite_3d_v5.gd",
    "scripts/components/cinematic_beast_sprite_3d_v5.gd.uid",
    "scripts/scenes/battle_v2.gd",
    "scripts/scenes/battle_stadium_3d_v2.gd",
    "scripts/scenes/battle_stadium_3d_v2.gd.uid",
    "scripts/scenes/cinematic_beast_sprite_3d_v5.gd",
    "scripts/scenes/cinematic_beast_sprite_3d_v5.gd.uid",
    "scripts/scenes/physical_projectile.gd",
    "scripts/scenes/physical_projectile.gd.uid",
    "scripts/scenes/battle_ui_v2.gd",
    "scripts/scenes/battle_ui_v2.gd.uid"
)

foreach ($rel in $affected) {
    $src = Join-Path $ProjectRoot $rel
    if (Test-Path $src) {
        $dst = Join-Path $backupRoot $rel
        $dstDir = Split-Path $dst -Parent
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
        Copy-Item $src $dst -Force
    }
}
Write-Host "Backup: $backupRoot" -ForegroundColor DarkGray

# ---------------------------------------------------------------------------
# 2. Impede o Godot de varrer PAYLOADs e backups locais
# ---------------------------------------------------------------------------
Write-Step "2/7 - Isolando backups e PAYLOADs do scanner do Godot"

$legacyDirs = Get-ChildItem -Path $ProjectRoot -Directory | Where-Object {
    $_.Name -like "_backup_*" -or $_.Name -like "PAYLOAD_BATALHA_*"
}

foreach ($dir in $legacyDirs) {
    $gdignore = Join-Path $dir.FullName ".gdignore"
    if (-not (Test-Path $gdignore)) {
        New-Item -ItemType File -Path $gdignore -Force | Out-Null
        Write-Host "Ignorado pelo Godot: $($dir.Name)"
    } else {
        Write-Host "Ja ignorado: $($dir.Name)"
    }
}

# ---------------------------------------------------------------------------
# 3. Separa a classe experimental V5 da classe V3 usada pela partida atual
# ---------------------------------------------------------------------------
Write-Step "3/7 - Corrigindo colisao CinematicBeastSprite3D"

$v5Path = Join-Path $ProjectRoot "scripts/components/cinematic_beast_sprite_3d_v5.gd"
$battleV2Path = Join-Path $ProjectRoot "scripts/scenes/battle_v2.gd"

if (Test-Path $v5Path) {
    $v5 = Get-Content -Raw -Encoding UTF8 $v5Path
    $v5Fixed = [regex]::Replace(
        $v5,
        '(?m)^\s*class_name\s+CinematicBeastSprite3D\s*$',
        'class_name CinematicBeastSprite3DV5',
        1
    )
    if ($v5Fixed -eq $v5 -and $v5 -notmatch '(?m)^\s*class_name\s+CinematicBeastSprite3DV5\s*$') {
        throw "Nao consegui localizar class_name CinematicBeastSprite3D em $v5Path"
    }
    Set-Content -Path $v5Path -Value $v5Fixed -Encoding UTF8
    Write-Host "V5 agora usa class_name CinematicBeastSprite3DV5"
}

if (Test-Path $battleV2Path) {
    $battleV2 = Get-Content -Raw -Encoding UTF8 $battleV2Path
    $battleV2Fixed = $battleV2.Replace("CinematicBeastSprite3D", "CinematicBeastSprite3DV5")
    Set-Content -Path $battleV2Path -Value $battleV2Fixed -Encoding UTF8
    Write-Host "battle_v2.gd atualizado para a classe V5 separada"
}

# ---------------------------------------------------------------------------
# 4. Remove somente COPIAS duplicadas; mantem os arquivos canonicos
# ---------------------------------------------------------------------------
Write-Step "4/7 - Removendo copias globais duplicadas"

$duplicates = @(
    "scripts/scenes/battle_stadium_3d_v2.gd",
    "scripts/scenes/battle_stadium_3d_v2.gd.uid",
    "scripts/scenes/cinematic_beast_sprite_3d_v5.gd",
    "scripts/scenes/cinematic_beast_sprite_3d_v5.gd.uid",
    "scripts/scenes/physical_projectile.gd",
    "scripts/scenes/physical_projectile.gd.uid",
    "scripts/scenes/battle_ui_v2.gd",
    "scripts/scenes/battle_ui_v2.gd.uid"
)

foreach ($rel in $duplicates) {
    $path = Join-Path $ProjectRoot $rel
    if (Test-Path $path) {
        Remove-Item $path -Force
        Write-Host "Removida duplicata: $rel"
    }
}

# Canonicos preservados:
# - scripts/components/battle_stadium_3d_v2.gd
# - scripts/components/physical_projectile.gd
# - scripts/components/cinematic_beast_sprite_3d_v5.gd (classe CinematicBeastSprite3DV5)
# - scripts/ui/battle_ui_v2.gd
# - scripts/components/cinematic_beast_sprite_3d.gd (V3 usada pela battle.tscn atual)

# ---------------------------------------------------------------------------
# 5. Evita que novos backups/PAYLOADs entrem no Git
# ---------------------------------------------------------------------------
Write-Step "5/7 - Atualizando .gitignore"

$gitignorePath = Join-Path $ProjectRoot ".gitignore"
$gitignore = ""
if (Test-Path $gitignorePath) {
    $gitignore = Get-Content -Raw -Encoding UTF8 $gitignorePath
}

$patterns = @(
    "/_backup_*/",
    "/PAYLOAD_BATALHA_*/"
)

foreach ($pattern in $patterns) {
    $escapedPattern = [regex]::Escape($pattern)
    if ($gitignore -notmatch "(?m)^$escapedPattern\s*$") {
        if ($gitignore.Length -gt 0 -and -not $gitignore.EndsWith("`n")) {
            $gitignore += "`r`n"
        }
        $gitignore += $pattern + "`r`n"
        Write-Host "Adicionado ao .gitignore: $pattern"
    }
}
Set-Content -Path $gitignorePath -Value $gitignore -Encoding UTF8

# ---------------------------------------------------------------------------
# 6. Apaga SOMENTE cache gerado do Godot
# ---------------------------------------------------------------------------
Write-Step "6/7 - Limpando cache global de classes"

$godotCache = Join-Path $ProjectRoot ".godot"
if (Test-Path $godotCache) {
    Remove-Item $godotCache -Recurse -Force
    Write-Host ".godot removido. O Godot vai recria-lo corretamente."
} else {
    Write-Host ".godot nao existia."
}

# ---------------------------------------------------------------------------
# 7. Confere class_name duplicado nos scripts ativos
# ---------------------------------------------------------------------------
Write-Step "7/7 - Validando classes globais"

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
    $relative = [System.IO.Path]::GetRelativePath($ProjectRoot, $file.FullName)

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
    Write-Host "AINDA HA CLASS_NAME DUPLICADO:" -ForegroundColor Red
    foreach ($dup in $duplicatesFound) {
        Write-Host $dup -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "O backup das alteracoes esta em: $backupRoot" -ForegroundColor Yellow
    exit 2
}

$checks = @{
    "BattleStadium3D" = "scripts/components/battle_stadium_3d.gd"
    "BattleShieldDome3D" = "scripts/components/battle_shield_dome_3d.gd"
    "CinematicBeastSprite3D" = "scripts/components/cinematic_beast_sprite_3d.gd"
    "CinematicBeastSprite3DV5" = "scripts/components/cinematic_beast_sprite_3d_v5.gd"
    "BattleStadium3DV2" = "scripts/components/battle_stadium_3d_v2.gd"
    "PhysicalProjectile" = "scripts/components/physical_projectile.gd"
    "BattleUIV2" = "scripts/ui/battle_ui_v2.gd"
}

foreach ($name in $checks.Keys) {
    if ($classMap.ContainsKey($name)) {
        Write-Host ("OK: {0} -> {1}" -f $name, $classMap[$name]) -ForegroundColor Green
    } elseif (Test-Path (Join-Path $ProjectRoot $checks[$name])) {
        Write-Warning "Arquivo existe, mas class_name esperado nao foi encontrado: $name"
    }
}

Write-Host ""
Write-Step "Teste estrutural da batalha"
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
$battleVerifier = Join-Path $ProjectRoot "tools/verificar_batalha.py"

if ($null -ne $pythonCmd -and (Test-Path $battleVerifier)) {
    & python $battleVerifier
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "O reparo de classes terminou, mas tools/verificar_batalha.py encontrou outro problema estrutural."
    } else {
        Write-Host "verificar_batalha.py: OK" -ForegroundColor Green
    }
} else {
    Write-Warning "Python ou tools/verificar_batalha.py nao encontrado; pulei o teste estrutural."
}

Write-Host ""
Write-Host "REPARO CONCLUIDO." -ForegroundColor Green
Write-Host "Backup de seguranca: $backupRoot"
Write-Host ""
Write-Host "Agora abra o project.godot no Godot 4.6 e rode a partida."
Write-Host "Se quiser conferir o que mudou antes de commitar:"
Write-Host "  git status --short"
Write-Host "  git diff"
