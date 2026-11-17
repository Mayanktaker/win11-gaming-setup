# © Mayanktaker Computers & Web Development | https://mayanktaker.com

# Changelog

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
