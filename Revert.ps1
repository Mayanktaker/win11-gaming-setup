# © Mayanktaker Computers & Web Development | https://mayanktaker.com
# Revert.ps1 - undo Win11 Gaming Setup (run as Administrator)
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Continue'

$root = 'C:\ProgramData\Win11GamingSetup'
$logDir = Join-Path $root 'logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$revertLog = Join-Path $logDir ('revert-{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$revertTxtRoot = Join-Path $root 'logs.txt'
$revertTxtLocal = if ($PSScriptRoot) { Join-Path $PSScriptRoot 'logs.txt' } else { $null }

function RLog([string]$msg, [string]$color = 'Gray') {
    Write-Host $msg -ForegroundColor $color
    $line = ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $msg)
    Add-Content -Path $revertLog -Value $line -ErrorAction SilentlyContinue
    Add-Content -Path $revertTxtRoot -Value $line -ErrorAction SilentlyContinue
    if ($revertTxtLocal -and $PSScriptRoot -ne $root -and (Test-Path $PSScriptRoot)) {
        Add-Content -Path $revertTxtLocal -Value $line -ErrorAction SilentlyContinue
    }
}

RLog ('=== Reverting Windows Gaming Setup ({0}) ===' -f (Get-Date)) 'Cyan'
RLog 'Created by Mayanktaker Computers & Web Development' 'Cyan'

# 1. Services
$json = Join-Path $root 'backup\services-backup.json'
if (Test-Path $json) {
    $rows = Get-Content $json -Raw | ConvertFrom-Json
    foreach ($r in $rows) {
        $v = switch ([int]$r.Start) { 0 {'boot'} 1 {'system'} 2 {'auto'} 3 {'demand'} 4 {'disabled'} default {'demand'} }
        & sc.exe config $r.Name start= $v | Out-Null
        RLog ("  restored {0} -> {1}" -f $r.Name, $v) 'Green'
    }
} else {
    RLog "  services-backup.json not found: $json" 'Yellow'
}

# 2. Registry backups
Get-ChildItem (Join-Path $root 'backup') -Filter '*.reg' -ErrorAction SilentlyContinue | ForEach-Object {
    & reg.exe import $_.FullName 2>&1 | Out-Null
    RLog ("  imported {0}" -f $_.Name) 'Green'
}

# 2b. Registry keys the setup created (they were never exported)
$createdJson = Join-Path $root 'backup\created-reg-paths.json'
if (Test-Path $createdJson) {
    try {
        foreach ($c in @(Get-Content $createdJson -Raw | ConvertFrom-Json)) {
            if ($c -and (Test-Path ('Registry::' + $c))) {
                & reg.exe delete $c /f 2>&1 | Out-Null
                RLog ("  removed created key: {0}" -f $c) 'Green'
            }
        }
    } catch {
        RLog ("  created-key removal failed: {0}" -f $_.Exception.Message) 'Yellow'
    }
}

# 3. Power scheme & hibernation
$pSchemeFile = Join-Path $root 'backup\power-scheme.txt'
if (Test-Path $pSchemeFile) {
    try {
        $scheme = (Get-Content $pSchemeFile -Raw).Trim()
        if ($scheme) {
            & powercfg.exe /setactive $scheme 2>&1 | Out-Null
            RLog ("  restored power scheme -> {0}" -f $scheme) 'Green'
        }
    } catch {
        RLog ("  power scheme restore failed: {0}" -f $_.Exception.Message) 'Yellow'
    }
}

# 3b. Hibernation: only re-enable if it was enabled before the setup ran
$hibJson = Join-Path $root 'backup\hibernation-state.json'
$hibWasOn = $false
if (Test-Path $hibJson) {
    try { $hibWasOn = ((Get-Content $hibJson -Raw | ConvertFrom-Json).HibernationOn -eq $true) } catch { }
}
if ($hibWasOn) {
    & powercfg.exe /h on 2>&1 | Out-Null
    RLog "  hibernation re-enabled (it was on before)" 'Green'
} else {
    RLog "  hibernation left off (it was off before)" 'DarkGray'
}

# 3c. Power schemes the setup created are removed again
$createdScheme = Join-Path $root 'backup\power-created.txt'
if (Test-Path $createdScheme) {
    try {
        $cg = (Get-Content $createdScheme -Raw).Trim()
        $activeGuid = [regex]::Match(((powercfg /getactivescheme) -join ' '), '[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}').Value
        if ($cg -and $cg -ne $activeGuid) {
            & powercfg.exe /delete $cg 2>&1 | Out-Null
            RLog ("  removed power scheme created by setup: {0}" -f $cg) 'Green'
        }
        Remove-Item $createdScheme -Force -ErrorAction SilentlyContinue
    } catch {
        RLog ("  created power scheme cleanup failed: {0}" -f $_.Exception.Message) 'Yellow'
    }
}

# 4. SMB1 configuration
$smbReg = Join-Path $root 'backup\smb1.reg'
if (Test-Path $smbReg) {
    & reg.exe import $smbReg 2>&1 | Out-Null
    try { Set-SmbServerConfiguration -EnableSMB1Protocol $true -Force -ErrorAction SilentlyContinue } catch { }
    RLog "  restored SMB1 configuration" 'Green'
}

# 5. Scheduled tasks
$taskJson = Join-Path $root 'backup\tasks-backup.json'
if (Test-Path $taskJson) {
    try {
        $tList = Get-Content $taskJson -Raw | ConvertFrom-Json
        foreach ($t in $tList) {
            $tp = (Split-Path $t -Parent).TrimEnd('\') + '\'
            $tn = Split-Path $t -Leaf
            try {
                Enable-ScheduledTask -TaskPath $tp -TaskName $tn -ErrorAction Stop | Out-Null
                RLog ("  enabled task: {0}" -f $tn) 'Green'
            } catch { }
        }
    } catch {
        RLog ("  tasks restore failed: {0}" -f $_.Exception.Message) 'Yellow'
    }
}

# 6. DNS: restore original resolver list
$dnsBak = Join-Path $root 'backup\dns-backup.json'
if (Test-Path $dnsBak) {
    try {
        foreach ($r in @(Get-Content $dnsBak -Raw | ConvertFrom-Json)) {
            if (@($r.Servers).Count -gt 0) {
                Set-DnsClientServerAddress -InterfaceIndex $r.InterfaceIndex -ServerAddresses @($r.Servers) -ErrorAction Stop
            } else {
                Reset-DnsClientServerAddress -InterfaceIndex $r.InterfaceIndex -ErrorAction SilentlyContinue
            }
            RLog ("  restored DNS on {0}" -f $r.Name) 'Green'
        }
    } catch {
        RLog ("  DNS restore failed: {0}" -f $_.Exception.Message) 'Yellow'
    }
}

# 7. Undo search UI disable: tasks, renamed executable, owner
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
            RLog ("  restored {0}" -f $original) 'Green'
        } elseif ((Test-Path $disabled) -and (Test-Path $original)) {
            Remove-Item $disabled -Force -ErrorAction SilentlyContinue
            RLog ("  removed orphaned disabled copy: {0}" -f $disabled) 'Green'
        }
        Remove-Item $marker -Force -ErrorAction SilentlyContinue
    } catch {
        RLog ("  SearchHost restore failed: {0}" -f $_.Exception.Message) 'Yellow'
    }
}

# 8. Defender preferences: restore the values saved before tuning
$mpBak = Join-Path $root 'backup\defender-preferences.json'
if (Get-Command Set-MpPreference -ErrorAction SilentlyContinue) {
    if (Test-Path $mpBak) {
        try {
            $p = Get-Content $mpBak -Raw | ConvertFrom-Json
            foreach ($prop in $p.PSObject.Properties) {
                try {
                    $h = @{ $prop.Name = $prop.Value }
                    & Set-MpPreference @h -ErrorAction Stop
                } catch { }
            }
            RLog "  Defender preferences restored" 'Green'
        } catch {
            RLog ("  Defender preference restore failed: {0}" -f $_.Exception.Message) 'Yellow'
        }
    } else {
        RLog "  Defender preferences: no backup found (nothing to restore)" 'DarkGray'
    }
} else {
    RLog "  Set-MpPreference not available - Defender preferences skipped" 'DarkGray'
}

RLog ''
RLog 'Revert complete. Reboot recommended.' 'Cyan'
RLog 'Note: uninstalled Store apps have to be installed again from the Store.' 'Yellow'
RLog ('Revert log: {0}' -f $revertLog) 'DarkGray'
RLog ''
RLog '================================================================================' 'Cyan'
RLog '  Created with ❤️ by Mayanktaker Computers & Web Development' 'Cyan'
RLog '  Website: https://mayanktaker.com' 'Green'
RLog '================================================================================' 'Cyan'
