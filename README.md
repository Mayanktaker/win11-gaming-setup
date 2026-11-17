# 🎮 Win11 Gaming Setup

> One PowerShell script that turns a fresh Windows 10 or 11 install (LTSC included) into a lean, fast, **gaming-only** machine — tweaks, cleanup, debloat and service slimming, with a one-click revert.

![Platform](https://img.shields.io/badge/platform-Windows%2011%20%7C%2010%20%7C%20LTSC-0078D6?style=flat-square&logo=windows)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=flat-square&logo=powershell)
![Admin](https://img.shields.io/badge/requires-Administrator-red?style=flat-square)
![Revert](https://img.shields.io/badge/revert-included-success?style=flat-square)
![Version](https://img.shields.io/badge/version-1.1.1-blue?style=flat-square)

---

## ✨ What it does

| Area | Result |
|---|---|
| 🖱️ **Right-click menu** | Restores the fast classic context menu (Windows 11's WinUI menu is slow on older hardware) |
| 💨 **UI speed** | Animations, transparency, list-view shadows and the 400 ms menu delay are turned off |
| ⚡ **Power** | High Performance plan, CPU min state 100 %, PCIe ASPM off, sleep never, monitor off after 10 min |
| 🛑 **Fast Startup / Hibernate** | Both off — removes `hiberfil.sys` and power-transition glitches |
| 🎯 **Gaming** | GameDVR / Game Bar recording off, Game Mode on, MMCSS *Games* profile boosted, Win32 priority 38, power throttling off |
| 🛡️ **Defender** | Low CPU priority, 20 % scan CPU cap, scheduled scan off — **real-time protection stays ON** |
| 🧹 **Background junk** | Copilot, Widgets, Phone Link background access, ads, suggestions, telemetry tasks |
| 🔍 **Search** | Start-menu search becomes local-only: Bing/web results, cloud search, search highlights and the suggestion dropdown are off (the search UI still works) |
| 📦 **Store apps** | 19 apps removed (Photos, Snipping Tool, Solitaire, Media Player stay) |
| 💾 **Cleanup** | Temp, WER, crash dumps, shader caches, icon/thumbnail cache, WinRE leftover, Windows Update cache |
| ⚙️ **Services** | ~50 non-essential services disabled, hardware-aware (WiFi / BT / camera / scanner / fingerprint) |
| 🌐 **Network** | RSS, auto-tuning, Nagle off, QoS reserve 0, NIC power saving off, SMB1 off |
| ↩️ **Safety** | Restore point attempt + registry backups + auto-generated `Revert.ps1` |

> ⚠️ **No security feature is disabled.** Defender real-time protection, Firewall, SmartScreen, Windows Update, BITS and the SMB/LAN stack are always preserved.

---

## 🚀 Quick start

> Copy-paste ready commands with step-by-step instructions are in
> **[`RUN-COMMANDS.txt`](RUN-COMMANDS.txt)** — open that file on the target PC.

```powershell
# 1. Open PowerShell in this folder, unblock the scripts, then run:
Get-ChildItem -Path . -Filter *.ps1 | Unblock-File
powershell -NoProfile -ExecutionPolicy Bypass -File .\Win11-Gaming-Setup.ps1
```

Or simply **right-click** `Win11-Gaming-Setup.ps1` → **Run with PowerShell** → press **Yes** on the UAC prompt.

The script re-launches itself elevated, prints a coloured live log, and ends with a summary:

```
  System drive free space : 44.5 GB -> 64.4 GB  (+19.9 GB)
  Services changed        : 52
  Scheduled tasks off     : 13
  Store apps removed      : 19
```

---

## 🎛️ Flags

| Flag | What it does |
|---|---|
| `-KeepPrintSpooler` | Keep printing enabled (Print Spooler stays `Automatic`) |
| `-KeepWindowsSearch` | Keep Windows Search indexing (recommended if you search files a lot) |
| `-NoLAN` | Force LAN-discovery services off even if a LAN is detected (offline gaming PC) |
| `-KeepSMB1` | Keep SMB1 (only for very old NAS / Windows XP devices) |
| `-KeepDefenderDailyScan` | Keep a daily Defender scan at 03:00 |
| `-SkipDebloat` | Do not remove any Store app |
| `-SkipCleanup` | Skip disk cleanup and the Windows Update cache reset |
| `-SkipRestorePoint` | Do not create a restore point |
| `-EmptyRecycleBin` | Also empty the Recycle Bin |
| `-DisableMouseAcceleration` | Mouse acceleration off (FPS aim) — changes the feel, off by default |
| `-DisableSysMain` | Force-disable SysMain (auto-off on SSD, kept on HDD) |
| `-DeepComponentCleanup` | DISM component cleanup with `/ResetBase` (10–30 min) |
| `-NoPause` | No “press Enter” at the end (unattended use) |

Examples:

```powershell
# Gaming PC that also prints
.\Win11-Gaming-Setup.ps1 -KeepPrintSpooler

# Maximum disk reclaim
.\Win11-Gaming-Setup.ps1 -EmptyRecycleBin -DeepComponentCleanup

# Everything except app removal
.\Win11-Gaming-Setup.ps1 -SkipDebloat
```

---

## 🧩 Store apps

### ❌ Removed

| App | Why |
|---|---|
| Clipchamp | Video editor, not needed for gaming |
| Bing News / Bing Weather / Bing Search | Ads + background network calls |
| Outlook for Windows | Not needed |
| Teams (new + chat) | Background chat + autostart |
| Microsoft To Do | Not needed |
| Office Hub | Office upsell + Copilot host |
| Feedback Hub, Get Help | Telemetry / support bloat |
| Alarms & Clock | Not needed |
| Phone Link | Background sync with phones |
| Widgets Platform Runtime | Widgets board backend |
| Dev Home | Developer tooling |
| Family Safety / Parental Controls | Home-only extras |
| Quick Assist | Remote support tool |
| Start Experiences | Tips & suggestions backend |
| **Camera** | Only when **no camera hardware** is detected |

### ✅ Always kept

| Kept | Reason |
|---|---|
| 🖼️ **Photos** | Asked to keep |
| ✂️ **Snipping Tool** (`ScreenSketch`) | Screenshots |
| 🃏 **Microsoft Solitaire Collection** | Asked to keep |
| 🎵 **Media Player** (`ZuneMusic`) | Local media |
| 📷 **Camera** | If camera hardware exists |
| 🎨 Paint, 📝 Notepad, ⌨️ Terminal, 🧮 Calculator | Everyday tools |
| 🏪 Microsoft Store | Needed for app updates |
| 🎮 Xbox / Gaming App / Game Bar | Gaming features |
| 🧱 WebView2, VCLibs, App Runtime, codecs (HEVC, VP9, AV1, WebP…) | Dependencies |

---

## ⚙️ Services

The script never touches services it cannot safely judge. Every change is checked
against a **protected list**, a **running-dependents check**, and after the change
it verifies the registry start value actually changed.

### 🔒 Never touched (protected)

| Group | Services |
|---|---|
| Core Windows | `RpcSs`, `DcomLaunch`, `LSM`, `SamSs`, `Winmgmt`, `EventLog`, `Schedule`, `ProfSvc`, `gpsvc`, `Power`, `PlugPlay`, `StateRepository`, `CoreMessagingRegistrar`, … |
| LAN / file transfer | `LanmanWorkstation`, `LanmanServer`, `Dnscache`, `Dhcp`, `nsi`, `NlaSvc`, `netprofm`, `lmhosts`, `FDResPub`, `fdPHost` |
| Security | `WinDefend`, `SecurityHealthService`, `wscsvc`, `SgrmBroker`, `Sense`, `mpssvc`, `CryptSvc`, `BITS`, `wuauserv` |
| Audio / GPU | `Audiosrv`, `AudioEndpointBuilder`, `NVDisplay.ContainerLocalSystem` |
| Xbox / gaming | `XblAuthManager`, `XblGameSave`, `XboxGipSvc`, `XboxNetApiSvc`, `GamingServices`, `GamingServicesNet`, `GameInputSvc` |
| Remote desktop | `TermService`, `UmRdpService`, `SessionEnv` |

### 🚫 Disabled on every PC

| Category | Services |
|---|---|
| Telemetry & diagnostics | `DiagTrack`, `dmwappushservice`, `diagnosticshub.standardcollector.service`, `WerSvc`, `DPS`, `PcaSvc`, `wisvc`, `diagsvc`, `WdiServiceHost`, `WdiSystemHost` |
| Push & cloud sync | `WpnService`, `WpnUserService*`, `CDPSvc`, `CDPUserSvc*`, `OneSyncSvc*`, `PimIndexMaintenanceSvc*`, `BcastDVRUserService*` |
| Consumer extras | `WpcMonSvc`, `MapsBroker`, `lfsvc`, `AJRouter`, `WMPNetworkSvc`, `RetailDemo`, `icssvc`, `WwanSvc`, `SDRSVC`, `SmsRouter`, `SEMgrSvc`, `WalletService` |
| Enterprise / dev | `AppVClient`, `EntAppSvc`, `embeddedmode`, `NetTcpPortSharing`, `NetTcpActivator`, `NetPipeActivator`, `NetMsmqActivator`, `DmEnrollmentSvc`, `WorkFoldersSvc` |
| Remote & legacy | `RemoteRegistry`, `RemoteAccess`, `seclogon`, `WinRM`, `TapiSrv`, `PhoneSvc`, `Fax`, `upnphost`, `SSDPSRV`, `Bonjour Service`, `SCardSvr`, `ScDeviceEnum`, `TieringEngineService` |
| Indexing & maintenance | `WSearch`, `TrkWks`, `KtmRm`, `SensorService`, `SensrSvc` |
| Vendors | `NvTelemetryContainer` |
| Optional | `Spooler` (printing), `SysMain` (SSD only) |

### 🧠 Hardware-adaptive (only when the hardware is missing)

| Hardware | Services disabled |
|---|---|
| No WiFi adapter | `WlanSvc`, `RmSvc` |
| No Bluetooth | `bthserv`, `BTAGService`, `BthAvctpSvc`, `BluetoothUserService*` |
| No camera | `FrameServer`, `FrameServerMonitor` |
| No scanner | `stisvc` |
| No fingerprint / iris | `WbioSrvc` |
| No touch / pen | `TabletInputService` |

So a laptop with WiFi + Bluetooth + webcam keeps all of those working — nothing is lost.

---

## 🌐 Network tuning

| Setting | Value | Effect |
|---|---|---|
| Receive-Side Scaling | `enabled` | Multi-core packet processing |
| Receive Window Auto-Tuning | `normal` | Good throughput on LAN + internet |
| ECN | `disabled` | Avoids old-router stalls |
| Timestamps / NetDMA | `disabled` | Lower per-packet overhead |
| Nagle (`TcpAckFrequency`, `TCPNoDelay`) | `1` / `1` | Lower latency in games |
| QoS reserved bandwidth | `0` | Nothing held back |
| NIC power saving / EEE / RSC | off | No random packet drops |
| SMB1 | `disabled` unless an SMB 1.5 connection is active | Security (SMB2/3 stays on for Linux & Windows shares) |
| Delivery Optimization | HTTP only | LAN stays free for file transfers |
| Firewall | Discovery + File Sharing allowed | Linux ↔ Windows transfers work |
| DNS cache | flushed | Fresh lookups |

---

## 🖧 LAN discovery (auto-detected)

Explorer → **Network** and `\\hostname` / `\\IP` browsing need
`SSDPSRV`, `upnphost`, `FDResPub` and `fdPHost`. Older versions of this
script disabled SSDP/UPnP, which made other LAN PCs disappear from the
Network view while direct transfers still worked.

The script now decides from the machine itself:

| Detection | Result |
|---|---|
| Active `Private` / `DomainAuthenticated` network profile | LAN → discovery services kept ON and started |
| Private IPv4 address (`10.*`, `172.16-31.*`, `192.168.*`) | LAN → same |
| Local SMB shares or mapped network drives | LAN → same |
| None of the above | SSDP/UPnP slimmed as telemetry-safe overhead |
| `-NoLAN` | Force the slim behaviour on any machine |

`LanmanWorkstation`, `LanmanServer`, `lmhosts`, `iphlpsvc`, `mpssvc` and
Function Discovery stay in the protected list in every case, and the
Network Discovery + File and Printer Sharing firewall groups are enabled.

SMB1 is disabled by default for security, but is **kept automatically** when
an active SMB 1.5 connection is detected, or with `-KeepSMB1`.

---

## 💾 Cleanup details

| Target | Typical gain |
|---|---|
| `%TEMP%` + `C:\Windows\Temp` | 1–4 GB |
| WinRE leftover `C:\$WinREAgent` | 1–2 GB |
| NVIDIA DX / GL shader cache | 100–500 MB |
| DirectX / AMD shader caches | 50–300 MB |
| WER reports + crash dumps | 100 MB–1 GB |
| Icon + thumbnail cache | 20–200 MB |
| Windows Update cache (`SoftwareDistribution`, `catroot2`) | 0.5–5 GB |
| Windows logs older than 7 days | 100–500 MB |
| Delivery Optimization cache | 100 MB–1 GB |
| Recycle Bin (with `-EmptyRecycleBin`) | varies |

Fragment caches are rebuilt automatically — first Explorer open may feel slightly slower for a few seconds.

---

## ↩️ Revert

The script writes **`Revert.ps1` next to itself** and in `C:\ProgramData\Win11GamingSetup\`.

```powershell
powershell -ExecutionPolicy Bypass -File .\Revert.ps1
```

It restores:

| Restored | Source |
|---|---|
| Service start types | `backup\services-backup.json` |
| Registry values | `backup\*.reg` (imported) |

> Store apps that were uninstalled are **not** restored automatically — reinstall them from the Microsoft Store. Optionally create a restore point before running the script (it does this automatically unless `-SkipRestorePoint`).

---

## 📁 Files & logs

```
Win11-Gaming-Setup/
├── Win11-Gaming-Setup.ps1   # main script (run this)
├── Revert.ps1               # undo, generated on every run
├── RUN-COMMANDS.txt         # copy-paste commands + instructions
└── README.md

C:\ProgramData\Win11GamingSetup\
├── logs\setup-YYYYMMDD-HHmmss.log
└── backup\
    ├── services-backup.json
    └── *.reg
```

The backup is **merged**, not overwritten, on re-runs — so running the script twice never destroys the original service state.

---

## 🪟 Windows 10 / LTSC

The script detects the running build and skips what does not exist instead of failing.

| Area | Windows 11 | Windows 10 / LTSC |
|---|---|---|
| Classic right-click menu | applied | skipped (already the default) |
| Widgets, Copilot, Phone Link | policies written | written, ignored if absent |
| Store app debloat | 19 apps | usually "No removable Store apps found" — normal on LTSC |
| Search: web/Bing results | off | off (works on both) |
| Timeline / Activity history | off | off |
| News and Interests, Meet Now | not present | off |
| Defender tuning | full parameter set | unsupported parameters skipped one by one |
| Services | same list | missing services skipped, hardware checks unchanged |

---

## ✅ Verified on

| Item | Value |
|---|---|
| OS | Windows 11 build 26300 (Windows 10 / LTSC supported by build checks) |
| CPU | Intel Core i5-2500K (unsupported hardware) |
| RAM | 12 GB DDR3-1333 |
| GPU | NVIDIA GTX 750 Ti 2 GB |
| Result | +19.9 GB free, 52 service settings, 19 apps removed, UI noticeably snappier |

---

## 🧯 Safety notes

- Run it on a **gaming-only** PC. On a work PC you may want `-KeepPrintSpooler -KeepWindowsSearch -SkipDebloat`.
- Disabling `WSearch` makes file-content search slower; Start-menu app search still works.
- Start-menu search is set to **local results only** (no Bing web answers) — typing an app name is instant, typing a question no longer opens a web page.
- Disabling `Spooler` stops all printing until you re-enable it.
- `-DeepComponentCleanup` uses `/ResetBase`, which prevents uninstalling installed updates afterwards.
- Old, unsupported hardware (like the test machine) is still limited by the hardware itself — this script removes software overhead, not physics.
- Always keep a backup of important data. This script does not touch personal files.

---

## 📜 License

MIT — use it, fork it, improve it. No warranty; read the script before running it on production machines.

---

## 📤 Publishing to GitHub

The folder is git-ready: it already contains a local commit on `main`, plus `.gitignore`, `.gitattributes` and `LICENSE`. From the Linux machine:

```bash
cd Win11-Gaming-Setup

# The commit is already there - only add a remote and push:
git remote add origin git@github.com:<your-user>/win11-gaming-setup.git
git push -u origin main
```

If you copied only the files (no `.git` folder), create the repository history first:

```bash
git init -b main
git add .
git commit -m "Windows gaming setup: tweaks, cleanup, debloat, services, revert (Win10/11 + LTSC)"
git remote add origin git@github.com:<your-user>/win11-gaming-setup.git
git push -u origin main
```

Suggested repository settings:

| Setting | Value |
|---|---|
| Name | `win11-gaming-setup` |
| Description | *One PowerShell script to turn Windows 10 or 11 into a lean, fast, gaming-only PC: tweaks, cleanup, debloat, service slimming and network tuning, with a one-click revert.* |
| Topics | `windows-11`, `windows-10`, `ltsc`, `gaming`, `debloat`, `powershell`, `performance`, `tweaks`, `cleanup` |
| License | MIT |

