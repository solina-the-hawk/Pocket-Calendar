# Pocket Calendar
**A smart time-management, event-tracking, and birthday ledger for Achaea and Mudlet.**

Because Achaean time moves at a fixed rate relative to the real world (1 Achaean day = 1 real hour), Pocket Calendar seamlessly converts between the two. Whether you are coordinating a city election using Achaean months, planning a combat spar in "90 minutes", or trying to figure out exactly when a GMT timestamp from an old log occurred in the game's history, this script does the math for you.

Unlike older tracking scripts, Pocket Calendar features zero external dependencies, zero alias clutter (everything routes through a single `cal` command), utilizes invisible GMCP data for minute-level precision, and includes a fully integrated Birthday Tracker.

---
## Screenshots
<img width="800" alt="Pocket Calendar List Example" src="URL_TO_IMAGE_HERE" />
<img width="800" alt="Pocket Calendar Help Example" src="URL_TO_IMAGE_HERE" />


## Features

* **Zero Bloat:** Single-script architecture. Everything is routed through a single master alias (`cal`), keeping your Mudlet alias list perfectly clean. Just type `cal` to see your dashboard!
* **GMCP Precision Timekeeping:** Silently synchronizes with the server in the background. It tracks the exact Achaean hour, giving your real-world countdowns minute-level accuracy.
* **Bi-Directional Conversions:** Add events to your calendar using exact Achaean dates (e.g., 15 Valnuary 950) or relative real-world times (e.g., "in 90 mins"). 
* **Official Event Ingestion:** Type `cal upcoming <#>` to instantly scrape an event directly from Achaea's UPCOMING list and drop it onto your personal calendar.
* **Chronological Sorting & Countdowns:** Type `cal list` to view your schedule at a glance. Events are automatically sorted chronologically and display a live real-time countdown.
* **Smart Warning System:** Toggle warnings on specific events. The system will alert you when a warned event is less than 60 real minutes away.
* **Timestamp Parsing:** Paste GMT or Local timestamps (`YYYY/MM/DD HH:MM:SS`) straight from Achaean news posts or Mudlet logs to instantly translate them into their Achaean date equivalent.
* **Integrated VIP Birthday Tracker:** Silently watches the `honours` command to build a database of known birthdays, allowing you to "monitor" your friends so their birthdays appear directly on your main calendar dashboard.

---

## Installation

1. Download the `PocketCalendar.mpackage` or import the `calendar-core.lua` script directly into your Mudlet Script Editor.
2. Log into Achaea.
3. The script will automatically handshake with the server and synchronize your time via GMCP! *(Note: You can also type the `DATE` command at any time to force a manual sync).*
4. Type `cal help` in the game for a full list of commands.

---

## Translating News & Logs (Timezones)

Achaean logs and news posts use a standard `YYYY/MM/DD HH:MM:SS` format, often in GMT. Pocket Calendar can translate these into Achaean dates so you can easily piece together game lore.

If you live outside the GMT timezone, you need to tell the calendar your offset so its math is perfectly accurate:
1. Type `cal timezone <#>` (e.g., `cal timezone -5` for US Central Daylight Time).
2. Copy a timestamp from an Achaean news board.
3. Type `cal check real gmt 2026/05/01 05:05:11`.
4. Pocket Calendar will automatically apply your timezone offset and spit out the exact Achaean date that the post was made!

*(Note: If you are looking at timestamps from your own local Mudlet logs, simply use `cal check real local <timestamp>` instead).*

---

## Tracking Birthdays (Known vs. Monitored)

Pocket Calendar absorbs and upgrades the old Solina Birthday Tracker. It builds a silent database of every birthday you see, and lets you elevate specific people to a "VIP Watchlist" that integrates seamlessly into your main calendar.

**Building your database is entirely automatic:** 1. Simply type `honours <PlayerName>` in the game.
2. The script will passively catch the birthday from the output and silently log it into your "Known Birthdays" database.

**Monitoring your friends:**
Once the calendar knows someone's birthday, you can choose to monitor them.
1. Type `cal bday monitor <name>`.
2. This player is now on your VIP Watchlist. Their upcoming birthday will now appear dynamically on your main `cal list` dashboard with a `[B]` tag, complete with a real-time countdown!
3. Type `cal bday unmonitor <name>` to remove them from your dashboard, or `cal bday clear` to wipe your entire watchlist and start fresh (this does *not* delete your known birthdays).
4. Type `cal bday others` to see a list of unmonitored birthdays coming up in the next 7 days.

If a player's age is hidden by the Sands of Aeon, you can manually inject their birthday into the database and watchlist using `cal bday add <name> <day> <month>`.