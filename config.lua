mpackage = [[BirthdayTracker]]
author = [[Solina]]
title = [[Birthday tracker for Achaea]]
description = [[--------
SOLINA's BIRTHDAY TRACKER (MUDLET PACKAGE)
Version 1.1
--------


OVERVIEW
--------
This Mudlet package automatically tracks character birthdays in Achaea. It
silently monitors your 'honours' commands to build a database of birthdays,
calculates the current in-game date, and alerts you when a monitored friend's
birthday is coming up (within 25 Achaean days).


FEATURES
--------
* **Smart Data Entry:** Automatically captures birthdays when you honour someone.
* **Hidden Age Support:** Detects "Sand of Aeon" users and allows manual entry.
* **Watchlist:** Only get alerts for people you actually care about.
* **Passive Updates:** Updates date automatically at midnight (game time).
* **Safety First:** No background timers or gagging triggers that could interfere
  with combat.


INSTALLATION
------------
1.  Download the `BirthdayTracker.mpackage` file.
2.  Open Mudlet.
3.  Drag and drop the file into your main Mudlet window.
4.  The package will install automatically.


HOW TO USE
----------
1.  **Capture Data:**
    Type `honours <name>` (e.g., `honours Rivka`).
    You will see a green message confirming the birthday was captured.
    * *Note:* If their age is hidden, the script will prompt you to enter
        it manually if you know it.


2.  **Add to Watchlist:**
    Type `bday monitor <name>` (e.g., `bday monitor Rivka`).
    This tells the script to alert you when this person's birthday is near.


3.  **Check Status:**
    Type `bday list` (or `plist`) to see a summary of all monitored friends
    and how many days are left until their parties.


4.  **Date Sync:**
    The tracker updates automatically at midnight. If you just logged in,
    type `date` once to sync the tracker with the current game time.


COMMAND REFERENCE
-----------------
* `honours <name>`       - Captures birthday data (Case-insensitive).
* `bday monitor <name>`  - Adds a person to your alert list.
* `bday unmonitor <name>`- Removes a person from your alert list.
* `bday add <name> <day> <month>` 
                         - Manually set a birthday for someone with a hidden age.
* `bday list` / `plist`  - Shows the countdown for your monitored list.
* `bday help`            - Shows the in-game help menu.
* `bday debug`           - Diagnostics for date/tracker issues.


TROUBLESHOOTING
---------------
* **"I don't know the current date yet"**:
    The tracker needs to see the in-game date at least once. Type `date`
    in the game to initialize it.


* **"Her date of birth is hidden..."**:
    The script detected a hidden age. Use `bday add <name> <day> <month>`
    to record it manually. It will show as "(Age Hidden)" in your list.


* **Duplicate Tables in `bday list`**:
    If you see two tables, another script (like SVO) might be using the
    `bday` command. Use `plist` instead.]]
version = [[1]]
created = "2026-02-13T15:15:22-06:00"
