-- =========================================================================
-- POCKET CALENDAR CORE
-- Converts between Achaean and Real-World Dates
-- =========================================================================

PocketCalendar = PocketCalendar or {}
PocketCalendar.events = PocketCalendar.events or {}
PocketCalendar.birthdays = PocketCalendar.birthdays or {}
PocketCalendar.monitoredBirthdays = PocketCalendar.monitoredBirthdays or {}
PocketCalendar.dateQueue = PocketCalendar.dateQueue or {}
PocketCalendar.clockDrift = PocketCalendar.clockDrift or 0 
PocketCalendar.currentDate = PocketCalendar.currentDate or { hour = 0, day = 1, month = "Sarapin", year = 0 }

-- =========================================================================
-- DEBUG MODE
-- =========================================================================
PocketCalendar.debugMode = PocketCalendar.debugMode or false -- Disabled by default

function PocketCalendar:debug(msg)
    if self.debugMode then
        cecho(string.format("\n<yellow>[CAL DEBUG]:<reset> %s\n", tostring(msg)))
    end
end

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
-- TIME MATHEMATICS & SERVER SYNC
-- =========================================================================

function PocketCalendar:getAbsAchaeanHour(hour, day, month, year)
    local monthNum = self.monthMap[month] or 1
    local absDays = (year * 300) + ((monthNum - 1) * 25) + (day - 1)
    return (absDays * 24) + (hour or 0)
end

function PocketCalendar:parseLocalToEpoch(y, m, d, h, min, s)
    self:debug(string.format("Converting Local to Epoch: %d/%d/%d %d:%d:%d", y, m, d, h, min, s))
    -- Directly trusts the computer's OS time since Achaea is giving us Local Time
    return os.time({year=y, month=m, day=d, hour=h, min=min, sec=s})
end

function PocketCalendar:parseGmtToEpoch(y, m, d, h, min, s)
    self:debug(string.format("Converting GMT to Epoch: %d/%d/%d %d:%d:%d", y, m, d, h, min, s))
    
    local t = os.time({year=y, month=m, day=d, hour=h, min=min, sec=s})
    local l = os.date("*t", t)
    local u = os.date("!*t", t)
    
    local offset = (l.hour - u.hour) * 3600 + (l.min - u.min) * 60
    if l.year > u.year then offset = offset + 86400
    elseif l.year < u.year then offset = offset - 86400
    elseif l.yday > u.yday then offset = offset + 86400
    elseif l.yday < u.yday then offset = offset - 86400 end
    
    local finalTime = t + offset
    self:debug("Calculated True Epoch: " .. finalTime)
    return finalTime
end

function PocketCalendar:getServerTime()
    return os.time() + self.clockDrift
end

function PocketCalendar:syncServerTime()
    self:debug("Syncing server time...")
    self.syncingTime = true
    send("TIME", false)
end

-- =========================================================================
-- ASYNC ACHAEA SERVER DATE RESOLUTION ENGINE
-- =========================================================================

function PocketCalendar:queueDateCmd(cmd, payload)
    table.insert(self.dateQueue, payload)
    self:debug("Queueing DATE command: '" .. cmd .. "' | Queue Length: " .. #self.dateQueue)
    send(cmd, false)
end

function PocketCalendar:processAchaeaToReal(matches, payload)
    self:debug("Executing processAchaeaToReal payload action: " .. tostring(payload.action))
    local aDay, aMonth, aYear = tonumber(matches[1]), matches[2]:title(), tonumber(matches[3])
    
    local rMonth, rDay, rYear = tonumber(matches[4]), tonumber(matches[5]), tonumber(matches[6])
    local rHour = tonumber(matches[7])
    local rMin = tonumber(matches[8]) or 0
    
    local realUnixTime = self:parseGmtToEpoch(rYear, rMonth, rDay, rHour, rMin, 0)
    
    if payload.action == "add_event" then
        self:debug("Adding event to events array: " .. payload.name)
        table.insert(self.events, {
            name = payload.name,
            achaean = {day = aDay, month = aMonth, year = aYear},
            realTime = realUnixTime,
            warn = false
        })
        cecho(string.format("\n%s[Pocket Calendar]:%s %sAdded event %s'%s'%s for %s%s %d, %d%s.\n", 
            self.colors.main, "<reset>", self.colors.text, self.colors.accent, payload.name, self.colors.text, 
            self.colors.accent, aMonth, aDay, aYear, "<reset>"))
        self:save()
        
    elseif payload.action == "lookup" then
        local diff = realUnixTime - self:getServerTime()
        if diff < 0 then
            cecho(string.format("\n%s[Pocket Calendar]:%s %sThat date is in the past!%s\n", self.colors.main, "<reset>", self.colors.warn, "<reset>"))
            return
        end
        local daysLeft = math.floor(diff / 86400)
        local hoursLeft = math.floor((diff % 86400) / 3600)
        local minsLeft = math.floor((diff % 3600) / 60)
        cecho(string.format("\n%s[Pocket Calendar]:%s %s%s %d, %d%s is in %s%dd %dh %dm%s (Local Time: %s%s%s)\n",
            self.colors.main, "<reset>", self.colors.accent, aMonth, aDay, aYear, self.colors.text,
            self.colors.accent, daysLeft, hoursLeft, minsLeft, self.colors.text, 
            self.colors.accent, os.date("%c", realUnixTime - self.clockDrift), "<reset>"))
    end
end

function PocketCalendar:processRealToAchaea(matches, payload)
    self:debug("Executing processRealToAchaea payload action: " .. tostring(payload.action))

    local rMonth, rDay, rYear = tonumber(matches[1]), tonumber(matches[2]), tonumber(matches[3])
    local rHour = tonumber(matches[4])
    local rMin = tonumber(matches[5]) or 0
    local aDay, aMonth, aYear = tonumber(matches[6]), matches[7]:title(), tonumber(matches[8])

    if payload.action == "add_event" then
        self:debug("Adding event to events array: " .. payload.name)
        table.insert(self.events, {
            name = payload.name,
            achaean = {day = aDay, month = aMonth, year = aYear},
            realTime = payload.targetUnix,
            warn = false
        })
        cecho(string.format("\n%s[Pocket Calendar]:%s %sAdded event %s'%s'%s for %s%s %d, %d%s.\n", 
            self.colors.main, "<reset>", self.colors.text, self.colors.accent, payload.name, self.colors.text, 
            self.colors.accent, aMonth, aDay, aYear, "<reset>"))
        self:save()
        
    elseif payload.action == "lookup_relative" then
        cecho(string.format("\n%s[Pocket Calendar]:%s %sIn %d %s, the Achaean date will be %s%s %d, %d%s (Local Time: %s%s%s)\n",
            self.colors.main, "<reset>", self.colors.text, payload.amountNum, payload.unit,
            self.colors.accent, aMonth, aDay, aYear, self.colors.text,
            self.colors.accent, os.date("%c", payload.targetUnix - self.clockDrift), "<reset>"))
            
    elseif payload.action == "lookup_timestamp" then
        local typeStr = (payload.timeType == "gmt") and "GMT " or "Local "
        cecho(string.format("\n%s[Pocket Calendar]:%s %sThe %stimestamp %s%04d/%02d/%02d %02d:%02d:%02d%s translates to %s%s %d, %d%s in Achaea.\n",
            self.colors.main, "<reset>", self.colors.text, typeStr, self.colors.accent, 
            payload.orig.y, payload.orig.m, payload.orig.d, payload.orig.h, payload.orig.min, payload.orig.s, self.colors.text, self.colors.accent, 
            aMonth, aDay, aYear, "<reset>"))
    end
end

-- =========================================================================
-- EVENT ADDITION & MANAGEMENT
-- =========================================================================

function PocketCalendar:addAchaeanEvent(eventName, day, month, year)
    self:debug("addAchaeanEvent called for: " .. eventName)
    self:queueDateCmd(string.format("DATE %d %s %d", day, month, year), {
        type = "achaea_to_real",
        action = "add_event",
        name = eventName
    })
end

function PocketCalendar:addRealRelativeEvent(eventName, amount, unit)
    self:debug("addRealRelativeEvent called for: " .. eventName)
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

    local targetUnixTime = self:getServerTime() + (amountNum * multiplier)
    local dateStr = os.date("!%m/%d/%Y %H:%M", targetUnixTime)
    
    self:queueDateCmd("DATE " .. dateStr, {
        type = "real_to_achaea",
        action = "add_event",
        name = eventName,
        targetUnix = targetUnixTime
    })
end

function PocketCalendar:addRealTimestampEvent(eventName, year, month, day, hour, min, sec, timeType)
    local targetUnixTime
    if timeType == "gmt" then
        targetUnixTime = self:parseGmtToEpoch(year, month, day, hour, min, sec)
    else
        targetUnixTime = self:parseLocalToEpoch(year, month, day, hour, min, sec)
    end
    
    local dateStr = os.date("!%m/%d/%Y %H:%M", targetUnixTime)
    self:queueDateCmd("DATE " .. dateStr, {
        type = "real_to_achaea",
        action = "add_event",
        name = eventName,
        targetUnix = targetUnixTime
    })
end

function PocketCalendar:lookupAchaean(day, month, year)
    self:queueDateCmd(string.format("DATE %d %s %d", day, month, year), {
        type = "achaea_to_real",
        action = "lookup",
        achaean = {day = day, month = month, year = year}
    })
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
        cecho(string.format("\n%s[Pocket Calendar]:%s %sInvalid time unit.%s\n", self.colors.main, "<reset>", self.colors.warn, "<reset>"))
        return
    end

    local targetUnixTime = self:getServerTime() + (amountNum * multiplier)
    local dateStr = os.date("!%m/%d/%Y %H:%M", targetUnixTime)
    
    self:queueDateCmd("DATE " .. dateStr, {
        type = "real_to_achaea",
        action = "lookup_relative",
        targetUnix = targetUnixTime,
        amountNum = amountNum,
        unit = unit
    })
end

function PocketCalendar:lookupRealTimestamp(year, month, day, hour, min, sec, timeType)
    local targetUnixTime
    if timeType == "gmt" then
        targetUnixTime = self:parseGmtToEpoch(year, month, day, hour, min, sec)
    else
        targetUnixTime = self:parseLocalToEpoch(year, month, day, hour, min, sec)
    end
    
    local dateStr = os.date("!%m/%d/%Y %H:%M", targetUnixTime)
    self:queueDateCmd("DATE " .. dateStr, {
        type = "real_to_achaea",
        action = "lookup_timestamp",
        targetUnix = targetUnixTime,
        timeType = timeType,
        orig = {y=year, m=month, d=day, h=hour, min=min, s=sec}
    })
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
    local currentServerTime = self:getServerTime()
    for _, event in ipairs(self.events) do
        if event.warn and event.realTime > currentServerTime then
            local diff = event.realTime - currentServerTime
            
            if diff <= 3600 then
                local minsLeft = math.floor(diff / 60)
                cecho(string.format("\n%s[CALENDAR WARNING]:%s %s%s%s is coming up in %s%d real minutes%s!\n", 
                    self.colors.warn, "<reset>", self.colors.text, event.name, self.colors.text, self.colors.accent, minsLeft, "<reset>"))
            end
        end
    end
end

-- =========================================================================
-- DISPLAY & HELP
-- =========================================================================

function PocketCalendar:listEvents()
    if self.currentDate.year == 0 then
        cecho(string.format("\n%s[Pocket Calendar]:%s %sI don't know the current Achaean date yet. Gathering now...%s\n", self.colors.main, "<reset>", self.colors.warn, "<reset>"))
        self:syncServerTime()
        tempTimer(1, function() self:listEvents() end)
        return
    end

    local currentServerTime = self:getServerTime()
    local validEvents = {}
    local combinedEvents = {}
    
    for _, event in ipairs(self.events) do
        if event.realTime > currentServerTime then
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
                realTime = currentServerTime + realSecondsLeft,
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
    
    -- FORMAT THE HEADER
    local cDay = self.currentDate.day
    local cMonth = self.currentDate.month
    local cYear = self.currentDate.year
    -- Get local formatted time (adjusted by drift)
    local cLocalTime = os.date("%A, %B %d, %Y at %I:%M %p", currentServerTime - self.clockDrift)

    cecho(string.format("\n%s=======================================================================%s\n", self.colors.main, "<reset>"))
    cecho(string.format("%s                    U P C O M I N G   E V E N T S                      %s\n", self.colors.main, "<reset>"))
    cecho(string.format("%s=======================================================================%s\n", self.colors.main, "<reset>"))
    cecho(string.format(" %sCurrent Achaean Date:%s %s%s %d, %d%s\n", self.colors.text, "<reset>", self.colors.accent, cMonth, cDay, cYear, "<reset>"))
    cecho(string.format(" %sCurrent Local Time:%s   %s%s%s\n", self.colors.text, "<reset>", self.colors.accent, cLocalTime, "<reset>"))
    cecho(string.format("%s-----------------------------------------------------------------------%s\n\n", self.colors.main, "<reset>"))
    
    for _, event in ipairs(combinedEvents) do
        local diff = event.realTime - currentServerTime
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
    cecho(string.format("dates to server-synced Real-World GMT automatically.%s\n\n", r))

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
    cecho(string.format("  %scal sync%s             - Manually resync clock with Achaea server.\n", a, r))
    cecho(string.format("  %scal debug%s            - Toggles developer debug messages.\n", a, r))
    cecho(string.format("%s=======================================================================%s\n", m, r))
end

-- =========================================================================
-- COMMAND DISPATCHER
-- =========================================================================

function PocketCalendar:handleCommand(input)
    self:debug("Dispatcher received input: '" .. tostring(input) .. "'")

    if not input or input == "" or input:lower() == "list" then
        self:debug("Routing to listEvents()")
        self:listEvents()
        return
    end

    if input:lower() == "help" then
        self:help()
        return
    end
    
    if input:lower() == "sync" then
        self:syncServerTime()
        return
    end
    
    if input:lower() == "debug" then
        self.debugMode = not self.debugMode
        cecho(string.format("\n%s[Pocket Calendar]:%s %sDebug mode is now %s%s%s.\n", 
            self.colors.main, "<reset>", self.colors.text, 
            self.colors.accent, self.debugMode and "ON" or "OFF", "<reset>"))
        return
    end

    local aName, aDay, aMonth, aYear = input:match("^[Aa][Dd][Dd] [Aa][Cc][Hh][Aa][Ee][Aa]%s+(.+)%s+(%d+)%s+(%a+)%s+(%d+)$")
    if aName then
        self:debug("Matched Add Achaea: Name="..aName.." Date="..aDay.." "..aMonth.." "..aYear)
        self:addAchaeanEvent(aName, tonumber(aDay), aMonth:title(), tonumber(aYear))
        return
    end

    local rName, rAmt, rUnit = input:match("^[Aa][Dd][Dd] [Rr][Ee][Aa][Ll]%s+(.+)%s+in%s+(%d+)%s+(%a+)$")
    if rName then
        self:debug("Matched Add Real Relative: Name="..rName.." Amt="..rAmt.." Unit="..rUnit)
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

    local warnName = input:match("^[Ww][Aa][Rr][Nn]%s+(.+)$")
    if warnName then
        self:toggleWarning(warnName)
        return
    end

    self:debug("No regex match found in dispatcher. Outputting syntax warning.")
    cecho(string.format("\n%s[Pocket Calendar]:%s %sCommand syntax not recognized. Type %scal help%s %sfor options.%s\n", 
        self.colors.main, "<reset>", self.colors.warn, self.colors.accent, "<reset>", self.colors.warn, "<reset>"))
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
        cecho(string.format("\n%s[Pocket Calendar]:%s %sI don't know the current date yet. Gathering now...%s\n", self.colors.main, "<reset>", self.colors.warn, "<reset>"))
        self:syncServerTime()
        tempTimer(1, function() self:listBirthdays(showAll) end)
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
        events = self.events, birthdays = self.birthdays,
        monitoredBirthdays = self.monitoredBirthdays, clockDrift = self.clockDrift
    })
    self:debug("Data saved to disk.")
end

function PocketCalendar:load()
    local path = getMudletHomeDir() .. "/pocketcalendar_data.lua"
    if io.exists(path) then
        local content = {}
        table.load(path, content)
        self.events = content.events or {}
        self.birthdays = content.birthdays or {}
        self.monitoredBirthdays = content.monitoredBirthdays or {}
        self.clockDrift = content.clockDrift or 0
        self:debug("Data loaded from disk. Events count: " .. #self.events)
    end
end

PocketCalendar:load()

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
    
    if updated then self:save() end
end

-- =========================================================================
-- INITIALIZATION & DYNAMIC TRIGGERS
-- =========================================================================

function PocketCalendar:init()
    self:debug("Initializing PocketCalendar...")
    
    -- FORCE QUEUE WIPE ON INITIALIZATION
    self.dateQueue = {}
    self:debug("Event Queue wiped clean.")
    
    if self.calAlias then killAlias(self.calAlias) end
    if self.honoursAlias then killAlias(self.honoursAlias) end
    if self.birthdayTrigger then killTrigger(self.birthdayTrigger) end
    if self.achaeaDateTrigger then killTrigger(self.achaeaDateTrigger) end
    if self.realDateTrigger then killTrigger(self.realDateTrigger) end
    if self.timeSyncTrigger then killTrigger(self.timeSyncTrigger) end
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

    -- Updated Trigger: Matches configured timezone string explicitly
    self.timeSyncTrigger = tempRegexTrigger([[In your world, it is \d+/\d+/\d+ \d+:\d+:\d+ GMT and (\d+)/(\d+)/(\d+) (\d+):(\d+):(\d+) in your configured timezone]], function()
        if PocketCalendar.syncingTime then
            deleteLine()
            PocketCalendar.syncingTime = false
            
            local sYear, sMonth, sDay = tonumber(matches[2]), tonumber(matches[3]), tonumber(matches[4])
            local sHour, sMin, sSec = tonumber(matches[5]), tonumber(matches[6]), tonumber(matches[7])
            
            local serverEpoch = PocketCalendar:parseLocalToEpoch(sYear, sMonth, sDay, sHour, sMin, sSec)
            PocketCalendar.clockDrift = serverEpoch - os.time()
            PocketCalendar:save()
            cecho(string.format("\n%s[Pocket Calendar]:%s %sClock successfully synchronized with Achaea's local time.%s\n", PocketCalendar.colors.main, "<reset>", PocketCalendar.colors.text, "<reset>"))
        end
    end)

    -- Reverted to match UPCOMING INFO's explicit GMT output
    self.upcomingTrigger = tempRegexTrigger([[GMT Time:.*?(\d+)/(\d+)/(\d+).*?(\d+):(\d+):(\d+)]], function()
        if PocketCalendar.awaitingUpcoming then
            PocketCalendar.awaitingUpcoming = false
            local eventName = PocketCalendar.tempUpcomingTitle or "Unknown Event"
            eventName = string.gsub(eventName, "^[%s\128-\255]*(.-)[%s\128-\255]*$", "%1") 
            local tYear, tMonth, tDay = tonumber(matches[2]), tonumber(matches[3]), tonumber(matches[4])
            local tHour, tMin, tSec = tonumber(matches[5]), tonumber(matches[6]), tonumber(matches[7])
            PocketCalendar:debug("UPCOMING Trigger fired! Event: " .. eventName)
            -- Achaea's UPCOMING info uses GMT, so we flag it as 'gmt' here
            PocketCalendar:addRealTimestampEvent(eventName, tYear, tMonth, tDay, tHour, tMin, tSec, "gmt")
        end
    end)

    -- Matches: Achaean date 5 Glacian, year 1004 at midnight would be 5/15/2026 at 23:00
    self.achaeaDateTrigger = tempRegexTrigger([[(?i)^Achaean date\s+(\d+)\s+([A-Za-z]+),\s+year\s+(\d+).*?would be\s+(\d+)/(\d+)/(\d+)\s+(?:at\s+)?(\d+):(\d+)]], function()
        PocketCalendar:debug("ACHAEA DATE TRIGGER FIRED! Match 1: " .. tostring(matches[1]))
        
        local targetIdx = nil
        for i, payload in ipairs(PocketCalendar.dateQueue) do
            if payload.type == "achaea_to_real" then
                targetIdx = i
                break
            end
        end
        
        if targetIdx then
            PocketCalendar:debug("Queue match found! Removing payload from queue index: " .. targetIdx)
            deleteLine() 
            local payload = table.remove(PocketCalendar.dateQueue, targetIdx)
            
            -- passMatches: aDay, aMonth, aYear, rMonth, rDay, rYear, rHour, rMin
            local passMatches = {matches[2], matches[3], matches[4], matches[5], matches[6], matches[7], matches[8], matches[9]}
            PocketCalendar:debug("Passing match data: " .. table.concat(passMatches, " | "))
            PocketCalendar:processAchaeaToReal(passMatches, payload)
        else
            PocketCalendar:debug("Trigger fired, but no matching payload type found in queue.")
        end
    end)

    -- Matches: Real world 05/15/2026 at 23:30 hours would be 5th of Glacian, year 1004
    self.realDateTrigger = tempRegexTrigger([[(?i)^Real world\s+(\d+)/(\d+)/(\d+)\s+(?:at\s+)?(\d+):(\d+).*?would be\s+(\d+)(?:st|nd|rd|th)?(?:\s+of)?\s+([A-Za-z]+),\s+year\s+(\d+)]], function()
        PocketCalendar:debug("REAL DATE TRIGGER FIRED! Match 1: " .. tostring(matches[1]))
        
        local targetIdx = nil
        for i, payload in ipairs(PocketCalendar.dateQueue) do
            if payload.type == "real_to_achaea" then
                targetIdx = i
                break
            end
        end
        
        if targetIdx then
            PocketCalendar:debug("Queue match found! Removing payload from queue index: " .. targetIdx)
            deleteLine() 
            local payload = table.remove(PocketCalendar.dateQueue, targetIdx)
            
            -- passMatches: rMonth, rDay, rYear, rHour, rMin, aDay, aMonth, aYear
            local passMatches = {matches[2], matches[3], matches[4], matches[5], matches[6], matches[7], matches[8], matches[9]}
            PocketCalendar:debug("Passing match data: " .. table.concat(passMatches, " | "))
            PocketCalendar:processRealToAchaea(passMatches, payload)
        else
            PocketCalendar:debug("Trigger fired, but no matching payload type found in queue.")
        end
    end)

    self.timeListHandler = registerAnonymousEventHandler("gmcp.IRE.Time.List", "PocketCalendar:onTimeChange")
    self.timeUpdateHandler = registerAnonymousEventHandler("gmcp.IRE.Time.Update", "PocketCalendar:onTimeChange")
    
    sendGMCP([[Core.Supports.Add ["IRE.Time 1"] ]])
    
    self:syncServerTime()
    self:debug("Initialization Complete.")
end

PocketCalendar:init()