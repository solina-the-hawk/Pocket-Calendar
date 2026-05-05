# Pocket Calendar
**A smart time-management, event-tracking, and birthday ledger for Achaea and Mudlet.**

Because Achaean time moves at a fixed rate relative to the real world (1 Achaean day = 1 real hour), Pocket Calendar seamlessly converts between the two. Whether you are coordinating a city election using Achaean months, planning a combat spar in "2 hours", or trying to figure out exactly when a GMT timestamp from an old log occurred in the game's history, this script does the math for you.

Unlike older tracking scripts, Pocket Calendar features zero external dependencies, zero alias clutter (everything routes through a single `cal` command), and includes a fully integrated Birthday Tracker.

---
## Screenshots
<img width="800" alt="Pocket Calendar List Example" src="URL_TO_IMAGE_HERE" />
<img width="800" alt="Pocket Calendar Help Example" src="URL_TO_IMAGE_HERE" />


## Features

* **Zero Bloat:** Single-script architecture. Everything is routed through a single master alias (`cal`), keeping your Mudlet alias list perfectly clean.
* **Bi-Directional Conversions:** Add events to your calendar using exact Achaean dates (e.g., 15 Valnuary 950) or relative real-world times (e.g., "in 3 days"). 
* **Chronological Sorting & Countdowns:** Type `cal list` to view your schedule at a glance. Events are automatically sorted chronologically and display a live real-time countdown.
* **Smart Warning System:** Toggle warnings on specific events. The system monitors in-game midnight rollovers and will alert you when a warned event is less than 1 real hour (1 Achaean month) away.
* **Timestamp Parsing:** Paste GMT or Local timestamps (`YYYY/MM/DD HH:MM:SS`) straight from Achaean news posts or Mudlet logs to instantly translate them into their Achaean date equivalent.
* **Integrated Birthday Tracker:** Silently watches the `honours` command to automatically record player birthdays, calculating exactly how many real-world days are left until they age.

---

## Installation

1. Download the `PocketCalendar.mpackage` or import the `calendar-core.lua` script directly into your Mudlet Script Editor.
2. Log into Achaea.
3. Type `DATE` in the game. **(This is strictly required on your first login!)** It anchors the script's math to the exact current Achaean time. From there, the script will silently update itself every in-game midnight.
4. Type `cal help` in the game for a list of helpful commands!

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

## Tracking Birthdays (Zero Setup!)

Pocket Calendar absorbs and upgrades the old Solina Birthday Tracker. It manages a watchlist of upcoming birthdays and tells you exactly how many real hours/days remain until the player ages.

**You do not need to manually add birthdays.** The script handles the triggers automatically. 
1. Simply type `honours <PlayerName>` in the game.
2. The script will passively catch the birthday from the output, save it to its database, and add the player to your watchlist.
3. Type `cal bday list` to view your upcoming tracked birthdays!

If a player's age is hidden by the Sands of Aeon, you can manually inject their birthday into the database using `cal bday add <name> <day> <month>`.
