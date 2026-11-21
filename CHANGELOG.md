# © Mayanktaker Computers & Web Development | https://mayanktaker.com

# Changelog

## [1.8.0]

### What's new
- **Search UI stays on by default.** The full removal (taskbar entry hidden, `SearchHost.exe` renamed, logon cleanup task) is now opt-in with `-DisableSearchUI`. Running this version also **automatically restores** a search UI that an older script version removed.
- **Right-click menu stays untouched by default.** The classic Windows 10-style menu on Windows 11 is now opt-in with `-ClassicContextMenu`.

### Notes
- `-KeepSearchUI` is now a deprecated no-op (search is kept by default); old commands using it still run fine.

---

## [1.7.1]

### What's new
- Windows 11 power settings stay usable: the script no longer leaves duplicate Ultimate Performance schemes behind (older copies are cleaned up), never activates the raw hidden template scheme, and keeps the current scheme untouched on Modern Standby (S0) systems where legacy plans break the Settings power page.
- Dry-run is now truly non-destructive: power, disk cleanup, network, DNS, SMB1, firewall, Defender, restore-point and search-UI steps are skipped instead of executed.
- Revert is now complete: registry keys the script created are deleted, missing `.reg` backups were added (Fast Startup, priority control, Nagle interfaces, CloudContent and more), Defender scan preferences are restored, hibernation is only re-enabled if it was on before, and power schemes created by the setup are removed.

### Bug fixes
- Backups are now first-run snapshots: re-runs (and `-DryRun`) no longer overwrite the original registry, power-scheme, hibernation, SMB1 and DNS backups, so Revert always restores the true pre-setup state. Delete the `backup` folder to re-baseline on purpose.
- Fixed a `Cannot find an overload for "new"` error that stopped the scheduled-task backup from ever being written.
- `NetworkThrottlingIndex` is now written as `0xffffffff` so it applies reliably, and the audit check accepts both registry readback forms.
- Firewall rules are enabled only for Private/Domain profiles; Public-profile rules stay off.
- SearchHost: if a Windows update restored the executable, the leftover `.disabled` copy is cleaned up on re-run and on revert.

---

## [1.7.0]

### What's new
- Added a non-destructive System Audit mode (`CHECK-SETUP.cmd` / `-Audit`): quickly tests your gaming settings, calculates an optimization score, and flags whether any Windows Updates have undone your tweaks without changing any files.
- Added a double-click `VIEW-LOGS.cmd` launcher to immediately find and open your latest setup logs in Notepad.
- Added pre-packaged release zip downloads to releases so you can download everything ready-to-run with a single click.

### Bug fixes
- Improved command-line parameter handling when running unattended checks alongside self-elevation.

---

## [1.6.0]

### What's new
- Added instant access `logs.txt` log saving: each run automatically writes the complete log to `logs.txt` right in your setup folder and in `C:\ProgramData\Win11GamingSetup\logs.txt` for effortless viewing.
- Added start and finish banners acknowledging Mayanktaker Computers & Web Development with website link (https://mayanktaker.com).
- Added a friendly coffee appreciation message at the conclusion of runs.

### Bug fixes
- Ensured log creation gracefully handles read-only or restricted execution folders without interruptions.

---

## [1.5.0]

### What's new
- Added full support for the latest Windows 10 consumer editions (Home and Pro 22H2) and Windows 11 updates through version 26H2.
- Automatically unlocks and activates the Ultimate Performance power profile on supported desktop systems.
- Thorough cleanup of preinstalled sponsored consumer bloatware (including Candy Crush, TikTok, Spotify, Netflix, Disney+, and social apps).
- Automatically turns off background AI monitoring, Click to Do screenshot analysis, and Windows Recall background services on newer Windows 11 releases.
- Eliminates Edge background browser tasks, automatic shopping assistants, and startup boosts that run without the browser open.
- Shuts down background device linking and cross-device sync tasks to keep CPU and memory clear for games.
- Fullscreen game optimization settings now prioritize maximum frames and lower audio/input response delay.
- Added Intel graphics shader cache to the automated cleanup routine.

### Bug fixes
- Resolved a known network data telemetry memory leak that caused gradual RAM consumption during extended multiplayer gaming sessions.
- Suppressed background error reporting and diagnostic notifications during games.

---

## [1.4.0]

### What's new
- Added preview mode (`-DryRun`) to review all planned changes before making any system modifications.
- Added option to keep push notifications (`-KeepNotifications`) so apps like Discord, Telegram, and Slack can continue displaying message popups.
- Added option to retain Windows Copilot (`-KeepCopilot`) for users who rely on the assistant.
- Added hardware-accelerated GPU scheduling option (`-EnableHAGS`) to reduce input lag on supported graphics cards.
- Expanded app cleanup to remove extra preinstalled apps including Maps, Movies & TV, People, and Sticky Notes.
- Setup summary now reports the total elapsed execution time upon completion.
- Revert now fully restores your previous power plan and re-enables any scheduled tasks that were switched off.
- Revert now creates a dedicated log file so you have a complete history of restored settings.

### Bug fixes
- Network card power management now turns off properly so adapters will not go to sleep and drop connections mid-game.
- Cleaned up private folders from temporary file cleanup to prevent accidental file deletion.
- Restoring settings no longer skips disabled background tasks.

---

## [1.3.1]

### What's new
- Windows Defender background optimization runs smoothly on clean Windows installations without enterprise management tools installed.

### Bug fixes
- Fixed an issue where the background security agent check could cause script startup errors.

---

## [1.3.0]

### What's new
- Automated DNS server testing now tests multiple resolvers and automatically assigns the two fastest ones for quicker online gaming lookups.
- Added double-click admin launchers for both setup and revert tasks without needing to type PowerShell commands.

---

## [1.2.0]

### What's new
- Completely disables background search processes by default to eliminate idle memory overhead from web view renderers.
- Reduces background antivirus processor allocation to free up resources for games.

---

## [1.1.1]

### What's new
- Automatically detects local network connections and keeps local computer discovery active so home file sharing is never interrupted.
