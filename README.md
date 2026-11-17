# 🎮 Windows Gaming Setup

> Turn a fresh Windows 10 / 11 (LTSC included) install into a lean, fast, **gaming-only** PC — with one administrator script and a one-click undo.

![Platform](https://img.shields.io/badge/platform-Windows%2011%20%7C%2010%20%7C%20LTSC-0078D6?style=flat-square&logo=windows)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=flat-square&logo=powershell)
![Admin](https://img.shields.io/badge/requires-Administrator-red?style=flat-square)
![Revert](https://img.shields.io/badge/revert-included-success?style=flat-square)
![Version](https://img.shields.io/badge/version-1.4.0-blue?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)

---

## 📑 Contents

- [Why does this script exist?](#-why-does-this-script-exist)
- [Who is it for (and who is it not for)?](#-who-is-it-for-and-who-is-it-not-for)
- [Measured results](#-measured-results)
- [Quick start — run it in 10 seconds](#-quick-start--run-it-in-10-seconds)
- [How the script decides things (detection)](#-how-the-script-decides-things-detection)
- [Every feature, what it does and why](#-every-feature-what-it-does-and-why)
- [Command-line flags](#-command-line-flags)
- [Safety model](#-safety-model)
- [Revert — undo everything](#-revert--undo-everything)
- [Windows 10 / LTSC notes](#-windows-10--ltsc-notes)
- [Verify it worked](#-verify-it-worked)
- [Troubleshooting](#-troubleshooting)
- [Honest limitations (read this before believing the hype)](#-honest-limitations-read-this-before-believing-the-hype)
- [Files, logs and backups](#-files-logs-and-backups)
- [Publishing to GitHub](#-publishing-to-github)
- [License](#-license)

---

## 🤔 Why does this script exist?

A default Windows install carries a lot of machinery that a gaming-only PC never uses:

- telemetry uploaders, compatibility appraisers and error-reporting services;
- Widgets, Copilot, Phone Link, consumer suggestions and ads in Start / Explorer;
- Store apps you will never open (News, Weather, Teams, Outlook, To Do, Clipchamp…);
- an indexer (`WSearch`) that keeps the disk busy;
- a taskbar search UI that preloads Edge's WebView2 renderer (~250 MB of RAM);
- Windows Update and shader caches that grow to several GB;
- dozens of services for printing, fax, smart cards, cellular, remote access, sensors, etc.

On an older or modest machine (4–8 GB RAM, a spinning disk, an older CPU) this overhead is not abstract: it shows up as a slow right-click menu, short freezes, high idle RAM and CPU spikes during a game.

Doing all the fixes by hand means 50+ registry edits, service changes and cleanup commands — impossible to remember or repeat on a second PC. This script makes it **one repeatable, reversible step**.

### What this script is *not*

> 📌 It is **not** a driver updater, a "RAM booster", an FPS hack or an overclocking tool. It does **not** change your IP address, does **not** disable Defender / Firewall / SmartScreen / Windows Update, does **not** delete personal files, and does **not** promise extra FPS by magic. It removes software overhead so the hardware you already have is not fighting the OS.

---

## 👥 Who is it for (and who is it not for)?

| Use it when… | Avoid it (or use flags) when… |
|---|---|
| The PC is mainly for gaming | You print often → add `-KeepPrintSpooler` |
| You transfer files over LAN (Windows/Linux shares) | You search file contents all day → add `-KeepWindowsSearch` |
| You want less background noise and faster Explorer | You need web answers from the Start search box → add `-KeepSearchUI` |
| You reinstall Windows often and want the same setup every time | It is a corporate / managed work PC |
| You are comfortable with a UAC prompt and a reboot | You do not have a backup of important files |

---

## 📊 Measured results

From the test machine: **i5-2500K, 12 GB DDR3-1333, GTX 750 Ti 2 GB, Windows 11 build 26300**.

| Metric | Before → After | Note |
|---|---|---|
| Free space on C: | 44.5 GB → 64.4 GB (**+19.9 GB**) | Temp, WinRE leftover, WU cache, shader/log caches |
| Store apps | 19 removed | Photos, Snipping Tool, Solitaire, Media Player kept |
| Service settings | ~51–53 applied, 36+ disabled | Plus a hardware-aware keep list |
| Telemetry tasks | 13 disabled | Re-runs report 0 because they are already off |
| Search UI memory | ~250 MB → **0 MB at idle** | Host + its WebView2 renderer tree |
| DNS resolution | fastest servers chosen (~15 ms) | IP address untouched |
| Defender scan CPU cap | 50 % → 10 % | Real-time protection stays on |

> ⚠️ FPS gains are not measured or promised. What you get is a lighter desktop, fewer background interruptions and less I/O contention. The hardware is still the hardware.

---

## 🚀 Quick start — run it in 10 seconds

### Option 1 — double-click (easiest)

1. Copy the **whole folder** to the PC.
2. Double-click **`RUN-AS-ADMIN.cmd`**.
3. Click **Yes** on the UAC prompt. That is all.

The window stays open and shows the summary when it finishes.

### Option 2 — right-click

Right-click `RUN-AS-ADMIN.cmd` → **Run as administrator** → **Yes**.

### Option 3 — PowerShell

```powershell
cd "$env:USERPROFILE\Downloads\Win11-Gaming-Setup"
Get-ChildItem -Path . -Filter *.ps1 | Unblock-File
powershell -NoProfile -ExecutionPolicy Bypass -File .\Win11-Gaming-Setup.ps1
```

The script also self-elevates if launched from a non-administrator PowerShell, so it asks for UAC rights by itself.

**Afterwards: reboot once.** Some service and Explorer changes only fully settle after a restart.

To undo: double-click **`REVERT-AS-ADMIN.cmd`** (details [below](#-revert--undo-everything)).

---

## 🔍 How the script decides things (detection)

This is not a blind "disable everything" script. Every risky change is guarded by detection.

| What is detected | How | Decision |
|---|---|---|
| **OS family** | Build number (22000 = Windows 11) | Win11-only tweaks (classic context menu) skipped on Windows 10 / LTSC |
| **LTSC / IoT edition** | Caption + SKU | Debloat summary explains that Store apps are normally absent |
| **WiFi / Bluetooth / camera / scanner / fingerprint / touch** | PnP and network adapter queries | Their services are only disabled when the hardware is *missing* |
| **System disk type** | `Get-PhysicalDisk.MediaType` | `SysMain` (Superfetch) off on SSD, kept on HDD where prefetch helps |
| **LAN present** | Private / `DomainAuthenticated` network profile, RFC1918 IPv4 address, local SMB shares, mapped drives | Discovery services (`SSDPSRV`, `upnphost`, `FDResPub`, `fdPHost`) are **kept running and started**; only slimmed when no LAN exists. `-NoLAN` forces the slim path |
| **SMB1 in use** | Active SMB connection with dialect `1.5` | SMB1 kept automatically for old NAS / XP devices; otherwise disabled for security |
| **Fastest DNS** | TCP/53 connection latency to Cloudflare, Google, Quad9, OpenDNS | Two fastest resolvers applied; existing DNS kept as fallback; IP never changed |
| **MDE onboarding** | Presence of Defender-for-Endpoint onboarding keys | Unused `Sense` agent stopped; kept if the PC is actually onboarded |
| **Service change result** | Registry `Start` value re-read after `sc.exe config` | If Windows refuses the change, it is logged as `NOCHG`, not silently assumed |
| **Running dependents** | `DependentServices` check | A service with running dependents is skipped (`SKIP`) instead of breaking something |
| **Re-runs** | Existing `services-backup.json` is loaded first | Original values are **merged**, never overwritten |

---

## 🧩 Every feature, what it does and why

### 1. Explorer / UI responsiveness

| Change | Why | Effect |
|---|---|---|
| Classic right-click menu (Win11 only) | The WinUI menu is noticeably slow on older CPUs | Context menu opens immediately |
| `MenuShowDelay = 20 ms` | Default is 400 ms | Menus feel instant |
| Animations, transparency, list-view shadows off | Each costs GPU/CPU work on weak integrated graphics | Snappier Explorer, no visual lag |
| Copilot button / taskbar widgets hidden | Pure background noise | Cleaner taskbar |

### 2. Power plan (gaming profile)

| Change | Why | Effect |
|---|---|---|
| High Performance plan active | Avoids CPU downclocking | Consistent frame pacing |
| Processor minimum state 100 % | Prevents scale-up stutter | Fewer micro-stutters (more heat/power) |
| PCIe ASPM off | Link power saving can cause latency spikes | More stable GPU/NVMe latency |
| Sleep / hibernate never, monitor off after 10 min | A gaming PC should not sleep mid-session | No wake-up surprises |
| Fast Startup + hibernation off | Removes `hiberfil.sys` and power-transition bugs | Disk space + fewer boot issues |

### 3. Gaming registry tweaks

| Change | Why | Effect |
|---|---|---|
| GameDVR / Game Bar recording off | Background capture costs CPU/GPU | More headroom in games |
| Game Mode on | Prioritises the game process | Small, free improvement |
| MMCSS *Games* profile + Win32 priority 38 | Multimedia scheduling favours the game | Lower audio/input latency |
| `NetworkThrottlingIndex` max, `PowerThrottlingOff` | Windows otherwise throttles some workloads | Fewer stalls |

### 4. Background junk and telemetry

| Change | Why | Effect |
|---|---|---|
| Copilot, Widgets, Phone Link disabled | Always-on background processes and network calls | Lower idle CPU/RAM |
| Ads, suggestions, consumer features off | Start/Explorer stop recommending things | Cleaner, quieter OS |
| 13 telemetry / diagnostics tasks disabled | Needless scheduled wake-ups | Less background disk activity |
| Activity history, News feed, Meet Now off (Win10) | Cloud upload and taskbar feed | Less telemetry and network noise |

### 5. Start menu search — fully disabled by default

| Change | Why | Effect |
|---|---|---|
| Web / Bing / cloud results off | Web lookups spawn an Edge renderer in the search UI | No search-related network calls |
| Taskbar search icon hidden | You do not use it | Cleaner taskbar |
| `SearchHost.exe` renamed to `.disabled` | Hiding the icon alone does **not** stop the host from preloading | ~250 MB RAM + 6 WebView2 processes gone |
| Logon task `SearchHost-Kill` | A feature update can restore the executable | Any resident copy is removed after login |

> 📌 The Start menu itself still opens and launches apps — only *searching* is unavailable. `-KeepSearchUI` keeps it, and `Revert.ps1` fully restores it.

### 6. Windows Defender tuning (not disabling)

| Change | Why | Effect |
|---|---|---|
| Low CPU priority (`EnableLowCpuPriority`) | Scans yield CPU to the game | No scan-induced stutter |
| Scan CPU cap 10 % | Default 50 % is aggressive | Scans stay in the background |
| Scheduled / catch-up scans off | Unnecessary wake-ups | Quieter idle |
| Network drive / file scanning off | Prevents LAN transfers being slowed by AV | Faster copies |
| Unused `Sense` agent stopped | Consumer/LTSC PCs are never onboarded to Defender for Endpoint | Saves memory |
| **Real-time protection stays ON** | Security is not negotiable | You remain protected |

### 7. Store app debloat

| Removed | Kept |
|---|---|
| Clipchamp, Bing News / Weather / Search, Outlook, Teams, To Do, Office Hub, Feedback Hub, Get Help, Alarms, Your Phone, Dev Home, Family, Quick Assist, Widgets Runtime, Start Experiences, Camera (only if no camera hardware) | Photos, Snipping Tool, Solitaire, Media Player, Camera (if hardware exists), Paint, Notepad, Terminal, Calculator, Store, Xbox / Gaming services, runtime libraries and codecs |

Apps are removed for **the current user and all users** (provisioned packages too). Less update traffic, fewer background permissions, cleaner Start menu.

### 8. Disk cleanup

| Target | Typical gain |
|---|---|
| User + Windows TEMP | 1–4 GB |
| WinRE leftover (`C:\$WinREAgent`) | 1–2 GB |
| Windows Update cache (`SoftwareDistribution`, `catroot2`) | 0.5–5 GB |
| Crash dumps, WER reports, Live Kernel Reports | 100 MB–1 GB |
| NVIDIA / AMD / DirectX shader caches | 100–800 MB |
| Delivery Optimization cache | 100 MB–1 GB |
| Logs older than 7 days, icon/thumbnail caches | 100–500 MB |

The Windows Update cache is fully reset (services stopped, folders renamed and rebuilt). Icon caches are rebuilt automatically — the first Explorer open may take a second.

### 9. Service slimming with a protected core

The script never touches a hard-coded **protected list**: core Windows (`RpcSs`, `EventLog`, `Winmgmt`, `Power`, `PlugPlay`…), LAN/SMB (`LanmanWorkstation`, `LanmanServer`, `lmhosts`, `iphlpsvc`, `mpssvc`, Function Discovery), security (`WinDefend`, `wscsvc`, `mpssvc`, `BITS`, `wuauserv`), audio, GPU and Xbox/gaming services.

Groups that *are* disabled: telemetry/diagnostics, push and cloud sync, parental controls, offline maps, geolocation, media sharing, enterprise/App-V, remote registry/RRAS, fax, smart card, NFC, work folders, indexing (`WSearch`), printing (`Spooler`, opt-out available), plus hardware-absent services.

Every change is logged as `SET`, `KEEP`, `SKIP` or `NOCHG`, so you can see exactly what happened.

### 10. LAN discovery and network tuning

See [detection](#-how-the-script-decides-things-detection). In short: other PCs stay visible on the LAN, SMB2/3 and the firewall groups stay on, and only genuinely unnecessary protocols are disabled.

| Tuning | Why |
|---|---|
| RSS on, auto-tuning normal | Multi-core packet processing, good LAN + internet throughput |
| ECN / timestamps / NetDMA off | Avoids stalls with older routers |
| Nagle off per active NIC | Lower latency in games |
| QoS reserve 0 | No bandwidth held back |
| NIC power saving / EEE / RSC off | No random packet drops |
| SMB1 off (unless in use) | Security; SMB2/3 serves Windows and Linux shares |
| Delivery Optimization peering off | Windows updates do not saturate your LAN |
| Fastest DNS + fallback | Faster name resolution, IP unchanged |
| DNS cache flush | Fresh lookups after the change |

### 11. Backup and revert

See [Revert](#-revert--undo-everything).

---

## 🎛️ Command-line flags

| Flag | What it does |
|---|---|
| `-KeepPrintSpooler` | Keep printing enabled |
| `-KeepWindowsSearch` | Keep the search indexer (`WSearch`) |
| `-KeepDefenderDailyScan` | Keep a daily Defender scan at 03:00 |
| `-KeepSearchUI` | Keep the Start-menu search UI (default: fully disabled) |
| `-KeepCopilot` | Keep Windows Copilot and the Copilot app |
| `-KeepNotifications` | Keep push notification services (`WpnService`, `WpnUserService`) for apps like Discord/Slack/Telegram |
| `-EnableHAGS` | Enable Hardware-Accelerated GPU Scheduling (reduces latency on modern GPUs) |
| `-DryRun` | Log what would change without modifying system settings |
| `-SkipDebloat` | Do not remove Store apps |
| `-SkipCleanup` | Skip disk cleanup and the WU cache reset |
| `-SkipRestorePoint` | Do not create a System Restore point |
| `-SkipDns` | Do not touch DNS servers |
| `-DnsKeepLocalFirst` | Router/AD DNS first, fastest public DNS appended |
| `-EmptyRecycleBin` | Also empty the Recycle Bin |
| `-DisableMouseAcceleration` | Mouse acceleration off (changes aiming feel) |
| `-DisableSysMain` | Force-disable SysMain (auto-off on SSD, kept on HDD otherwise) |
| `-DeepComponentCleanup` | DISM component cleanup with `/ResetBase` (10–30 min) |
| `-NoLAN` | Force LAN-discovery services off even on a LAN |
| `-KeepSMB1` | Keep SMB1 for very old NAS / XP devices |
| `-NoPause` | No "press Enter" at the end (unattended runs) |

Examples:

```powershell
# Print from this PC
.\Win11-Gaming-Setup.ps1 -KeepPrintSpooler

# Need file-content search and the search box
.\Win11-Gaming-Setup.ps1 -KeepWindowsSearch -KeepSearchUI

# Maximum disk reclaim
.\Win11-Gaming-Setup.ps1 -EmptyRecycleBin -DeepComponentCleanup
```

---

## 🔐 Safety model

| Guard | What it prevents |
|---|---|
| Protected service list | Accidentally stopping core Windows, security, audio, GPU, LAN or Xbox services |
| Running-dependents check | Disabling a service another running service still needs |
| Verify-after-change | A refused `sc.exe config` is logged as `NOCHG`, not treated as success |
| Hardware detection | Disabling WiFi/Bluetooth/camera/scanner services on a PC that has that hardware |
| LAN detection | Other PCs disappearing from Explorer → Network |
| Backup merge | Re-runs never overwrite the original service states |
| Restore point attempt | A Windows-level rollback point before changes |
| No personal-file touch | Documents, photos and game saves are never deleted |

> ⚠️ Security is deliberately preserved: **Defender real-time protection, Firewall, SmartScreen, Windows Update and BITS stay enabled.**

---

## ↩️ Revert — undo everything

Double-click **`REVERT-AS-ADMIN.cmd`**, or:

```powershell
powershell -ExecutionPolicy Bypass -File .\Revert.ps1
```

| Restored | Source |
|---|---|
| Service start types | `backup\services-backup.json` |
| Registry values | `backup\*.reg` imported |
| Power scheme & hibernation | `backup\power-scheme.txt` + `powercfg /h on` |
| Scheduled tasks | `backup\tasks-backup.json` re-enabled |
| SMB1 configuration | `backup\smb1.reg` + `Set-SmbServerConfiguration` |
| DNS servers | `backup\dns-backup.json` (or DHCP automatic) |
| Search UI | `SearchHost.exe.disabled` renamed back, owner restored, `SearchHost-Kill` / `SearchHost-Trim` tasks removed |
| Logging | Full audit trail written to `logs\revert-*.log` |

> 📌 Uninstalled Store apps are **not** reinstalled automatically — get them from the Microsoft Store. A reboot after revert is recommended.

---

## 🪟 Windows 10 / LTSC notes

Build detection means the script works on Windows 11, Windows 10 and LTSC / IoT LTSC images.

| Area | Windows 11 | Windows 10 / LTSC |
|---|---|---|
| Classic context menu | applied | skipped (already the default) |
| Widgets / Copilot / Phone Link | policies written | written, ignored if absent |
| Store app debloat | 19 apps | usually "No removable Store apps found" — normal on LTSC |
| Search UI | host renamed + logon task | `SearchHost.exe` usually absent — skipped |
| Search / web results | off | off (works on both) |
| Timeline, News feed, Meet Now | not present | off |
| Defender tuning | full parameter set | unsupported parameters skipped individually; unused `Sense` disabled without MDE onboarding |
| Services | same list | missing services skipped, hardware checks unchanged |

---

## ✅ Verify it worked

```powershell
# Search should be gone
Get-Process SearchHost,msedgewebview2 -ErrorAction SilentlyContinue
Test-Path 'C:\Windows\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\SearchHost.exe.disabled'

# DNS and IP (IP must be unchanged)
Get-DnsClientServerAddress -AddressFamily IPv4 | Select InterfaceAlias,ServerAddresses
Get-NetIPConfiguration | Select InterfaceAlias,IPv4Address

# Services and protection
Get-Service DiagTrack,WSearch,Spooler,SysMain,SSDPSRV,upnphost,FDResPub,fdPHost,WinDefend -ErrorAction SilentlyContinue |
  Select Name,Status,StartType
Get-MpComputerStatus | Select RealTimeProtectionEnabled,AntivirusEnabled

# The newest log
Get-Content (Get-ChildItem "$env:ProgramData\Win11GamingSetup\logs\setup-*.log" |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
```

Full copy-paste instructions are in **[`RUN-COMMANDS.txt`](RUN-COMMANDS.txt)**.

---

## 🛠️ Troubleshooting

| Symptom | Fix |
|---|---|
| "Running scripts is disabled on this system" | Use the `.cmd` launcher, or the full command with `-ExecutionPolicy Bypass` |
| UAC prompt does not appear | Click the taskbar — the consent window is often behind other windows |
| "Access is denied" / nothing changes | Close the window, open PowerShell as Administrator, run again |
| Restore point step fails | System Restore is off on that PC — add `-SkipRestorePoint` |
| Other PCs not visible in Explorer → Network | Ensure the network profile is `Private`, LAN is connected at run time, and re-run without `-NoLAN` |
| Search still appears | A feature update restored the host — re-run the script (the logon task also removes it), or check that you did not pass `-KeepSearchUI` |
| Some registry lines show "unauthorized operation" | Windows protects a few policy keys even from an elevated user; those tweaks are cosmetic and harmless |
| File-content search no longer works | Expected: `WSearch` is off. Re-enable with `-KeepWindowsSearch` or `Revert.ps1` |
| Printing stopped | Expected: `Spooler` is off. Add `-KeepPrintSpooler` and re-run |

---

## ⚠️ Honest limitations (read this before believing the hype)

- **No FPS is guaranteed.** The script removes overhead; it cannot make an i5-2500K into a modern CPU.
- **Search is completely disabled by default.** The Start menu still works, but typing a search query returns nothing. `-KeepSearchUI` opts out.
- **Renaming a system executable is a deliberate, invasive tweak.** Windows feature updates can restore it; the logon task handles that, but the method is a trade-off, not an official Microsoft setting.
- **Defender's ~200 MB is mostly baseline AV memory.** The script lowers CPU cost and removes the unused Endpoint agent; it does not (and should not) turn real-time protection off.
- **Disabling `WSearch` makes file-content search slower**, and disabling `Spooler` stops all printing until re-enabled.
- **`-DeepComponentCleanup` uses `/ResetBase`** — installed Windows updates can no longer be uninstalled afterwards.
- **Public DNS is not always best for local names.** The original DNS is kept as fallback; use `-DnsKeepLocalFirst` if your LAN relies on it.
- **Re-runs are safe but not magical**: cleanup and WU cache reset run again, so the second run usually frees much less space.
- **Store apps removed are not auto-reinstalled** on revert.
- **Always keep a backup of important data.** The script does not touch personal files, but no system tweak is risk-free.

---

## 📁 Files, logs and backups

```
Win11-Gaming-Setup/
├── RUN-AS-ADMIN.cmd         # double-click to run everything
├── REVERT-AS-ADMIN.cmd      # double-click to undo
├── Win11-Gaming-Setup.ps1   # main script
├── Revert.ps1               # undo script (regenerated on every run)
├── RUN-COMMANDS.txt         # copy-paste commands and instructions
└── README.md

C:\ProgramData\Win11GamingSetup\
├── logs\setup-YYYYMMDD-HHmmss.log
├── logs\disk-check.txt
├── backup\
│   ├── services-backup.json
│   ├── dns-backup.json
│   ├── searchui-disabled.json
│   └── *.reg
├── Revert.ps1
├── kill-searchhost.ps1
└── trim-searchhost.ps1
```

---

## 📤 Publishing to GitHub

The folder already contains a local Git repository on `main` (with `.gitignore`, `.gitattributes` and MIT `LICENSE`). From a machine with Git:

```bash
cd Win11-Gaming-Setup
git remote add origin git@github.com:mayanktaker/win11-gaming-setup.git
git push -u origin main
```

If you copied only the files (no `.git` folder), create the history first:

```bash
git init -b main
git add .
git commit -m "Windows gaming setup: tweaks, cleanup, debloat, services, revert"
git remote add origin git@github.com:mayanktaker/win11-gaming-setup.git
git push -u origin main
```

Suggested repository settings:

| Setting | Value |
|---|---|
| Name | `win11-gaming-setup` |
| Description | *One script to turn Windows 10 / 11 (LTSC included) into a lean gaming-only PC: tweaks, cleanup, debloat, service slimming, LAN-aware detection, fastest DNS and one-click revert.* |
| Topics | `windows-11`, `windows-10`, `ltsc`, `gaming`, `debloat`, `powershell`, `performance`, `tweaks`, `cleanup` |
| License | MIT |

---

## 📜 License

MIT — use it, fork it, improve it. No warranty. Read the script before running it on a production machine.
