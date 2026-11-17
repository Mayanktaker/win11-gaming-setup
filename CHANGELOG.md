# © Mayanktaker Computers & Web Development | https://mayanktaker.com

# Changelog

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
