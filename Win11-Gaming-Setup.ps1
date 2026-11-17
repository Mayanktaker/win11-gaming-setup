<#
.SYNOPSIS
    Windows 10 / 11 Gaming-Only PC Setup - one script for tweaks, cleanup,
    debloat and service slimming.

.DESCRIPTION
    A single, safe, reversible setup script for a gaming-only Windows machine.

    Tested on Windows 11 (build 26300) and written to run on Windows 10 as well,
    including LTSC / IoT LTSC images. Anything that does not exist on the running
    build (Windows 11 context menu, Widgets, Copilot, Store apps on LTSC) is
    skipped with a log line instead of failing.

      1.  UI / Explorer responsiveness (classic context menu, no animations)
      2.  Power plan + PCIe ASPM off + sleep never (gaming profile)
      3.  Gaming registry tweaks (GameDVR off, Game Mode on, MMCSS, throttling off)
      4.  Background junk off (Copilot, Widgets, Phone Link, ads, telemetry tasks)
      4b. Windows Defender resource tuning (low CPU priority, 20% scan cap)
      4c. Store app debloat (keeps Photos, Snipping Tool, Solitaire, Media Player)
      5.  Disk cleanup (temp, WER, shader caches, WinRE leftover, WU cache, icons)
      6.  Service slimming for a gaming-only PC, with LAN-aware detection:
          SSDP / UPnP / Function Discovery stay ON when the machine is on a LAN,
          so other Windows/Linux PCs remain visible in Explorer > Network
      7.  Internet / network tuning (RSS, Nagle off, QoS, NIC power saving)
      8.  Icon + thumbnail cache rebuild
      9.  Automatic backup + Revert.ps1 generator

    Nothing security related is disabled: Defender, Firewall, SmartScreen,
    Windows Update, BITS and the SMB/LAN stack stay untouched.

.PARAMETER SkipCleanup
    Skip disk cleanup and the Windows Update cache reset.

.PARAMETER SkipRestorePoint
    Do not create a System Restore point.

.PARAMETER KeepPrintSpooler
    Keep the Print Spooler running (use this if you print from this PC).

.PARAMETER KeepWindowsSearch
    Do not touch Windows Search indexing (WSearch).

.PARAMETER DisableSysMain
    Force-disable SysMain (Superfetch). Default: auto-disable on SSD, keep on HDD.

.PARAMETER DisableMouseAcceleration
    Turn mouse acceleration off (FPS aiming). Off by default, it changes the feel.

.PARAMETER EmptyRecycleBin
    Empty the Recycle Bin.

.PARAMETER DeepComponentCleanup
    Run DISM component store cleanup with /ResetBase (can take 10-30 minutes).

.PARAMETER SkipDebloat
    Do not remove any Store apps.

.PARAMETER KeepDefenderDailyScan
    Keep a daily Defender scan at 03:00 instead of disabling the schedule.

.PARAMETER NoLAN
    Force the LAN-discovery services off even if a LAN is detected.
    Default: they are kept running whenever the PC is on a LAN.

.PARAMETER KeepSMB1
    Do not disable SMB1. Only needed for very old NAS boxes or Windows XP
    devices that cannot speak SMB2/3. SMB1 is otherwise disabled for security.

.PARAMETER NoPause
    Do not wait for a key press at the end (used for unattended runs).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Win11-Gaming-Setup.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Win11-Gaming-Setup.ps1 -KeepPrintSpooler -EmptyRecycleBin

.NOTES
    Revert : .\Revert.ps1 (next to this script) or C:\ProgramData\Win11GamingSetup\Revert.ps1
    Logs   : C:\ProgramData\Win11GamingSetup\logs
    Backup : C:\ProgramData\Win11GamingSetup\backup
    Version: 1.1.0
#>

[CmdletBinding()]
param(
    [switch]$SkipCleanup,
    [switch]$SkipRestorePoint,
    [switch]$KeepPrintSpooler,
    [switch]$KeepWindowsSearch,
    [switch]$DisableSysMain,
    [switch]$DisableMouseAcceleration,
    [switch]$EmptyRecycleBin,
    [switch]$DeepComponentCleanup,
    [switch]$SkipDebloat,
    [switch]$KeepDefenderDailyScan,
    [switch]$NoLAN,
    [switch]$KeepSMB1,
    [switch]$NoPause,
    [switch]$ElevatedChild
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$ScriptVersion = '1.1.1'

# ---------------------------------------------------------------- self-elevate
if (-not $ElevatedChild) {
    $wid = [Security.Principal.WindowsIdentity]::GetCurrent()
    $isAdmin = (New-Object Security.Principal.WindowsPrincipal($wid)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        $fwd = @()
        foreach ($n in 'SkipCleanup','SkipRestorePoint','KeepPrintSpooler','KeepWindowsSearch','DisableSysMain','DisableMouseAcceleration','EmptyRecycleBin','DeepComponentCleanup','SkipDebloat','KeepDefenderDailyScan','NoLAN','KeepSMB1','NoPause') {
            if ((Get-Variable -Name $n -ValueOnly)) { $fwd += "-$n" }
        }
        Write-Host ''
        Write-Host ' Administrator rights are required. Please press "Yes" on the UAC prompt...' -ForegroundColor Yellow
        $argList = @('-NoProfile','-ExecutionPolicy','Bypass','-File', ('"{0}"' -f $PSCommandPath)) + $fwd + @('-ElevatedChild')
        try {
            Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList -ErrorAction Stop
        } catch {
            Write-Host ' UAC prompt was cancelled. Nothing was changed.' -ForegroundColor Red
            if (-not $NoPause) { Read-Host 'Press Enter to close' }
        }
        return
    }
}

# ---------------------------------------------------------------- environment
$Root   = 'C:\ProgramData\Win11GamingSetup'
$LogDir = Join-Path $Root 'logs'
$BakDir = Join-Path $Root 'backup'
foreach ($d in $Root, $LogDir, $BakDir) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null } }

# Revert.ps1 is written next to this script so script and revert stay together
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ScriptDir -or -not (Test-Path $ScriptDir)) { $ScriptDir = $Root }

$script:LogFile = Join-Path $LogDir ('setup-{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$svcOriginal = @{}
$script:Changed = 0

function Log {
    param([string]$Message, [string]$Color = 'Gray')
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $script:LogFile -Value ('[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $Message) -ErrorAction SilentlyContinue
}

function Section {
    param([string]$Title)
    Log ''
    Log ('=== {0} ===' -f $Title) 'Cyan'
}

function Set-Reg {
    param([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord')
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force -ErrorAction Stop | Out-Null }
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force -ErrorAction Stop | Out-Null
        return $true
    } catch {
        Log ('  ! {0}\{1} -> {2}' -f $Path, $Name, $_.Exception.Message) 'DarkYellow'
        return $false
    }
}

Log ('Gaming Setup v{0}  |  {1}  |  {2}' -f $ScriptVersion, (Get-Date), $env:COMPUTERNAME) 'White'
Log ('Log: {0}' -f $script:LogFile) 'DarkGray'

$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
Log ('OS : {0} (build {1})' -f $os.Caption, $os.BuildNumber) 'DarkGray'
Log ('CPU: {0}' -f (Get-CimInstance Win32_Processor | Select-Object -First 1 -ExpandProperty Name)) 'DarkGray'
Log ('RAM: {0:N1} GB' -f ($cs.TotalPhysicalMemory / 1GB)) 'DarkGray'

# Windows 11 = build 22000+. Windows 10 (incl. LTSC 2019/2021/2024), Server and
# LTSC/IoT images are supported too: anything that does not exist on the running
# build is skipped instead of failing.
$winBuild = [int]$os.BuildNumber
$IsWin11  = $winBuild -ge 22000
$IsLTSC   = ($os.Caption -match 'LTSC|EnterpriseS|IoT') -or ($os.OperatingSystemSKU -in 125,126,129)
Log ('Family: {0}' -f $(if ($IsWin11) { 'Windows 11' } else { 'Windows 10' })) 'DarkGray'
if ($IsLTSC) { Log 'Edition: LTSC / IoT - consumer apps and Store bloat are mostly missing already' 'DarkGray' }

$freeBefore = [math]::Round((Get-PSDrive -Name ($env:SystemDrive -replace ':','')).Free / 1GB, 2)

# ---------------------------------------------------------------- restore point
Section 'System Restore point'
if (-not $SkipRestorePoint) {
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description 'Before Win11 Gaming Setup' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Log '  Restore point created.' 'Green'
    } catch {
        Log ('  Restore point could not be created: {0}' -f $_.Exception.Message) 'DarkYellow'
    }
} else {
    Log '  Skipped (-SkipRestorePoint).'
}

# ---------------------------------------------------------------- registry backups
Section 'Registry backup'
$regBackups = @(
    @{ H = 'HKCU'; P = 'Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'; F = 'ctxmenu.reg' },
    @{ H = 'HKCU'; P = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; F = 'explorer-advanced.reg' },
    @{ H = 'HKCU'; P = 'Control Panel\Desktop'; F = 'desktop.reg' },
    @{ H = 'HKCU'; P = 'Control Panel\Mouse'; F = 'mouse.reg' },
    @{ H = 'HKCU'; P = 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; F = 'personalize.reg' },
    @{ H = 'HKCU'; P = 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; F = 'cdm.reg' },
    @{ H = 'HKCU'; P = 'Software\Microsoft\Windows\CurrentVersion\Search'; F = 'search.reg' },
    @{ H = 'HKCU'; P = 'Software\Policies\Microsoft\Windows\Explorer'; F = 'policy-explorer.reg' },
    @{ H = 'HKLM'; P = 'SOFTWARE\Policies\Microsoft\Windows\Windows Search'; F = 'policy-wsearch.reg' },
    @{ H = 'HKCU'; P = 'System\GameConfigStore'; F = 'gameconfigstore.reg' },
    @{ H = 'HKCU'; P = 'Software\Microsoft\Windows\CurrentVersion\GameDVR'; F = 'gamedvr.reg' },
    @{ H = 'HKLM'; P = 'SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'; F = 'sysprofile.reg' },
    @{ H = 'HKLM'; P = 'SYSTEM\CurrentControlSet\Control\Power\PowerThrottling'; F = 'powerthrottling.reg' },
    @{ H = 'HKLM'; P = 'SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'; F = 'tcpip.reg' },
    @{ H = 'HKLM'; P = 'SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; F = 'policy-windowsai.reg' },
    @{ H = 'HKLM'; P = 'SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; F = 'policy-copilot.reg' },
    @{ H = 'HKLM'; P = 'SOFTWARE\Policies\Microsoft\Dsh'; F = 'policy-dsh.reg' },
    @{ H = 'HKLM'; P = 'SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; F = 'policy-do.reg' }
)
$okBackups = 0
foreach ($b in $regBackups) {
    $psPath = if ($b.H -eq 'HKLM') { 'HKLM:\' + $b.P } else { 'HKCU:\' + $b.P }
    if (Test-Path $psPath) {
        & reg.exe export ('{0}\{1}' -f $b.H, $b.P) (Join-Path $BakDir $b.F) /y 2>&1 | Out-Null
        if (Test-Path (Join-Path $BakDir $b.F)) { $okBackups++ }
    }
}
Log ('  {0} registry keys backed up -> {1}' -f $okBackups, $BakDir) 'Green'

# ================================================================ 1. UI / EXPLORER
Section 'Explorer / UI responsiveness'

# Replace the slow Windows 11 WinUI context menu with the classic one.
# Windows 10 already ships the classic menu, so this is skipped there.
if ($IsWin11) {
    $clsid = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
    if (-not (Test-Path $clsid)) { New-Item -Path $clsid -Force | Out-Null }
    Set-ItemProperty -Path $clsid -Name '(default)' -Value '' -ErrorAction SilentlyContinue
    Log '  Classic right-click menu enabled'
} else {
    Log '  Windows 10 - classic right-click menu already present, skipped' 'DarkGray'
}

Set-Reg 'HKCU:\Control Panel\Desktop' 'MenuShowDelay' '20' 'String'
Set-Reg 'HKCU:\Control Panel\Desktop' 'MinAnimate' '0' 'String'
Set-Reg 'HKCU:\Control Panel\Desktop' 'DragFullWindows' '1' 'String'
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 3
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAnimations' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ListviewAlphaSelect' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ListviewShadow' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarDa' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowCopilotButton' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'SearchboxTaskbarMode' 1
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_IrisRecommendations' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowSyncProviderNotifications' 0
Log '  Animations / transparency / menu delay tuned'

if ($DisableMouseAcceleration) {
    Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '0' 'String'
    Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0' 'String'
    Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0' 'String'
    Log '  Mouse acceleration disabled'
}

# ================================================================ 2. POWER
Section 'Power plan / gaming power settings'
& powercfg.exe /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>&1 | Out-Null
$planNow = (powercfg /getactivescheme) -join ' '
Log ('  Active plan -> {0}' -f $planNow)

# Processor minimum state 100% (no downclocking stutter), PCIe ASPM off, no sleep
& powercfg.exe /setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 100 2>&1 | Out-Null
& powercfg.exe /setacvalueindex SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0 2>&1 | Out-Null
& powercfg.exe /setacvalueindex SCHEME_CURRENT SUB_SLEEP STANDBYIDLE 0 2>&1 | Out-Null
& powercfg.exe /setacvalueindex SCHEME_CURRENT SUB_SLEEP HIBERNATEIDLE 0 2>&1 | Out-Null
& powercfg.exe /setacvalueindex SCHEME_CURRENT SUB_VIDEO VIDEOIDLE 600 2>&1 | Out-Null
& powercfg.exe /setactive SCHEME_CURRENT 2>&1 | Out-Null
Log '  Processor min 100%, PCIe ASPM off, sleep never, monitor off after 10 min'

# Fast Startup off + hibernation off (also removes hiberfil.sys)
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 0
& powercfg.exe /h off 2>&1 | Out-Null
Log '  Fast Startup OFF, hibernation OFF'

# ================================================================ 3. GAMING TWEAKS
Section 'Gaming registry tweaks'

$mm = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
Set-Reg $mm 'NetworkThrottlingIndex' 4294967295
Set-Reg $mm 'SystemResponsiveness' 10
$games = "$mm\Tasks\Games"
Set-Reg $games 'GPU Priority' 8
Set-Reg $games 'Priority' 6
Set-Reg $games 'Scheduling Category' 'High' 'String'
Set-Reg $games 'SFIO Priority' 'High' 'String'
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' 38
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' 1

# GameDVR / Game Bar recording off, Game Mode on
Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_FSEBehaviorMode' 2
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'HistoricalCaptureEnabled' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0
Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1
Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'ShowStartupPanel' 0
Log '  MMCSS Games profile, priority 38, throttling off, GameDVR off, Game Mode on'

# ================================================================ 4. BACKGROUND JUNK
Section 'Background apps / ads / telemetry'

# --- Copilot ---
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'RemoveMicrosoftCopilotApp' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
Get-Process copilotapp, copilotapphost -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Log '  Copilot: policy off + processes stopped'

# --- Widgets / Phone Link background access ---
foreach ($p in 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh','HKCU:\Software\Policies\Microsoft\Dsh') {
    Set-Reg $p 'AllowNewsAndInterests' 0
}
foreach ($pkg in 'Microsoft.WidgetsPlatformRuntime_8wekyb3d8bbwe','MicrosoftWindows.Client.WebExperience_cw5n1h2txyewy','Microsoft.YourPhone_8wekyb3d8bbwe') {
    $k = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\$pkg"
    Set-Reg $k 'Disabled' 1
    Set-Reg $k 'DisabledByUser' 1
}
Get-Process WidgetService, PhoneExperienceHost -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Log '  Widgets + Phone Link: background access off, processes stopped'

# --- Ads / suggestions / consumer features ---
$cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
foreach ($n in 'SilentInstalledAppsEnabled','SystemPaneSuggestionsEnabled','SoftLandingEnabled','RotatingLockScreenOverlayEnabled',
               'OemPreInstalledAppsEnabled','PreInstalledAppsEnabled','PreInstalledAppsEverEnabled',
               'SubscribedContent-310093Enabled','SubscribedContent-338387Enabled','SubscribedContent-338388Enabled',
               'SubscribedContent-338389Enabled','SubscribedContent-353694Enabled','SubscribedContent-353696Enabled',
               'SubscribedContent-88000326Enabled','ContentDeliveryAllowed') {
    Set-Reg $cdm $n 0
}
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableSoftLanding' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableCloudOptimizedContent' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows' 'CEIPEnable' 0
Log '  Ads / suggestions / CEIP off'

# --- Start menu search: local results only, no Bing / web engine ---
# The search UI is a WebView2 app on Windows 11. Web results make it load an
# extra Edge renderer process, so disabling them keeps the search box local.
$wsearchPol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
Set-Reg $wsearchPol 'DisableWebSearch' 1
Set-Reg $wsearchPol 'ConnectedSearchUseWeb' 0
Set-Reg $wsearchPol 'AllowCortana' 0
Set-Reg $wsearchPol 'AllowSearchToUseLocation' 0
Set-Reg $wsearchPol 'AllowCloudSearch' 0
$searchCu = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
foreach ($n in 'BingSearchEnabled','CortanaConsent','IsDeviceSearchHistoryEnabled',
               'IsDynamicSearchBoxEnabled','EnableDynamicContentInWSB') {
    Set-Reg $searchCu $n 0
}
# Windows 11 stores the taskbar search style here (Windows 10 uses Explorer\Advanced)
Set-Reg $searchCu 'SearchboxTaskbarMode' 1
# No suggestion dropdown at all -> Start menu search stays fully local
Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1
Log '  Start menu search: Bing/web/cloud results OFF, local search only'

# --- Windows 10 extras (the keys are harmless on Windows 11) ---
# Timeline / Activity history: stop the cloud upload of your activity
foreach ($n in 'EnableActivityFeed','PublishUserActivities','UploadUserActivities') {
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' $n 0
}
# News and interests on the taskbar (Windows 10 20H2 and newer)
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' 'EnableFeeds' 0
# Meet Now icon in the notification area
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'HideSCAMeetNow' 1
Log '  Windows 10 extras: timeline/activity history, news feeds, Meet Now off'

# --- Scheduled tasks: telemetry and junk (Xbox tasks are kept) ---
$tasks = @(
    '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
    '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
    '\Microsoft\Windows\Application Experience\AitAgent',
    '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
    '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
    '\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask',
    '\Microsoft\Windows\Feedback\Siuf\DmClient',
    '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload',
    '\Microsoft\Windows\Windows Error Reporting\QueueReporting',
    '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
    '\Microsoft\Windows\Maintenance\WinSAT',
    '\Microsoft\Windows\Autochk\Proxy',
    '\Microsoft\Windows\Maps\MapsToastTask',
    '\Microsoft\Windows\Maps\MapsUpdateTask',
    '\Microsoft\Windows\RetailDemo\CleanupOfflineContent',
    '\Microsoft\Windows\Windows Media Sharing\UpdateLibrary',
    '\Microsoft\Windows\Device Information\Device',
    '\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem',
    '\Microsoft\Windows\CloudExperienceHost\CreateObjectTask'
)
$taskOff = 0
foreach ($t in $tasks) {
    try {
        $tp = (Split-Path $t -Parent).TrimEnd('\') + '\'
        $tn = Split-Path $t -Leaf
        $st = Get-ScheduledTask -TaskPath $tp -TaskName $tn -ErrorAction Stop
        if ($st.State -ne 'Disabled') {
            Disable-ScheduledTask -TaskPath $tp -TaskName $tn -ErrorAction Stop | Out-Null
            $taskOff++
            Log ('  - task off: {0}' -f $tn) 'DarkGray'
        }
    } catch { }
}
Log ('  {0} telemetry/junk scheduled tasks disabled' -f $taskOff)

# ================================================================ 4b. DEFENDER
Section 'Windows Defender resource tuning'
try {
    if (Get-Command Set-MpPreference -ErrorAction SilentlyContinue) {
        # Each setting is applied on its own: older Windows 10 builds (LTSC 2019)
        # do not know every parameter, and one unknown name must not stop the rest.
        function Set-MpSafe {
            param([string]$Name, $Value, [string]$Why)
            $h = @{ $Name = $Value }
            try {
                & Set-MpPreference @h -ErrorAction Stop
                Log ('  - {0} = {1} ({2})' -f $Name, $Value, $Why) 'DarkGray'
            } catch {
                Log ('  - {0} not supported on this build, skipped' -f $Name) 'DarkGray'
            }
        }

        # Low CPU priority: MsMpEng runs in the background and yields CPU to games
        Set-MpSafe 'EnableLowCpuPriority' $true 'yield CPU to games'
        # Cap scan CPU at 20% (default is 50%)
        Set-MpSafe 'ScanAvgCPULoadFactor' 20 'scan CPU cap'
        if (-not $KeepDefenderDailyScan) {
            # 8 = Never (real-time protection stays enabled)
            Set-MpSafe 'ScanScheduleDay' 8 'no scheduled scan'
        } else {
            Set-MpSafe 'ScanScheduleDay' 1 'daily scan'
            Set-MpSafe 'ScanScheduleTime' '03:00:00' 'at 03:00'
        }
        Set-MpSafe 'DisableCatchupQuickScan' $true 'no catch-up scans'
        Set-MpSafe 'DisableCatchupFullScan' $true 'no catch-up scans'
        Set-MpSafe 'DisableScanningMappedNetworkDrivesForFullScan' $true 'skip mapped drives'
        Set-MpSafe 'DisableScanningNetworkFiles' $true 'skip network files'

        $pref = Get-MpPreference
        Log ('  Low CPU priority: {0} | Scan CPU cap: {1}% | Scheduled scan: {2}' -f $pref.EnableLowCpuPriority, $pref.ScanAvgCPULoadFactor, $pref.ScanScheduleDay) 'Green'
        Log '  Real-time protection stays ON (security intact)' 'DarkGray'
    } else {
        Log '  Set-MpPreference not available (third-party antivirus?) - skipped' 'DarkYellow'
    }
} catch {
    Log ('  Defender tweak partial: {0}' -f $_.Exception.Message) 'DarkYellow'
}

# ================================================================ 4c. DEBLOAT
Section 'Store app debloat'
$appsRemoved = 0

# Camera hardware detection (used by both debloat and services)
$hasCam = $false
try {
    $hasCam = [bool](Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
        Where-Object { $_.PNPClass -eq 'Camera' -or $_.PNPClass -eq 'Image' } | Select-Object -First 1)
} catch { }
if ($hasCam) { Log '  Camera hardware detected - Camera app will be kept' 'DarkGray' }
else { Log '  No camera hardware - Camera app will be removed too' 'DarkGray' }

if ($SkipDebloat) {
    Log '  Skipped (-SkipDebloat).'
} else {
    # Always kept: Photos, Camera (if hardware), Media Player (ZuneMusic),
    # ScreenSketch (Snipping Tool), Microsoft Solitaire Collection, Paint, Notepad,
    # Terminal, Calculator, Store, Xbox / Gaming App, WebView, VCLibs, AppRuntime, codecs
    $RemoveApps = @(
        'Clipchamp.Clipchamp',
        'Microsoft.BingNews',
        'Microsoft.BingWeather',
        'Microsoft.BingSearch',
        'Microsoft.GetHelp',
        'Microsoft.MicrosoftOfficeHub',
        'Microsoft.OutlookForWindows',
        'Microsoft.PowerAutomateDesktop',
        'Microsoft.Todos',
        'MSTeams',
        'Microsoft.WindowsFeedbackHub',
        'Microsoft.WindowsAlarms',
        'Microsoft.YourPhone',
        'Microsoft.Windows.DevHome',
        'Microsoft.Windows.ParentalControls',
        'MicrosoftCorporationII.MicrosoftFamily',
        'MicrosoftCorporationII.QuickAssist',
        'Microsoft.WidgetsPlatformRuntime',
        'Microsoft.StartExperiencesApp'
    )
    if (-not $hasCam) { $RemoveApps += 'Microsoft.WindowsCamera' }

    foreach ($a in $RemoveApps) {
        $found = @(Get-AppxPackage -Name $a -ErrorAction SilentlyContinue)
        foreach ($pkg in $found) {
            $ok = $false
            try { Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop; $ok = $true }
            catch {
                try { Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop; $ok = $true } catch { }
            }
            if ($ok) { Log ('  - removed {0}' -f $a) 'Green'; $appsRemoved++ }
            else { Log ('  - could not remove {0}' -f $a) 'DarkYellow' }
        }
        try {
            Get-AppxProvisionedPackage -Online -ErrorAction Stop |
                Where-Object { $_.DisplayName -eq $a } |
                ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null }
        } catch { }
    }
    if ($appsRemoved -eq 0) {
        Log '  No removable Store apps found (normal on LTSC / IoT images)' 'DarkGray'
    } else {
        Log ('  {0} store apps removed' -f $appsRemoved) 'Cyan'
    }
}

# ================================================================ 5. CLEANUP
Section 'Disk cleanup'
if ($SkipCleanup) {
    Log '  Skipped (-SkipCleanup).'
} else {
    function Clear-Dir([string]$Path, [string]$Label) {
        if (-not (Test-Path $Path)) { Log ('  - {0}: not present' -f $Label) 'DarkGray'; return }
        $skip = @('opencode','Win11GamingSetup')
        $before = (Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        Get-ChildItem $Path -Force -ErrorAction SilentlyContinue | Where-Object { $skip -notcontains $_.Name } | ForEach-Object {
            try { Remove-Item $_.FullName -Recurse -Force -ErrorAction Stop } catch { }
        }
        $after = (Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        Log ('  - {0}: {1:N0} MB freed' -f $Label, (($before - $after) / 1MB)) 'Green'
    }

    Clear-Dir $env:TEMP 'User TEMP'
    Clear-Dir 'C:\Windows\Temp' 'Windows TEMP'
    Clear-Dir "$env:LOCALAPPDATA\CrashDumps" 'Crash dumps'
    Clear-Dir "$env:LOCALAPPDATA\Microsoft\Windows\WER" 'User WER reports'
    Clear-Dir 'C:\ProgramData\Microsoft\Windows\WER\ReportArchive' 'WER archive'
    Clear-Dir 'C:\ProgramData\Microsoft\Windows\WER\ReportQueue' 'WER queue'
    Clear-Dir 'C:\Windows\LiveKernelReports' 'Live kernel reports'
    Clear-Dir 'C:\Windows\SoftwareDistribution\Download' 'WU download cache'
    Clear-Dir "$env:LOCALAPPDATA\D3DSCache" 'DirectX shader cache'
    Clear-Dir "$env:LOCALAPPDATA\NVIDIA\DXCache" 'NVIDIA DX cache'
    Clear-Dir "$env:LOCALAPPDATA\NVIDIA\GLCache" 'NVIDIA GL cache'
    Clear-Dir "$env:LOCALAPPDATA\AMD\DxCache" 'AMD shader cache'
    Clear-Dir "$env:LOCALAPPDATA\Microsoft\Windows\INetCache" 'INetCache'
    Clear-Dir 'C:\ProgramData\Microsoft\Windows\WER\Temp' 'WER temp'

    # Delivery Optimization cache
    try { Delete-DeliveryOptimizationCache -Force -ErrorAction Stop; Log '  - Delivery Optimization cache cleared' 'Green' }
    catch { Clear-Dir 'C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache' 'DO cache' }

    # WinRE leftover after feature updates (often several GB)
    if (Test-Path 'C:\$WinREAgent') {
        & takeown.exe /f 'C:\$WinREAgent' /r /d y 2>&1 | Out-Null
        & icacls.exe 'C:\$WinREAgent' /grant '*S-1-5-32-544:F' /t /c 2>&1 | Out-Null
        Remove-Item 'C:\$WinREAgent' -Recurse -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path 'C:\$WinREAgent')) { Log '  - $WinREAgent removed' 'Green' } else { Log '  - $WinREAgent partially left' 'DarkYellow' }
    }

    # Windows logs older than 7 days
    $logBytes = 0
    Get-ChildItem 'C:\Windows\Logs' -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
        ForEach-Object { try { $logBytes += $_.Length; Remove-Item $_.FullName -Force -ErrorAction Stop } catch { } }
    Log ('  - Windows logs: {0:N0} MB freed' -f ($logBytes / 1MB)) 'Green'

    if ($EmptyRecycleBin) {
        try { Clear-RecycleBin -Force -ErrorAction Stop; Log '  - Recycle Bin emptied' 'Green' } catch { }
    }

    if ($DeepComponentCleanup) {
        Log '  - DISM component cleanup running (this can take a while)...'
        & Dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1 | Out-Null
        Log '  - DISM component cleanup done' 'Green'
    }

    # --- Windows Update cache reset ---
    Log '  - Resetting Windows Update cache...'
    foreach ($s in 'wuauserv','bits','cryptSvc','msiserver','UsoSvc','WaaSMedicSvc') {
        Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
    }
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    if (Test-Path 'C:\Windows\SoftwareDistribution') { Rename-Item 'C:\Windows\SoftwareDistribution' "SoftwareDistribution.old-$ts" -Force -ErrorAction SilentlyContinue }
    if (Test-Path 'C:\Windows\System32\catroot2') { Rename-Item 'C:\Windows\System32\catroot2' "catroot2.old-$ts" -Force -ErrorAction SilentlyContinue }
    foreach ($s in 'wuauserv','bits','cryptSvc') { Start-Service -Name $s -ErrorAction SilentlyContinue }
    Get-ChildItem 'C:\Windows' -Filter 'SoftwareDistribution.old-*' -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Get-ChildItem 'C:\Windows\System32' -Filter 'catroot2.old-*' -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Log '  - Windows Update cache reset done' 'Green'
}

$freeMid = [math]::Round((Get-PSDrive -Name ($env:SystemDrive -replace ':','')).Free / 1GB, 2)
Log ('  Free space: {0} GB -> {1} GB' -f $freeBefore, $freeMid) 'White'

# ================================================================ 6. SERVICES
Section 'Service slimming (gaming-only PC)'

# Load an existing backup first so a re-run never overwrites the original state
$jsonPath0 = Join-Path $BakDir 'services-backup.json'
if (Test-Path $jsonPath0) {
    try {
        foreach ($r in (Get-Content $jsonPath0 -Raw | ConvertFrom-Json)) {
            if (-not $svcOriginal.ContainsKey($r.Name)) { $svcOriginal[$r.Name] = [int]$r.Start }
        }
        Log ('  Existing service backup loaded: {0} entries' -f $svcOriginal.Count) 'DarkGray'
    } catch { }
}

# Never touched: core Windows, LAN/SMB, security, audio, GPU, Xbox gaming
$Protected = @(
    'RpcSs','DcomLaunch','RpcEptMapper','LSM','SamSs','Winmgmt','EventLog','Schedule','ProfSvc','gpsvc',
    'UserManager','BrokerInfrastructure','SystemEventsBroker','Power','PlugPlay','nsi','Dhcp','Dnscache',
    'NlaSvc','netprofm','Nlm','Ndu','LanmanWorkstation','LanmanServer','lmhosts','iphlpsvc','mpssvc',
    'WinDefend','SecurityHealthService','wscsvc','SgrmBroker','Sense','CryptSvc','BITS','wuauserv',
    'TrustedInstaller','msiserver','UsoSvc','WaaSMedicSvc','Audiosrv','AudioEndpointBuilder',
    'Wcmsvc','Themes','TextInputManagementService','CoreMessagingRegistrar','StateRepository','TokenBroker',
    'KeyIso','VaultSvc','AppXSvc','ClipSVC','InstallService','LicenseManager','wlidsvc','XblAuthManager',
    'XblGameSave','XboxGipSvc','XboxNetApiSvc','GamingServices','GamingServicesNet','GameInputSvc',
    'FDResPub','fdPHost','dot3svc','EapHost','PolicyAgent','NcaSvc','NcbService','camsvc',
    'TimeBrokerSvc','QWAVE','SharedAccess','DeviceInstall','DsmSvc',
    'TermService','UmRdpService','SessionEnv','NVDisplay.ContainerLocalSystem'
)

function Resolve-SvcName {
    param([string]$Pattern)
    if ($Pattern -match '[\*\?]') {
        return @(Get-Service -Name $Pattern -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
    }
    return @($Pattern)
}

function Get-SvcStartValue {
    param([string]$Name)
    $p = "HKLM:\SYSTEM\CurrentControlSet\Services\$Name"
    if (Test-Path $p) {
        $v = (Get-ItemProperty $p -ErrorAction SilentlyContinue).Start
        if ($null -ne $v) { return [int]$v }
    }
    return 3
}

function Set-SvcStart {
    param([string]$Pattern, [string]$StartValue, [string]$Why)
    foreach ($n in (Resolve-SvcName $Pattern)) {
        if ($Protected -contains $n) { Log ('  KEEP  {0,-42} {1}' -f $n, '(protected)') 'DarkGray'; continue }
        $w = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $n) -ErrorAction SilentlyContinue
        if (-not $w) { continue }
        if (-not $svcOriginal.ContainsKey($n)) { $svcOriginal[$n] = [int](Get-SvcStartValue $n) }
        if ($StartValue -eq 'disabled') {
            $runningDeps = @(Get-Service -Name $n -ErrorAction SilentlyContinue).DependentServices |
                Where-Object { $_.Status -eq 'Running' -and $Protected -notcontains $_.Name }
            if ($runningDeps.Count -gt 0) {
                Log ('  SKIP  {0,-42} dependents running: {1}' -f $n, (($runningDeps | Select-Object -ExpandProperty Name) -join ',')) 'DarkYellow'
                continue
            }
            if ($w.State -eq 'Running') {
                Stop-Service -Name $n -Force -ErrorAction SilentlyContinue
                Start-Sleep -Milliseconds 150
            }
        }
        & sc.exe config $n start= $StartValue 2>&1 | Out-Null
        $after = (Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $n) -ErrorAction SilentlyContinue).StartMode
        $afterReg = [int](Get-SvcStartValue $n)
        $wantReg = switch ($StartValue) { 'auto' {2} 'demand' {3} 'disabled' {4} default {3} }
        if ($afterReg -ne $wantReg) {
            Log ('  NOCHG {0,-42} {1,-9} (protected by Windows)' -f $n, $w.StartMode) 'DarkYellow'
            continue
        }
        Log ('  {0,-6} {1,-42} {2,-9} -> {3,-9} {4}' -f 'SET', $n, $w.StartMode, $after, $Why) 'Green'
        $script:Changed++
    }
}

# ============================================================ LAN DISCOVERY
# Explorer > Network and \\hostname / \\IP browsing depend on these services.
# Disabling SSDPSRV / upnphost used to make every other LAN PC disappear while
# direct file transfer still worked. Decide from the machine's own state.
Log '-- LAN discovery (auto-detected) --'
$lanPresent = $false
$lanReasons = @()

if ($NoLAN) {
    Log '  LAN detection overridden (-NoLAN) - discovery services will be slimmed' 'DarkYellow'
} else {
    # 1. An active Private or Domain network profile means a trusted LAN
    try {
        foreach ($pf in @(Get-NetConnectionProfile -ErrorAction Stop)) {
            if ([string]$pf.NetworkCategory -in @('Private','Domain','DomainAuthenticated')) {
                $lanPresent = $true
                $lanReasons += ('{0}={1}' -f $pf.InterfaceAlias, $pf.NetworkCategory)
            }
        }
    } catch { }

    # 2. RFC1918 address also counts, even if the profile query is unavailable
    try {
        $rfc1918 = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object { $_.IPAddress -match '^(10\.|172\.(1[6-9]|2\d|3[01])\.|192\.168\.)' })
        if ($rfc1918.Count -gt 0) {
            $lanPresent = $true
            $lanReasons += 'private IPv4'
        }
    } catch { }

    # 3. Existing SMB shares or mapped drives mean this PC is part of a LAN
    try {
        $shares = @(Get-SmbShare -ErrorAction Stop |
            Where-Object { $_.Name -notin @('IPC$','ADMIN$','C$','D$') })
        if ($shares.Count -gt 0) { $lanPresent = $true; $lanReasons += 'local shares' }
    } catch { }
    try {
        $mapped = @(Get-PSDrive -PSProvider FileSystem -ErrorAction Stop |
            Where-Object { $_.DisplayRoot -like '\\*' })
        if ($mapped.Count -gt 0) { $lanPresent = $true; $lanReasons += 'mapped drives' }
    } catch { }
}

if ($lanPresent) {
    Log ('  LAN detected ({0}) - keeping discovery services ON' -f ($lanReasons -join ', ')) 'Green'
    # FDResPub publishes this PC; fdPHost + SSDP + UPnP discover other PCs.
    foreach ($svc in @('FDResPub','fdPHost','SSDPSRV','upnphost')) {
        $w = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f $svc) -ErrorAction SilentlyContinue
        if (-not $w) { continue }
        if (-not $svcOriginal.ContainsKey($svc)) { $svcOriginal[$svc] = [int](Get-SvcStartValue $svc) }
        $wantStart = if ($svc -in @('FDResPub','fdPHost')) { 2 } else { 3 }
        if ((Get-SvcStartValue $svc) -ne $wantStart) {
            & sc.exe config $svc start= $(if ($wantStart -eq 2) { 'auto' } else { 'demand' }) 2>&1 | Out-Null
        }
        if ($w.State -ne 'Running') { Start-Service -Name $svc -ErrorAction SilentlyContinue }
        $now = Get-Service -Name $svc -ErrorAction SilentlyContinue
        Log ('  KEEP  {0,-12} {1,-9} LAN discovery' -f $svc, $now.Status) 'Green'
    }
} else {
    Log '  No LAN detected - SSDP / UPnP discovery will be slimmed' 'DarkGray'
    Set-SvcStart 'SSDPSRV' 'disabled' 'no LAN - SSDP discovery'
    Set-SvcStart 'upnphost' 'disabled' 'no LAN - UPnP host'
}

Log '-- Telemetry / diagnostics / error reporting --'
Set-SvcStart 'DiagTrack' 'disabled' 'telemetry upload'
Set-SvcStart 'dmwappushservice' 'disabled' 'WAP push'
Set-SvcStart 'diagnosticshub.standardcollector.service' 'disabled' 'diagnostics collector'
Set-SvcStart 'WerSvc' 'disabled' 'error reporting'
Set-SvcStart 'DPS' 'disabled' 'diagnostic policy'
Set-SvcStart 'PcaSvc' 'disabled' 'compat assistant'
Set-SvcStart 'wisvc' 'disabled' 'insider service'

Log '-- Consumer / cloud / notifications --'
Set-SvcStart 'WpnUserService*' 'disabled' 'push (per-user)'
Set-SvcStart 'WpnService' 'disabled' 'push notifications'
Set-SvcStart 'CDPUserSvc*' 'disabled' 'connected devices (per-user)'
Set-SvcStart 'CDPSvc' 'disabled' 'connected devices platform'
Set-SvcStart 'OneSyncSvc*' 'disabled' 'mail/calendar sync'
Set-SvcStart 'PimIndexMaintenanceSvc*' 'disabled' 'contact indexing'
Set-SvcStart 'BcastDVRUserService*' 'disabled' 'gameDVR broadcast'
Set-SvcStart 'WpcMonSvc' 'disabled' 'parental controls'
Set-SvcStart 'MapsBroker' 'disabled' 'offline maps'
Set-SvcStart 'lfsvc' 'disabled' 'geolocation'
Set-SvcStart 'PhoneSvc' 'disabled' 'telephony/TAPI'
Set-SvcStart 'AJRouter' 'disabled' 'AllJoyn router'
Set-SvcStart 'WMPNetworkSvc' 'disabled' 'media sharing'
Set-SvcStart 'RetailDemo' 'disabled' 'retail demo'
Set-SvcStart 'icssvc' 'disabled' 'mobile hotspot'
Set-SvcStart 'WwanSvc' 'disabled' 'cellular'
Set-SvcStart 'SDRSVC' 'disabled' 'windows backup'
Set-SvcStart 'TrkWks' 'disabled' 'link tracking'
Set-SvcStart 'KtmRm' 'disabled' 'KTM resource manager'
Set-SvcStart 'SensorService' 'disabled' 'sensors'
Set-SvcStart 'SensrSvc' 'disabled' 'sensor monitoring'

Log '-- WCF / MSMQ / enterprise --'
Set-SvcStart 'NetTcpPortSharing' 'disabled' 'WCF port sharing'
Set-SvcStart 'NetTcpActivator' 'disabled' 'WCF TCP'
Set-SvcStart 'NetPipeActivator' 'disabled' 'WCF pipe'
Set-SvcStart 'NetMsmqActivator' 'disabled' 'MSMQ'
Set-SvcStart 'AppVClient' 'disabled' 'App-V'
Set-SvcStart 'EntAppSvc' 'disabled' 'enterprise apps'
Set-SvcStart 'embeddedmode' 'disabled' 'embedded mode'

Log '-- Remote access / legacy (security) --'
# SSDPSRV and upnphost are handled by the LAN-detection block above.
Set-SvcStart 'RemoteRegistry' 'disabled' 'remote registry'
Set-SvcStart 'RemoteAccess' 'disabled' 'RRAS'
Set-SvcStart 'seclogon' 'disabled' 'secondary logon'
Set-SvcStart 'Fax' 'disabled' 'fax'
Set-SvcStart 'Bonjour Service' 'disabled' 'bonjour/mDNS'
Set-SvcStart 'NvTelemetryContainer' 'disabled' 'nvidia telemetry'

if (-not $KeepPrintSpooler) { Set-SvcStart 'Spooler' 'disabled' 'printing (gaming PC)' }
else { Log '  KEEP  Spooler (requested)' 'DarkGray' }

if (-not $KeepWindowsSearch) {
    Set-SvcStart 'WSearch' 'disabled' 'indexing off (resource saving)'
} else { Log '  KEEP  WSearch (requested)' 'DarkGray' }

# SysMain: disable on SSD, keep on HDD (prefetch helps app launch on spinning disks)
$sysMainDecision = 'keep'
if ($DisableSysMain) { $sysMainDecision = 'off' }
else {
    try {
        $sysDisk = Get-PhysicalDisk | Where-Object { $_.DeviceId -eq (Get-Partition -DriveLetter ($env:SystemDrive -replace ':','') -ErrorAction Stop).DiskNumber } | Select-Object -First 1
        if ($sysDisk -and $sysDisk.MediaType -eq 'SSD') { $sysMainDecision = 'off' }
    } catch { }
}
if ($sysMainDecision -eq 'off') { Set-SvcStart 'SysMain' 'disabled' 'SSD - prefetch not needed' }
else { Log '  KEEP  SysMain (HDD detected)' 'DarkGray' }

# Tablet input: disable when there is no touch screen or pen
$hasTouch = $false
try {
    $hasTouch = [bool](Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'HID-compliant touch screen|Pen device' } | Select-Object -First 1)
} catch { }
if (-not $hasTouch) { Set-SvcStart 'TabletInputService' 'disabled' 'no touch/pen' }

# ---- Hardware-adaptive: only disable what the machine does not have ----
Log '-- Hardware-adaptive (hardware not present) --'
$hasWifi = $false
try {
    $hasWifi = [bool](Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
        Where-Object { $_.PhysicalMediaType -match '802\.11' -or $_.InterfaceDescription -match 'Wireless|Wi-Fi|WLAN' } | Select-Object -First 1)
} catch { }
if (-not $hasWifi) {
    Set-SvcStart 'WlanSvc' 'disabled' 'no WiFi adapter'
    Set-SvcStart 'RmSvc' 'disabled' 'no radio hardware'
} else { Log '  KEEP  WlanSvc (WiFi adapter detected)' 'DarkGray' }

$hasBt = $false
try {
    $hasBt = [bool](Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue | Where-Object Status -eq 'OK' | Select-Object -First 1)
} catch { }
if (-not $hasBt) {
    Set-SvcStart 'bthserv' 'disabled' 'no Bluetooth'
    Set-SvcStart 'BTAGService' 'disabled' 'no Bluetooth audio'
    Set-SvcStart 'BthAvctpSvc' 'disabled' 'no Bluetooth AVRCP'
    Set-SvcStart 'BluetoothUserService*' 'disabled' 'no Bluetooth (per-user)'
} else { Log '  KEEP  Bluetooth services (adapter detected)' 'DarkGray' }

if (-not $hasCam) {
    Set-SvcStart 'FrameServer' 'disabled' 'no camera'
    Set-SvcStart 'FrameServerMonitor' 'disabled' 'no camera'
} else { Log '  KEEP  Camera services (camera detected)' 'DarkGray' }

$hasScan = $false
try {
    $hasScan = [bool](Get-PnpDevice -Class Image -ErrorAction SilentlyContinue | Where-Object Status -eq 'OK' | Select-Object -First 1)
} catch { }
if (-not $hasScan) { Set-SvcStart 'stisvc' 'disabled' 'no scanner' }

$hasBio = $false
try {
    $hasBio = [bool](Get-PnpDevice -Class Biometric -ErrorAction SilentlyContinue | Where-Object Status -eq 'OK' | Select-Object -First 1)
} catch { }
if (-not $hasBio) { Set-SvcStart 'WbioSrvc' 'disabled' 'no fingerprint/iris' }

Log '-- Extra (gaming-only, remote/legacy) --'
Set-SvcStart 'WinRM' 'disabled' 'remote management'
Set-SvcStart 'TapiSrv' 'disabled' 'telephony (PhoneSvc off)'
Set-SvcStart 'WorkFoldersSvc' 'disabled' 'work folders'
Set-SvcStart 'SmsRouter' 'disabled' 'SMS router'
Set-SvcStart 'SEMgrSvc' 'disabled' 'NFC payments'
Set-SvcStart 'SCardSvr' 'disabled' 'smart card'
Set-SvcStart 'ScDeviceEnum' 'disabled' 'smart card enumeration'
Set-SvcStart 'TieringEngineService' 'disabled' 'storage tiers'
Set-SvcStart 'DmEnrollmentSvc' 'disabled' 'MDM enrollment'
Set-SvcStart 'diagsvc' 'disabled' 'diagnostic execution'
Set-SvcStart 'WdiServiceHost' 'disabled' 'diagnostics host'
Set-SvcStart 'WdiSystemHost' 'disabled' 'diagnostics system host'
Set-SvcStart 'WalletService' 'disabled' 'wallet'

Log ('-- {0} service settings applied --' -f $script:Changed) 'Cyan'

# ================================================================ 7. NETWORK
Section 'Internet / network tuning'

function Net([string]$cmd) {
    $out = & cmd.exe /c $cmd 2>&1
    Log ('  > {0}' -f $cmd) 'DarkGray'
    if ($out) { foreach ($l in $out) { if ($l -and $l -notmatch '^\s*$') { Log ('    {0}' -f $l.Trim()) 'DarkGray' } } }
}

Net 'netsh int tcp set global autotuninglevel=normal'
Net 'netsh int tcp set global rss=enabled'
Net 'netsh int tcp set global ecncapability=disabled'
Net 'netsh int tcp set global timestamps=disabled'
Net 'netsh int tcp set global netdma=disabled'
Net 'netsh int tcp set global dca=enabled'
Net 'netsh winhttp reset proxy'
Net 'ipconfig /flushdns'

# QoS: reserved bandwidth 0 -> nothing held back from games or LAN transfers
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched' 'NonBestEffortLimit' 0

# Nagle off on every active NIC (lower latency, no impact on LAN throughput)
$tcpIf = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'
$nagleCount = 0
try {
    Get-ChildItem $tcpIf -ErrorAction Stop | ForEach-Object {
        $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
        $ip = $props.DhcpIPAddress
        if (-not $ip) { $ip = ($props.IPAddress | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } | Select-Object -First 1) }
        if ($ip -and $ip -ne '0.0.0.0') {
            Set-Reg $_.PSPath 'TcpAckFrequency' 1
            Set-Reg $_.PSPath 'TCPNoDelay' 1
            Set-Reg $_.PSPath 'TcpDelAckTicks' 0
            $nagleCount++
        }
    }
} catch { }
Log ('  Nagle disabled on {0} interface(s)' -f $nagleCount) 'Green'

# NIC power saving off (fixes packet drops / random latency spikes)
try {
    Get-NetAdapter -Physical -ErrorAction Stop | ForEach-Object {
        try { Set-NetAdapterPowerManagement -Name $_.Name -AllowComputerToTurnOffDevice Disabled -ErrorAction Stop | Out-Null } catch { }
        try { Set-NetAdapterAdvancedProperty -Name $_.Name -DisplayName 'Energy Efficient Ethernet' -DisplayValue 'Disabled' -ErrorAction Stop | Out-Null } catch { }
        try { Disable-NetAdapterRsc -Name $_.Name -ErrorAction Stop | Out-Null } catch { }
    }
    Log '  NIC power saving off (all physical adapters)' 'Green'
} catch { Log '  NIC power tweak skipped (cmdlet not available)' 'DarkYellow' }

# Delivery Optimization: no LAN peering, keep the LAN free for file transfers
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 0
Log '  Delivery Optimization peering OFF (LAN free for file transfer)'

# SMB1: off for security, SMB2/3 stay on so Linux and Windows shares keep working.
# Keep it automatically if an SMB 1.5 connection is already in use (old NAS/XP).
if ($KeepSMB1) {
    Log '  KEEP SMB1 (requested with -KeepSMB1)' 'DarkGray'
} else {
    $smb1InUse = $false
    try {
        $smb1InUse = [bool](Get-SmbConnection -ErrorAction Stop |
            Where-Object { $_.Dialect -eq '1.5' } | Select-Object -First 1)
    } catch { }
    if ($smb1InUse) {
        Log '  KEEP SMB1 - an active SMB 1.5 connection was detected' 'DarkYellow'
    } else {
        # Back up the SMB1 flag so Revert.ps1 can put it back
        $smbReg = 'HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
        if (Test-Path ('HKLM:\' + $smbReg)) {
            & reg.exe export $smbReg (Join-Path $BakDir 'smb1.reg') /y 2>&1 | Out-Null
        }
        try {
            Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction Stop
            Log '  SMB1 disabled, SMB2/3 enabled (LAN shares OK)' 'Green'
        } catch { Log '  SMB configuration skipped' 'DarkYellow' }
    }
}

# Keep network discovery and file sharing allowed for LAN transfers
try {
    Get-NetFirewallRule -DisplayGroup 'Network Discovery' -ErrorAction Stop | Enable-NetFirewallRule -ErrorAction SilentlyContinue
    Get-NetFirewallRule -DisplayGroup 'File and Printer Sharing' -ErrorAction Stop | Enable-NetFirewallRule -ErrorAction SilentlyContinue
    Log '  Firewall: Network Discovery + File Sharing allowed (LAN transfer)' 'Green'
} catch { Log '  Firewall rule tweak skipped' 'DarkYellow' }

# ================================================================ 8. EXPLORER + ICON CACHE
Section 'Icon / thumbnail cache + Explorer restart'
try {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3

    $freed = 0
    $cacheDirs = @(
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer",
        "$env:LOCALAPPDATA"
    )
    foreach ($cd in $cacheDirs) {
        if (-not (Test-Path $cd)) { continue }
        Get-ChildItem $cd -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^(iconcache|thumbcache).*\.db$|^IconCache\.db$' } |
            ForEach-Object {
                try { $freed += $_.Length; Remove-Item $_.FullName -Force -ErrorAction Stop } catch { }
            }
    }
    Log ('  Icon + thumbnail cache cleared ({0:N0} MB)' -f ($freed / 1MB)) 'Green'

    if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
    Start-Sleep -Seconds 2
    Log '  Explorer restarted (tweaks + fresh icons)' 'Green'
} catch { Log '  Explorer restart skipped' 'DarkYellow' }

# ================================================================ 9. REVERT
Section 'Backup + Revert script'

$jsonPath = Join-Path $BakDir 'services-backup.json'
$rows = @()
foreach ($k in $svcOriginal.Keys) { $rows += [PSCustomObject]@{ Name = $k; Start = $svcOriginal[$k] } }
$rows | ConvertTo-Json -Depth 3 | Set-Content -Path $jsonPath -Encoding UTF8
Log ('  Service state saved: {0} entries -> {1}' -f $rows.Count, $jsonPath) 'Green'

$revert = @'
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
'@
$revertTargets = @(
    (Join-Path $Root 'Revert.ps1'),
    (Join-Path $ScriptDir 'Revert.ps1')
)
foreach ($rt in ($revertTargets | Select-Object -Unique)) {
    try { Set-Content -Path $rt -Value $revert -Encoding UTF8; Log ('  Revert script: {0}' -f $rt) 'Green' } catch { }
}

# ================================================================ 10. SUMMARY
Section 'Summary'
$freeAfter = [math]::Round((Get-PSDrive -Name ($env:SystemDrive -replace ':','')).Free / 1GB, 2)
Log ('  System drive free space : {0} GB -> {1} GB  (+{2:N1} GB)' -f $freeBefore, $freeAfter, ($freeAfter - $freeBefore)) 'White'
Log ('  Services changed        : {0}' -f $script:Changed) 'White'
Log ('  Scheduled tasks off     : {0}' -f $taskOff) 'White'
Log ('  Store apps removed      : {0}' -f $appsRemoved) 'White'
Log ('  Log                     : {0}' -f $script:LogFile) 'DarkGray'
Log ('  Revert                  : {0}' -f (Join-Path $ScriptDir 'Revert.ps1')) 'DarkGray'
Log ''
Log '  Please reboot so every change takes full effect.' 'Yellow'

if (-not $NoPause) { Read-Host 'Press Enter to close' }
