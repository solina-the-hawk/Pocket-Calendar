-- =========================================================================
-- POCKET CALENDAR CORE
-- Converts between Achaean and Real-World Dates
-- =========================================================================

PocketCalendar = PocketCalendar or {}
PocketCalendar.events = PocketCalendar.events or {}
PocketCalendar.gmtOffset = PocketCalendar.gmtOffset or 0 
PocketCalendar.currentDate = PocketCalendar.currentDate or { hour = 0, day = 1, month = "Sarapin", year = 0 }
PocketCalendar.birthdays = PocketCalendar.birthdays or {}
PocketCalendar.monitoredBirthdays = PocketCalendar.monitoredBirthdays or {}

-- USER CONFIGURABLE RGB COLORS
color_table.cal_main = {0, 153, 153}
color_table.cal_accent = {255, 215, 0}
color_table.cal_text = {200, 200, 200}
color_table.cal_warn = {255, 69, 0}

PocketCalendar.colors = {
    main = "<cal_main>",
    accent = "<cal_accent>",
    text = "<cal_text>",
    warn = "<cal_warn>"
}

PocketCalendar.monthMap = {
    ["Sarapin"] = 1, ["Daedalan"] = 2, ["Aeguary"] = 3,
    ["Miraman"] = 4, ["Scarlatan"] = 5, ["Ero"] = 6,
    ["Valnuary"] = 7, ["Lupar"] = 8, ["Phaestian"] = 9,
    ["Chronos"] = 10, ["Glacian"] = 11, ["Mayan"] = 12
}

PocketCalendar.monthList = {
    "Sarapin", "Daedalan", "Aeguary", "Miraman", "Scarlatan", "Ero",
    "Valnuary", "Lupar", "Phaestian", "Chronos", "Glacian", "Mayan"
}

-- =========================================================================
-- TIME MATHEMATICS
-- =========================================================================

function PocketCalendar:getAbsAchaeanHour(hour, day, month, year)
    local monthNum = self.monthMap[month] or 1
    local absDays = (year * 300) + ((monthNum - 1) * 25) + (day - 1)
    return (absDays * 24) + (hour or 0)
end

function PocketCalendar:absHourToAchaean(absHour)
    local absDays = math.floor(absHour / 24)
    local tHour = absHour % 24
    
    local tYear = math.floor(absDays / 300)
    local remainder = absDays % 300
    local tMonthNum = math.floor(remainder / 25) + 1
    local tDay = (remainder % 25) + 1
    
    return { hour = tHour, day = tDay, month = self.monthList[tMonthNum], year = tYear }
end

-- =========================================================================
-- CONVERSIONS & LOOKUPS
-- =========================================================================

function PocketCalendar:AchaeanToReal(targetDay, targetMonth, targetYear, targetHour)
    if self.currentDate.year == 0 then return nil end

    local currentAbs = self:getAbsAchaeanHour(self.currentDate.hour, self.currentDate.day, self.currentDate.month, self.currentDate.year)
    local targetAbs = self:getAbsAchaeanHour(targetHour or 0, targetDay, targetMonth, targetYear)

    local diffGameHours = targetAbs - currentAbs
    local realSecondsDiff = diffGameHours * 150

    return os.time() + realSecondsDiff
end

function PocketCalendar:RealToAchaean(targetUnixTime)
    if self.currentDate.year == 0 then return nil end

    local currentUnix = os.time()
    local diffSeconds = targetUnixTime - currentUnix
    local diffGameHours = math.floor(diffSeconds / 150)

    local currentAbs = self:getAbsAchaeanHour(self.currentDate.hour, self.currentDate.day, self.currentDate.month, self.currentDate.year)
    local targetAbs = currentAbs + diffGameHours

    return self:absHourToAchaean(targetAbs)
end

function PocketCalendar:lookupRealTimestamp(year, month, day, hour, min, sec, timeType)
    local uncorrectedUnixTime = os.time({
        year = tonumber(year), month = tonumber(month), day = tonumber(day), 
        hour = tonumber(hour), min = tonumber(min), sec = tonumber(sec)
    })
    
    local targetUnixTime = uncorrectedUnixTime
    if timeType == "gmt" then
        targetUnixTime = uncorrectedUnixTime + (self.gmtOffset * 3600)
    end
    
    local achaeanDate = self:RealToAchaean(targetUnixTime)
    if not achaeanDate then
        cecho(string.format("\n%s[Pocket Calendar]:%s %sI don't know the current date yet. Type 'DATE'.%s\n", self.colors.main, "<reset>", self.colors.warn, "<reset>"))
        return
    end

    local typeStr = (timeType == "gmt") and "GMT " or "Local "

    cecho(string.format("\n%s[Pocket Calendar]:%s %sThe %stimestamp %s%04d/%02d/%02d %02d:%02d:%02d%s translates to %s%s %d, %d%s in Achaea.\n",
        self.colors.main, "<reset>", self.colors.text, typeStr, self.colors.accent, 
        year, month, day, hour, min, sec, self.colors.text, self.colors.accent, 
        achaeanDate.month, achaeanDate.day, achaeanDate.year, "<reset>"))
end

function PocketCalendar:lookupAchaean(day, month, year)
    local realUnixTime = self:AchaeanToReal(day, month, year)
    if not realUnixTime then return end
    
    local diff = realUnixTime - os.time()
    if diff < 0 then
        cecho(string.format("\n%s[Pocket Calendar]:%s %sThat date is in the past!%s\n", self.colors.main, "<reset>", self.colors.warn, "<reset>"))
        return
    end
    
    local daysLeft = math.floor(diff / 86400)
    local hoursLeft = math.floor((diff % 86400) / 3600)
    local minsLeft = math.floor((diff % 3600) / 60)
    
    cecho(string.format("\n%s[Pocket Calendar]:%s %s%s %d, %d%s is in %s%dd %dh %dm%s (Real Time: %s%s%s)\n",
        self.colors.main, "<reset>", self.colors.accent, month, day, year, self.colors.text,
        self.colors.accent, daysLeft, hoursLeft, minsLeft, self.colors.text, 
        self.colors.accent, os.date("%c", realUnixTime), "<reset>"))
end

function PocketCalendar:lookupReal(amount, unit)
    local amountNum = tonumber(amount)
    if not amountNum then return end

    local multiplier = 1
    unit = unit:lower()
    if unit:match("hour") then multiplier = 3600
    elseif unit:match("day") then multiplier = 86400
    elseif unit:match("week") then multiplier = 604800
    elseif unit:match("min") then multiplier = 60
    else
        cecho(string.format("\n%s[Pocket Calendar]:%s %sInvalid time unit. Use mins, hours, days, or weeks.%s\n", self.colors.main, "<reset>", self.colors.warn, "<reset>"))
        return
    end

    local targetUnixTime = os.time() + (amountNum * multiplier)
    local achaeanDate = self:RealToAchaean(targetUnixTime)

    if not achaeanDate then
        cecho(string.format("\n%s[Pocket Calendar]:%s %sI don't know the current date yet. Type 'DATE'.%s\n", self.colors.main, "<reset>", self.colors.warn, "<reset>"))
        return
    end

    cecho(string.format("\n%s[Pocket Calendar]:%s %sIn %d %s, the Achaean date will be %s%s %d, %d%s (Real Time: %s%s%s)\n",
        self.colors.main, "<reset>", self.colors.text, amountNum, unit,
        self.colors.accent, achaeanDate.month, achaeanDate.day, achaeanDate.year, self.colors.text,
        self.colors.accent, os.date("%c", targetUnixTime), "<reset>"))
end

-- =========================================================================
-- EVENT ADDITION & MANAGEMENT
-- =========================================================================

function PocketCalendar:addAchaeanEvent(eventName, day, month, year)
    local realUnixTime = self:AchaeanToReal(day, month, year)
    if not realUnixTime then return end
    
    table.insert(self.events, {
        name = eventName,
        achaean = {day = day, month = month, year = year},
        realTime = realUnixTime,
        warn = false
    })
    
    cecho(string.format("\n%s[Pocket Calendar]:%s %sAdded event %s'%s'%s for %s%s %d, %d%s.\n", 
        self.colors.main, "<reset>", self.colors.text, self.colors.accent, eventName, self.colors.text, 
        self.colors.accent, month, day, year, "<reset>"))
    self:save()
end

function PocketCalendar:addRealRelativeEvent(eventName, amount, unit)
    local amountNum = tonumber(amount)
    if not amountNum then return end

    local multiplier = 1
    unit = unit:lower()
    
    if unit:match("hour") then multiplier = 3600
    elseif unit:match("day") then multiplier = 86400
    elseif unit:match("week") then multiplier = 604800
    elseif unit:match("min") then multiplier = 60
    else
        cecho(string.format("\n%s[Pocket Calendar]:%s %sInvalid time unit. Use mins, hours, days, or weeks.%s\n", self.colors.main, "<reset>", self.colors.warn, "<reset>"))
        return
    end

    local targetUnixTime = os.time() + (amountNum * multiplier)
    local achaeanDate = self:RealToAchaean(targetUnixTime)

    if not achaeanDate then
        cecho(string.format("\n%s[Pocket Calendar]:%s %sI don't know the current date yet. Type 'DATE'.%s\n", self.colors.main, "<reset>", self.colors.warn, "<reset>"))
        return
    end

    table.insert(self.events, {
        name = eventName,
        achaean = achaeanDate,
        realTime = targetUnixTime,
        warn = false
    })

    cecho(string.format("\n%s[Pocket Calendar]:%s %sAdded event %s'%s'%s for %s%s %d, %d%s.\n", 
        self.colors.main, "<reset>", self.colors.text, self.colors.accent, eventName, self.colors.text, 
        self.colors.accent, achaeanDate.month, achaeanDate.day, achaeanDate.year, "<reset>"))
    self:save()
end

function PocketCalendar:addRealTimestampEvent(eventName, year, month, day, hour, min, sec, timeType)
    local uncorrectedUnixTime = os.time({
        year = tonumber(year), month = tonumber(month), day = tonumber(day), 
        hour = tonumber(hour), min = tonumber(min), sec = tonumber(sec)
    })
    
    local targetUnixTime = uncorrectedUnixTime
    if timeType == "gmt" then
        targetUnixTime = uncorrectedUnixTime + (self.gmtOffset * 3600)
    end
    
    local achaeanDate = self:RealToAchaean(targetUnixTime)
    if not achaeanDate then
        cecho(string.format("\n%s[Pocket Calendar]:%s %sI don't know the current date yet. Type 'DATE'.%s\n", self.colors.main, "<reset>", self.colors.warn, "<reset>"))
        return
    end

    table.insert(self.events, {
        name = eventName,
        achaean = achaeanDate,
        realTime = targetUnixTime,
        warn = false
    })

    cecho(string.format("\n%s[Pocket Calendar]:%s %sImported event %s'%s'%s for %s%s %d, %d%s.\n", 
        self.colors.main, "<reset>", self.colors.text, self.colors.accent, eventName, self.colors.text, 
        self.colors.accent, achaeanDate.month, achaeanDate.day, achaeanDate.year, "<reset>"))
    self:save()
end

function PocketCalendar:removeEvent(searchTerm)
    if #self.events == 0 then
        cecho(string.format("\n%s[Pocket Calendar]:%s %sNo events to remove.%s\n", self.colors.main, "<reset>", self.colors.text, "<reset>"))
        return
    end

    searchTerm = searchTerm:lower()
    local removedCount = 0
    
    for i = #self.events, 1, -1 do
        if self.events[i].name:lower():find(searchTerm, 1, true) then
            cecho(string.format("\n%s[Pocket Calendar]:%s %sRemoved event: %s%s%s\n", 
                self.colors.main, "<reset>", self.colors.text, self.colors.accent, self.events[i].name, "<reset>"))
            table.remove(self.events, i)
            removedCount = removedCount + 1
        end
    end
    
    if removedCount > 0 then
        self:save()
    else
        cecho(string.format("\n%s[Pocket Calendar]:%s %sNo event found matching '%s'.%s\n", self.colors.main, "<reset>", self.colors.text, searchTerm, "<reset>"))
    end
end

function PocketCalendar:toggleWarning(searchTerm)
    if #self.events == 0 then return end
    
    searchTerm = searchTerm:lower()
    local found = false
    
    for _, event in ipairs(self.events) do
        if event.name:lower():find(searchTerm, 1, true) then
            event.warn = not event.warn
            found = true
            local state = event.warn and "<green>ON<reset>" or "<red>OFF<reset>"
            cecho(string.format("\n%s[Pocket Calendar]:%s %sWarnings for '%s%s%s' are now %s.\n", 
                self.colors.main, "<reset>", self.colors.text, self.colors.accent, event.name, self.colors.text, state))
        end
    end
    
    if found then self:save() else cecho(string.format("\n%s[Pocket Calendar]:%s %sNo event found matching '%s'.%s\n", self.colors.main, "<reset>", self.colors.text, searchTerm, "<reset>")) end
end

function PocketCalendar:checkWarnings()
    local currentTime = os.time()
    for _, event in ipairs(self.events) do
        if event.warn and event.realTime > currentTime then
            local diff = event.realTime - currentTime
            
            if diff <= 3600 then
                local minsLeft = math.floor(diff / 60)
                cecho(string.format("\n%s[CALENDAR WARNING]:%s %s%s%s is coming up in %s%d real minutes%s!\n", 
                    self.colors.warn, "<reset>", self.colors.text, event.name, self.colors.text, self.colors.accent, minsLeft, "<reset>"))
            end
        end
    end
end

function PocketCalendar:setTimezone(offset)
    local numOffset = tonumber(offset)
    if not numOffset then return end
    
    self.gmtOffset = numOffset
    self:save()
    
    cecho(string.format("\n%s[Pocket Calendar]:%s %sGMT Offset set to %s%s%s hours.\n", 
        self.colors.main, "<reset>", self.colors.text, self.colors.accent, numOffset, "<reset>"))
end

-- =========================================================================
-- DISPLAY & HELP
-- =========================================================================

function PocketCalendar:listEvents()
    if self.currentDate.year == 0 then
        cecho(string.format("\n%s[Pocket Calendar]:%s %sI don't know the current Achaean date yet. Type 'DATE'.%s\n", self.colors.main, "<reset>", self.colors.warn, "<reset>"))
        return
    end

    local currentTime = os.time()
    local validEvents = {}
    local combinedEvents = {}
    
    for _, event in ipairs(self.events) do
        if event.realTime > currentTime then
            table.insert(validEvents, event)
            table.insert(combinedEvents, event)
        end
    end
    
    self.events = validEvents
    self:save()

    local currentAbs = self:getAbsAchaeanHour(self.currentDate.hour, self.currentDate.day, self.currentDate.month, self.currentDate.year)
    
    for name, bday in pairs(self.birthdays) do
        if table.contains(self.monitoredBirthdays, name) then
            local bdayAbs = self:getAbsAchaeanHour(0, bday.day, bday.month, self.currentDate.year)
            local achaeanHoursLeft = bdayAbs - currentAbs
            
            local targetYear = self.currentDate.year
            if achaeanHoursLeft < 0 then 
                achaeanHoursLeft = achaeanHoursLeft + (300 * 24) 
                targetYear = targetYear + 1
            end
            
            local realSecondsLeft = achaeanHoursLeft * 150
            
            table.insert(combinedEvents, {
                name = name .. "'s Birthday",
                realTime = currentTime + realSecondsLeft,
                achaean = { day = bday.day, month = bday.month, year = targetYear },
                warn = false,
                isBday = true
            })
        end
    end

    if #combinedEvents == 0 then
        cecho(string.format("\n%s[Pocket Calendar]:%s %sNo upcoming events or monitored birthdays.%s\n", self.colors.main, "<reset>", self.colors.text, "<reset>"))
        return
    end

    table.sort(combinedEvents, function(a, b) return a.realTime < b.realTime end)
    
    cecho(string.format("\n%s=======================================================================%s\n", self.colors.main, "<reset>"))
    cecho(string.format("%s                    U P C O M I N G   E V E N T S                      %s\n", self.colors.main, "<reset>"))
    cecho(string.format("%s=======================================================================%s\n\n", self.colors.main, "<reset>"))
    
    for _, event in ipairs(combinedEvents) do
        local diff = event.realTime - currentTime
        local daysLeft = math.floor(diff / 86400)
        local hoursLeft = math.floor((diff % 86400) / 3600)
        local minsLeft = math.floor((diff % 3600) / 60)
        
        local timeLeftStr = ""
        if daysLeft > 0 then
            timeLeftStr = string.format("%dd %dh %dm", daysLeft, hoursLeft, minsLeft)
        elseif hoursLeft > 0 then
            timeLeftStr = string.format("%dh %dm", hoursLeft, minsLeft)
        else
            timeLeftStr = string.format("%dm", minsLeft)
        end

        local warnStr = "   "
        if event.isBday then
            warnStr = string.format("%s[B]%s", self.colors.accent, "<reset>")
        elseif event.warn then
            warnStr = string.format("%s[W]%s", self.colors.warn, "<reset>")
        end

        cecho(string.format(" %s %s%-22s%s | %sIn %-10s%s | %s%s %d, %d%s\n", 
            warnStr,
            self.colors.accent, event.name, "<reset>",
            self.colors.main, timeLeftStr, "<reset>",
            self.colors.text, event.achaean.month, event.achaean.day, event.achaean.year, "<reset>"))
    end
    
    cecho(string.format("\n%s=======================================================================%s\n", self.colors.main, "<reset>"))
    cecho(string.format("%s                  Type %scal help%s %sfor a list of commands.                  %s\n", self.colors.text, self.colors.accent, self.colors.text, self.colors.text, "<reset>"))
end

function PocketCalendar:help()
    local m = self.colors.main
    local a = self.colors.accent
    local t = self.colors.text
    local r = "<reset>"

    cecho(string.format("\n%s=======================================================================%s\n", m, r))
    cecho(string.format("%s                 P O C K E T   C A L E N D A R   H E L P               %s\n", m, r))
    cecho(string.format("%s=======================================================================%s\n", m, r))
    
    cecho(string.format("\n%sPocket Calendar manages events and seamlessly converts Achaean in-game\n", t))
    cecho(string.format("dates to real-world time. Ensure you've typed DATE once this session!%s\n\n", r))

    cecho(string.format("%sAdding Events:%s\n", m, r))
    cecho(string.format("  %scal add achaea <name> <day> <month> <year>%s\n", a, r))
    cecho(string.format("  %scal add real <name> in <number> <hours/days/weeks>%s\n", a, r))
    cecho(string.format("  %scal upcoming <#>%s         - Imports an event from Achaea's UPCOMING list.%s\n\n", a, r, r))
    
    cecho(string.format("%sLookups (Does not save to list):%s\n", m, r))
    cecho(string.format("  %scal check achaea <day> <month> <year>%s\n", a, r))
    cecho(string.format("  %scal check real in <number> <mins/hours/days>%s\n", a, r))
    cecho(string.format("  %scal check real <gmt/local> <YYYY/MM/DD HH:MM:SS>%s\n\n", a, r))
    
    cecho(string.format("%sBirthday Tracking:%s\n", m, r))
    cecho(string.format("  %scal bday list%s          - Shows watched birthdays with countdowns.\n", a, r))
    cecho(string.format("  %scal bday monitor <name>%s- Adds a player to your birthday watchlist.\n", a, r))
    cecho(string.format("  %scal bday unmonitor <name>%s- Removes a player.\n", a, r))
    cecho(string.format("  %scal bday add <name> <d> <m>%s\n", a, r))
    cecho(string.format("  %scal bday clear%s         - Wipes your entire monitored watchlist.%s\n\n", a, r, r))
    
    cecho(string.format("%sManaging Events:%s\n", m, r))
    cecho(string.format("  %scal list%s             - Shows all upcoming events.\n", a, r))
    cecho(string.format("  %scal remove <name>%s    - Deletes an event (partial names work).\n", a, r))
    cecho(string.format("  %scal warn <name>%s      - Toggles 1-hour countdown warnings.\n\n", a, r))

    cecho(string.format("%sSystem Setup:%s\n", m, r))
    cecho(string.format("  %scal timezone <#>%s     - Sets your local hour offset from GMT.\n", a, r))
    cecho(string.format("  %sDATE%s                 - (Game Command) Syncs your current Achaean date.\n", a, r))
    cecho(string.format("%s=======================================================================%s\n", m, r))
end

-- =========================================================================
-- COMMAND DISPATCHER
-- =========================================================================

function PocketCalendar:handleCommand(input)
    if not input or input == "" or input:lower() == "list" then
        self:listEvents()
        return
    end

    if input:lower() == "help" then
        self:help()
        return
    end

    local aName, aDay, aMonth, aYear = input:match("^[Aa][Dd][Dd] [Aa][Cc][Hh][Aa][Ee][Aa]%s+(.+)%s+(%d+)%s+(%a+)%s+(%d+)$")
    if aName then
        self:addAchaeanEvent(aName, tonumber(aDay), aMonth:title(), tonumber(aYear))
        return
    end

    local rName, rAmt, rUnit = input:match("^[Aa][Dd][Dd] [Rr][Ee][Aa][Ll]%s+(.+)%s+in%s+(%d+)%s+(%a+)$")
    if rName then
        self:addRealRelativeEvent(rName, tonumber(rAmt), rUnit)
        return
    end
    
    local upID = input:match("^[Uu][Pp][Cc][Oo][Mm][Ii][Nn][Gg].-(%d+)%s*$")
    if upID then
        self.awaitingUpcoming = true
        self.tempUpcomingTitle = "Unknown Event"
        send("upcoming info " .. upID)

        if self.titleCatchTrigger then killTrigger(self.titleCatchTrigger) end
        self.titleCatchTrigger = tempRegexTrigger("^(.+)$", function()
            local txt = matches[2]
            if txt:match("^%-%-%-%-%-%-+") then
                killTrigger(PocketCalendar.titleCatchTrigger)
                PocketCalendar.titleCatchTrigger = nil
            elseif not txt:lower():match("^upcoming info") then
                PocketCalendar.tempUpcomingTitle = txt
            end
        end)
        return
    end

    local cDay, cMonth, cYear = input:match("^[Cc][Hh][Ee][Cc][Kk] [Aa][Cc][Hh][Aa][Ee][Aa]%s+(%d+)%s+(%a+)%s+(%d+)$")
    if cDay then
        self:lookupAchaean(tonumber(cDay), cMonth:title(), tonumber(cYear))
        return
    end

    local crAmt, crUnit = input:match("^[Cc][Hh][Ee][Cc][Kk] [Rr][Ee][Aa][Ll]%s+in%s+(%d+)%s+(%a+)$")
    if crAmt then
        self:lookupReal(tonumber(crAmt), crUnit)
        return
    end

    local bName, bDay, bMonth = input:match("^[Bb][Dd][Aa][Yy] [Aa][Dd][Dd]%s+(%w+)%s+(%d+)%s+(%a+)$")
    if bName then
        self:addBirthday(bName, bDay, bMonth, true) 
        return
    end

    local bMonName = input:match("^[Bb][Dd][Aa][Yy] [Mm][Oo][Nn][Ii][Tt][Oo][Rr]%s+(%w+)$")
    if bMonName then
        self:monitorBirthday(bMonName)
        return
    end

    local bUnmonName = input:match("^[Bb][Dd][Aa][Yy] [Uu][Nn][Mm][Oo][Nn][Ii][Tt][Oo][Rr]%s+(%w+)$")
    if bUnmonName then
        self:unmonitorBirthday(bUnmonName)
        return
    end

    if input:lower() == "bday list" then
        self:listBirthdays(false)
        return
    end
    
    if input:lower() == "bday others" then
        self:listBirthdays(true)
        return
    end

    if input:lower() == "bday clear" then
        self:clearMonitoredBirthdays()
        return
    end

    local tType, tYear, tMonth, tDay, tHour, tMin, tSec = input:match("^[Cc][Hh][Ee][Cc][Kk] [Rr][Ee][Aa][Ll]%s+(%w+)%s+(%d%d%d%d)/(%d%d)/(%d%d)%s+(%d%d):(%d%d):(%d%d)$")
    if tType and (tType:lower() == "gmt" or tType:lower() == "local") then
        self:lookupRealTimestamp(tYear, tMonth, tDay, tHour, tMin, tSec, tType:lower())
        return
    end
    
    local remName = input:match("^[Rr][Ee][Mm][Oo][Vv][Ee]%s+(.+)$")
    if remName then
        self:removeEvent(remName)
        return
    end

    local tzOffset = input:match("^[Tt][Ii][Mm][Ee][Zz][Oo][Nn][Ee]%s+([%+%-%d%.]+)$")
    if tzOffset then
        self:setTimezone(tzOffset)
        return
    end

    local warnName = input:match("^[Ww][Aa][Rr][Nn]%s+(.+)$")
    if warnName then
        self:toggleWarning(warnName)
        return
    end

    cecho(string.format("\n%s[Pocket Calendar]:%s %sCommand syntax not recognized. Type %scal help%s %sfor options.%s\n", 
        self.colors.main, "<reset>", self.colors.warn, self.colors.accent, "<reset>", self.colors.warn, "<reset>"))
end

-- =========================================================================
-- GMCP SYNC & SAVING
-- =========================================================================

function PocketCalendar:onStatusChange()
    if not gmcp or not gmcp.Char or not gmcp.Char.Status then return end
    if gmcp.Char.Status.day then
        self.currentDate.day = tonumber(gmcp.Char.Status.day)
        self.currentDate.month = gmcp.Char.Status.month
        self.currentDate.year = tonumber(gmcp.Char.Status.year)
    end
end

if PocketCalendar.eventHandlerID then killAnonymousEventHandler(PocketCalendar.eventHandlerID) end
PocketCalendar.eventHandlerID = registerAnonymousEventHandler("gmcp.Char.Status", "PocketCalendar:onStatusChange")

function PocketCalendar:save()
    local path = getMudletHomeDir() .. "/pocketcalendar_data.lua"
    table.save(path, {
        events = self.events, 
        gmtOffset = self.gmtOffset,
        birthdays = self.birthdays,
        monitoredBirthdays = self.monitoredBirthdays
    })
end

function PocketCalendar:load()
    local path = getMudletHomeDir() .. "/pocketcalendar_data.lua"
    if io.exists(path) then
        local content = {}
        table.load(path, content)
        self.events = content.events or {}
        self.gmtOffset = content.gmtOffset or 0
        self.birthdays = content.birthdays or {}
        self.monitoredBirthdays = content.monitoredBirthdays or {}
    end
end

-- =========================================================================
-- BIRTHDAY TRACKER MODULE
-- =========================================================================

function PocketCalendar:addBirthday(name, day, month, autoMonitor)
    name = name:title()
    month = month:title()
    
    if not self.monthMap[month] then
        cecho(string.format("\n%s[Pocket Calendar]:%s %sInvalid month: %s. Use full Achaean names.%s\n", self.colors.main, "<reset>", self.colors.warn, month, "<reset>"))
        return
    end
    
    self.birthdays[name] = { day = tonumber(day), month = month }
    
    if autoMonitor and not table.contains(self.monitoredBirthdays, name) then
        table.insert(self.monitoredBirthdays, name)
    end
    
    self:save()
    
    if autoMonitor then
        cecho(string.format("\n%s[Pocket Calendar]:%s %sSaved and monitored %s%s's%s birthday as %s%s %d%s.\n", 
            self.colors.main, "<reset>", self.colors.text, self.colors.accent, name, self.colors.text,
            self.colors.accent, month, day, "<reset>"))
    else
        cecho(string.format("\n%s[Pocket Calendar]:%s %sSilently logged %s%s's%s birthday as %s%s %d%s.\n", 
            self.colors.main, "<reset>", self.colors.text, self.colors.accent, name, self.colors.text,
            self.colors.accent, month, day, "<reset>"))
    end
end

function PocketCalendar:monitorBirthday(name)
    name = name:title()
    if not table.contains(self.monitoredBirthdays, name) then
        table.insert(self.monitoredBirthdays, name)
        self:save()
        cecho(string.format("\n%s[Pocket Calendar]:%s %sAdded %s%s%s to your birthday watchlist.\n", self.colors.main, "<reset>", self.colors.text, self.colors.accent, name, "<reset>"))
    else
        cecho(string.format("\n%s[Pocket Calendar]:%s %s%s is already on the watchlist.%s\n", self.colors.main, "<reset>", self.colors.text, name, "<reset>"))
    end
end

function PocketCalendar:unmonitorBirthday(name)
    name = name:title()
    if table.contains(self.monitoredBirthdays, name) then
        for i, v in ipairs(self.monitoredBirthdays) do
            if v == name then table.remove(self.monitoredBirthdays, i) break end
        end
        self:save()
        cecho(string.format("\n%s[Pocket Calendar]:%s %sRemoved %s%s%s from the watchlist.\n", self.colors.main, "<reset>", self.colors.text, self.colors.accent, name, "<reset>"))
    else
        cecho(string.format("\n%s[Pocket Calendar]:%s %s%s was not on the watchlist.%s\n", self.colors.main, "<reset>", self.colors.text, name, "<reset>"))
    end
end

function PocketCalendar:clearMonitoredBirthdays()
    local count = #self.monitoredBirthdays
    self.monitoredBirthdays = {}
    self:save()
    cecho(string.format("\n%s[Pocket Calendar]:%s %sCleared %s%d%s monitored birthdays from your watchlist. (Known birthdays were kept).%s\n", 
        self.colors.main, "<reset>", self.colors.text, self.colors.accent, count, self.colors.text, "<reset>"))
end

function PocketCalendar:listBirthdays(showAll)
    if self.currentDate.year == 0 then
        cecho(string.format("\n%s[Pocket Calendar]:%s %sI don't know the current date yet. Type 'DATE'.%s\n", self.colors.main, "<reset>", self.colors.warn, "<reset>"))
        return
    end

    local currentAbs = self:getAbsAchaeanHour(self.currentDate.hour, self.currentDate.day, self.currentDate.month, self.currentDate.year)
    local sortedList = {}
    local otherCount = 0

    for name, bday in pairs(self.birthdays) do
        local isMonitored = table.contains(self.monitoredBirthdays, name)
        local bdayAbs = self:getAbsAchaeanHour(0, bday.day, bday.month, self.currentDate.year)
        local achaeanHoursLeft = bdayAbs - currentAbs
        
        if achaeanHoursLeft < 0 then achaeanHoursLeft = achaeanHoursLeft + (300 * 24) end
        
        local realSecondsLeft = achaeanHoursLeft * 150

        if showAll or isMonitored then
            table.insert(sortedList, { name = name, realSecondsLeft = realSecondsLeft, month = bday.month, day = bday.day, monitored = isMonitored })
        elseif not isMonitored then
            if realSecondsLeft <= (168 * 3600) then otherCount = otherCount + 1 end
        end
    end

    if #sortedList == 0 then
        cecho(string.format("\n%s[Pocket Calendar]:%s %sNo birthdays on your watchlist.%s\n", self.colors.main, "<reset>", self.colors.text, "<reset>"))
        return
    end

    table.sort(sortedList, function(a, b) return a.realSecondsLeft < b.realSecondsLeft end)

    local title = showAll and "A L L   K N O W N   B I R T H D A Y S" or "U P C O M I N G   B I R T H D A Y S"
    cecho(string.format("\n%s=======================================================================%s\n", self.colors.main, "<reset>"))
    cecho(string.format("%s                  %s                   %s\n", self.colors.main, title, "<reset>"))
    cecho(string.format("%s=======================================================================%s\n\n", self.colors.main, "<reset>"))

    for _, person in ipairs(sortedList) do
        local realDays = math.floor(person.realSecondsLeft / 86400)
        local realHours = math.floor((person.realSecondsLeft % 86400) / 3600)
        local realMins = math.floor((person.realSecondsLeft % 3600) / 60)
        
        local timeLeftStr = ""
        if realDays > 0 then 
            timeLeftStr = string.format("%dd %dh %dm", realDays, realHours, realMins)
        elseif realHours > 0 then 
            timeLeftStr = string.format("%dh %dm", realHours, realMins) 
        else
            timeLeftStr = string.format("%dm", realMins)
        end

        local nameColor = person.monitored and self.colors.accent or self.colors.text

        cecho(string.format("   %s%-18s%s | %sIn %-10s%s | %s%s %d%s\n", 
            nameColor, person.name, "<reset>",
            self.colors.main, timeLeftStr, "<reset>",
            self.colors.text, person.month, person.day, "<reset>"))
    end

    cecho(string.format("\n%s=======================================================================%s\n", self.colors.main, "<reset>"))
    
    if not showAll and otherCount > 0 then
        cecho(string.format("%s  There are %s%d%s other known birthdays coming up in the next 7 days.%s\n", 
            self.colors.text, self.colors.accent, otherCount, self.colors.text, "<reset>"))
        cecho(string.format("%s  Type %scal bday others%s to view them.%s\n", self.colors.text, self.colors.accent, self.colors.text, "<reset>"))
    end
end

PocketCalendar:load()

-- =========================================================================
-- GMCP TIME SYNC
-- =========================================================================

function PocketCalendar:onTimeChange(event)
    local timeData = nil
    if event == "gmcp.IRE.Time.List" then
        timeData = gmcp.IRE.Time.List
    elseif event == "gmcp.IRE.Time.Update" then
        timeData = gmcp.IRE.Time.Update
    end
    
    if not timeData then return end
    
    local updated = false
    
    if timeData.hour then
        self.currentDate.hour = tonumber(timeData.hour)
        updated = true
    end
    if timeData.day then
        self.currentDate.day = tonumber(timeData.day)
        updated = true
    end
    if timeData.month then
        self.currentDate.month = timeData.month
        updated = true
    end
    if timeData.year then
        self.currentDate.year = tonumber(timeData.year)
        updated = true
    end
    
    if updated then
        self:save()
    end
end

-- =========================================================================
-- INITIALIZATION & DYNAMIC TRIGGERS
-- =========================================================================

function PocketCalendar:init()
    if self.calAlias then killAlias(self.calAlias) end
    if self.honoursAlias then killAlias(self.honoursAlias) end
    if self.birthdayTrigger then killTrigger(self.birthdayTrigger) end
    if self.dateTrigger then killTrigger(self.dateTrigger) end
    if self.upcomingTrigger then killTrigger(self.upcomingTrigger) end
    if self.timeListHandler then killAnonymousEventHandler(self.timeListHandler) end
    if self.timeUpdateHandler then killAnonymousEventHandler(self.timeUpdateHandler) end

    self.calAlias = tempAlias("^(?i)cal(?:\\s+(.*))?$", function()
        local input = matches[2] or ""
        PocketCalendar:handleCommand(input)
    end)

    self.honoursAlias = tempAlias("^(?i)honours (\\w+)$", function()
        PocketCalendar.currentLookup = matches[2]:title()
        send(matches[1])
    end)

    self.birthdayTrigger = tempRegexTrigger("^.*born on the (\\d+)(?:st|nd|rd|th) of (\\w+), (\\d+)", function()
        if PocketCalendar.currentLookup then
            local bDay = matches[2]
            local bMonth = matches[3]
            PocketCalendar:addBirthday(PocketCalendar.currentLookup, bDay, bMonth, false)
            PocketCalendar.currentLookup = nil
        end
    end)

    self.dateTrigger = tempRegexTrigger("^Today is the (\\d+)(?:st|nd|rd|th) of (\\w+), (\\d+) years after", function()
        PocketCalendar.currentDate.day = tonumber(matches[2])
        PocketCalendar.currentDate.month = matches[3]
        PocketCalendar.currentDate.year = tonumber(matches[4])
        PocketCalendar:save()
        cecho(string.format("\n%s[Pocket Calendar]:%s %sDate synchronized! It is now %s%s %d, %d%s.\n", 
            PocketCalendar.colors.main, "<reset>", PocketCalendar.colors.text, 
            PocketCalendar.colors.accent, PocketCalendar.currentDate.month, PocketCalendar.currentDate.day, PocketCalendar.currentDate.year, "<reset>"))
    end)

    self.upcomingTrigger = tempRegexTrigger([[GMT Time:[^0-9]*(\d+)/(\d+)/(\d+)[^0-9]*(\d+):(\d+):(\d+)]], function()
        if PocketCalendar.awaitingUpcoming then
            PocketCalendar.awaitingUpcoming = false
            local eventName = PocketCalendar.tempUpcomingTitle or "Unknown Event"
            eventName = string.gsub(eventName, "^[%s\128-\255]*(.-)[%s\128-\255]*$", "%1") 
            local tYear, tMonth, tDay = matches[2], matches[3], matches[4]
            local tHour, tMin, tSec = matches[5], matches[6], matches[7]
            PocketCalendar:addRealTimestampEvent(eventName, tYear, tMonth, tDay, tHour, tMin, tSec, "gmt")
        end
    end)

    self.timeListHandler = registerAnonymousEventHandler("gmcp.IRE.Time.List", "PocketCalendar:onTimeChange")
    self.timeUpdateHandler = registerAnonymousEventHandler("gmcp.IRE.Time.Update", "PocketCalendar:onTimeChange")
    
    sendGMCP([[Core.Supports.Add ["IRE.Time 1"] ]])

    cecho(string.format("\n%s[Pocket Calendar]:%s %sFully Initialized. Type %scal help%s %sfor options.%s\n", 
        self.colors.main, "<reset>", self.colors.text, self.colors.accent, self.colors.text, self.colors.text, "<reset>"))
end

PocketCalendar:init()