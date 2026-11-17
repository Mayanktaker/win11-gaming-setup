# Revert.ps1 - undo Win11 Gaming Setup (run as Administrator)
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Continue'

$root = 'C:\ProgramData\Win11GamingSetup'
$json = Join-Path $root 'backup\services-backup.json'
if (Test-Path $json) {
    $rows = Get-Content $json -Raw | ConvertFrom-Json
    foreach ($r in $rows) {
        $v = switch ([int]$r.Start) { 0 {'boot'} 1 {'system'} 2 {'auto'} 3 {'demand'} 4 {'disabled'} default {'demand'} }
        & sc.exe config $r.Name start= $v | Out-Null
        Write-Host ("  restored {0} -> {1}" -f $r.Name, $v) -ForegroundColor Green
    }
} else {
    Write-Host "  services-backup.json not found: $json" -ForegroundColor Yellow
}

Get-ChildItem (Join-Path $root 'backup') -Filter '*.reg' -ErrorAction SilentlyContinue | ForEach-Object {
    & reg.exe import $_.FullName 2>&1 | Out-Null
    Write-Host ("  imported {0}" -f $_.Name) -ForegroundColor Green
}

Write-Host ''
Write-Host 'Revert complete. Reboot recommended.' -ForegroundColor Cyan
Write-Host 'Note: uninstalled Store apps have to be installed again from the Store.' -ForegroundColor Yellow
