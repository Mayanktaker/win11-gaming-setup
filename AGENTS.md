# © Mayanktaker Computers & Web Development | https://mayanktaker.com

# AGENTS.md — Operating Map

## Environment
- **Project:** win11-gaming-setup (v1.7.1)
- **Target OS:** Windows 11 (21H2 through 26H2+ / build 27000+), Windows 10 (Home, Pro, Enterprise 22H2 build 19045, incl. LTSC 2019/2021/2024 / IoT LTSC)
- **Runtime:** PowerShell 5.1+ / PowerShell Core 7+
- **Privilege Requirement:** Elevated (Administrator / UAC self-elevating)
- **Package Manager / Tooling:** Native Windows CLI / PowerShell cmdlets, `powercfg`, `sc.exe`, `reg.exe`, `schtasks.exe`, `dism.exe`

## Core Architecture
- `Win11-Gaming-Setup.ps1`: Primary optimization and audit script (UI, Power, Gaming registry, Background tasks/telemetry, Defender tuning, Debloat, Disk cleanup, Services slimming, Network/DNS, Icon cache, Revert generator, Summary, Audit mode).
- `Revert.ps1`: Rollback script to restore service start types, import registry backups, revert DNS, re-enable power scheme, restart hibernation, re-enable scheduled tasks, and restore SearchHost.
- `RUN-AS-ADMIN.cmd`: Double-click batch wrapper invoking `Win11-Gaming-Setup.ps1` with UAC prompt.
- `CHECK-SETUP.cmd`: Double-click batch wrapper invoking non-destructive optimization audit and Windows Update drift detection.
- `VIEW-LOGS.cmd`: Double-click batch wrapper to view current execution logs in Notepad.
- `REVERT-AS-ADMIN.cmd`: Double-click batch wrapper invoking `Revert.ps1` with UAC prompt.
- `.github/workflows/release.yml`: Automated CI/CD release workflow packaging and attaching zip bundles.
- `C:\ProgramData\Win11GamingSetup\`: Runtime root for logs (`logs\`, `logs.txt`) and backups (`backup\`).

## Conventions & Rules
- **Non-destructive debloat:** Never disable core Windows, LAN discovery, security stack (Defender real-time, Firewall, SmartScreen), or Windows Update.
- **Hardware-adaptive:** Only disable WiFi, Bluetooth, camera, or biometric services if respective hardware devices are absent.
- **LAN-aware:** Retain SSDP, UPnP, and Function Discovery when on Private/Domain networks or when local shares exist.
- **Single Source of Truth:** Changes must be mirrored in `Win11-Gaming-Setup.ps1` (inline revert generator) and `Revert.ps1`.

## Key Commands
- Standard run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\Win11-Gaming-Setup.ps1`
- Audit / Drift check: `powershell -NoProfile -ExecutionPolicy Bypass -File .\Win11-Gaming-Setup.ps1 -Audit`
- Dry run (preview): `powershell -NoProfile -ExecutionPolicy Bypass -File .\Win11-Gaming-Setup.ps1 -DryRun`
- Unattended: `powershell -NoProfile -ExecutionPolicy Bypass -File .\Win11-Gaming-Setup.ps1 -NoPause`
- Revert: `powershell -NoProfile -ExecutionPolicy Bypass -File .\Revert.ps1`

## Document Pointers
- `README.md` -> Full feature breakdown, benchmark metrics, safety model, and troubleshooting
- `RUN-COMMANDS.txt` -> Copy-paste command reference and flag usage
- `CHANGELOG.md` -> User-facing version history
- `LICENSE` -> MIT License
