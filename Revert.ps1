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

# DNS: restore the original resolver list (DHCP automatic if it was empty)
$dnsBak = Join-Path $root 'backup\dns-backup.json'
if (Test-Path $dnsBak) {
    try {
        foreach ($r in @(Get-Content $dnsBak -Raw | ConvertFrom-Json)) {
            if (@($r.Servers).Count -gt 0) {
                Set-DnsClientServerAddress -InterfaceIndex $r.InterfaceIndex -ServerAddresses @($r.Servers) -ErrorAction Stop
            } else {
                Reset-DnsClientServerAddress -InterfaceIndex $r.InterfaceIndex -ErrorAction SilentlyContinue
            }
            Write-Host ("  restored DNS on {0}" -f $r.Name) -ForegroundColor Green
        }
    } catch {
        Write-Host ("  DNS restore failed: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
    }
}

# Undo the search UI disable: task, renamed executable, owner
& schtasks.exe /Delete /TN 'SearchHost-Kill' /F 2>&1 | Out-Null
& schtasks.exe /Delete /TN 'SearchHost-Trim' /F 2>&1 | Out-Null
$marker = Join-Path $root 'backup\searchui-disabled.json'
if (Test-Path $marker) {
    try {
        $m = Get-Content $marker -Raw | ConvertFrom-Json
        $disabled = $m.DisabledPath
        $original = $m.OriginalPath
        if ((Test-Path $disabled) -and -not (Test-Path $original)) {
            & takeown.exe /f $disabled 2>&1 | Out-Null
            & icacls.exe $disabled /grant '*S-1-5-32-544:F' 2>&1 | Out-Null
            Rename-Item -Path $disabled -NewName (Split-Path $original -Leaf) -Force -ErrorAction Stop
            & icacls.exe $original /setowner 'NT SERVICE\TrustedInstaller' 2>&1 | Out-Null
            Write-Host ("  restored {0}" -f $original) -ForegroundColor Green
        }
        Remove-Item $marker -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host ("  SearchHost restore failed: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
    }
}

Write-Host ''
Write-Host 'Revert complete. Reboot recommended.' -ForegroundColor Cyan
Write-Host 'Note: uninstalled Store apps have to be installed again from the Store.' -ForegroundColor Yellow
