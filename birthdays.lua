BirthdayTracker = BirthdayTracker or {}
BirthdayTracker.data = BirthdayTracker.data or {}
BirthdayTracker.monitored = BirthdayTracker.monitored or {}
BirthdayTracker.currentDate = BirthdayTracker.currentDate or { day = 1, month = "Sarapin", year = 0 }

BirthdayTracker.monthMap = {
    ["Sarapin"] = 1, ["Daedalan"] = 2, ["Aeguary"] = 3,
    ["Miraman"] = 4, ["Scarlatan"] = 5, ["Ero"] = 6,
    ["Valnuary"] = 7, ["Lupar"] = 8, ["Phaestian"] = 9,
    ["Chronos"] = 10, ["Glacian"] = 11, ["Mayan"] = 12
}

-- Converts Date to Absolute Day
function BirthdayTracker:toAbsDay(day, monthName)
    local monthNum = self.monthMap[monthName] or 1
    return ((monthNum - 1) * 25) + day
end

-- Add a player to the watchlist
function BirthdayTracker:monitor(name)
    name = name:title()
    if not table.contains(self.monitored, name) then
        table.insert(self.monitored, name)
        self:save()
        cecho(string.format("\n<green>[BIRTHDAY]: Added %s to the watchlist.<reset>", name))
    else
        cecho(string.format("\n<yellow>[BIRTHDAY]: %s is already on the watchlist.<reset>", name))
    end
end

-- Remove a player from the watchlist
function BirthdayTracker:unmonitor(name)
    name = name:title()
    if table.contains(self.monitored, name) then
        for i, v in ipairs(self.monitored) do
            if v == name then table.remove(self.monitored, i) break end
        end
        self:save()
        cecho(string.format("\n<red>[BIRTHDAY]: Removed %s from the watchlist.<reset>", name))
    else
        cecho(string.format("\n<yellow>[BIRTHDAY]: %s was not on the watchlist.<reset>", name))
    end
end

-- Manually inject a birthday (for Sand of Aeon users)
function BirthdayTracker:manualAdd(name, day, month)
    name = name:title()
    month = month:title()
    
    if not self.monthMap[month] then
        cecho("\n<red>Invalid month: " .. month .. ". Use full Achaean names.<reset>")
        return
    end
    
    -- Year 0 indicates age is unknown/hidden
    self.data[name] = { day = tonumber(day), month = month, year = 0 }
    
    -- Automatically add to watchlist if not already there
    if not table.contains(self.monitored, name) then
        table.insert(self.monitored, name)
    end
    self:save()
    cecho(string.format("\n<green>[BIRTHDAY]: Manually set %s's birthday to %s %d.<reset>", name, month, day))
end

-- Core Logic
function BirthdayTracker:checkUpcoming(verbose)
    if not self.currentDate.year or self.currentDate.year == 0 then
        cecho("<red>I don't know the current date yet. Type 'date'.<reset>\n")
        return
    end

    local currentAbs = self:toAbsDay(self.currentDate.day, self.currentDate.month)
    
    if verbose then
        cecho("\n")  
        cecho("\n<gold>--- Birthday Watchlist ---<reset>\n") 
        cecho(string.format("<grey>Date: %s %d, %d<reset>\n", self.currentDate.month, self.currentDate.day, self.currentDate.year))
    end

    local isMonitored = {}
    for _, n in pairs(self.monitored) do isMonitored[n] = true end

    -- Display Watchlist
    local sortableWatchlist = {}
    
    for _, name in pairs(self.monitored) do
        local bday = self.data[name]
        if bday then
            local bdayAbs = self:toAbsDay(bday.day, bday.month)
            local daysLeft = 0
            
            if bdayAbs >= currentAbs then daysLeft = bdayAbs - currentAbs
            else daysLeft = (300 - currentAbs) + bdayAbs end
            
            -- NEW: Real Time Calculation (1 Game Day = 1 Real Hour)
            local realTimeStr = ""
            if daysLeft < 24 then
                realTimeStr = string.format("<grey>(%d hrs)<reset>", daysLeft)
            else
                local realDays = daysLeft / 24
                realTimeStr = string.format("<grey>(%.1f days)<reset>", realDays)
            end

            -- Add to our temporary sorting table
            table.insert(sortableWatchlist, {
                name = name, 
                days = daysLeft, 
                month = bday.month, 
                day = bday.day, 
                realTime = realTimeStr -- Storing real time instead of age
            })
        elseif verbose then
             cecho(string.format("<grey>%-12s: [No data - try 'honours %s']<reset>\n", name, name))
        end
    end

    if verbose then cecho("<gold>--------------------------<reset>\n") end

    table.sort(sortableWatchlist, function(a, b) return a.days < b.days end)

    for _, person in ipairs(sortableWatchlist) do
        if verbose or person.days <= 25 then
            local color = "<white>"
            if person.days <= 10 then color = "<red>"
            elseif person.days <= 25 then color = "<yellow>"
            end
            
            -- Updated print format
            cecho(string.format("%s%-12s: %3d days (%s %d) %s<reset>\n", 
                color, person.name, person.days, person.month, person.day, person.realTime))
        end
    end

    -- Calculate "Others"
    local limit = 168
    local otherCount = 0
    for name, bday in pairs(self.data) do
        if not isMonitored[name] then
            local bdayAbs = self:toAbsDay(bday.day, bday.month)
            local daysLeft = 0
            if bdayAbs >= currentAbs then daysLeft = bdayAbs - currentAbs
            else daysLeft = (300 - currentAbs) + bdayAbs end
            
            if daysLeft <= limit then otherCount = otherCount + 1 end
        end
    end

    if verbose and otherCount > 0 then
        cecho("\n<grey>There are " .. otherCount .. " other known birthdays in the next 7 real days.<reset>\n")
        cechoLink("<green>[Click here to view them]<reset>\n", [[BirthdayTracker:showOthers()]], "View other birthdays", true)
        cecho("\n")
    end
end

function BirthdayTracker:showOthers()
    local currentAbs = self:toAbsDay(self.currentDate.day, self.currentDate.month)
    local limit = 168
    local sortedList = {}
    local isMonitored = {}
    for _, n in pairs(self.monitored) do isMonitored[n] = true end

    for name, bday in pairs(self.data) do
        if not isMonitored[name] then
            local bdayAbs = self:toAbsDay(bday.day, bday.month)
            local daysLeft = 0
            if bdayAbs >= currentAbs then daysLeft = bdayAbs - currentAbs
            else daysLeft = (300 - currentAbs) + bdayAbs end
            
            if daysLeft <= limit then
                table.insert(sortedList, {name=name, days=daysLeft, month=bday.month, day=bday.day, year=bday.year})
            end
        end
    end

    table.sort(sortedList, function(a,b) return a.days < b.days end)

    cecho("\n<gold>--- Other Upcoming Birthdays ---<reset>\n")
    for _, v in ipairs(sortedList) do
        local color = "<grey>"
        if v.days <= 25 then color = "<white>" end
        
        -- NEW: Real Time Calculation for "Others" list too
        local realTimeStr = ""
        if v.days < 24 then
            realTimeStr = string.format("<grey>(%d hrs)<reset>", v.days)
        else
            local realDays = v.days / 24
            realTimeStr = string.format("<grey>(%.1f days)<reset>", realDays)
        end

        cecho(string.format("%s%-12s: %3d days (%s %d) %s<reset>\n", color, v.name, v.days, v.month, v.day, realTimeStr))
    end
    cecho("<gold>--------------------------------<reset>\n")
end

-- Help Function
function BirthdayTracker:help()
    cecho("\n<gold>-----------------------------------------------------------<reset>\n")
    cecho("<white>          Solina's Birthday Tracker Help (v1.3)<reset>\n")
    cecho("<gold>-----------------------------------------------------------<reset>\n")
    cecho("<green>Data Collection:<reset>\n")
    cecho("  <yellow>honours <name><reset>      - Captures a player's birthday automatically.\n")
    cecho("                        (Must use this alias, not just 'honours')\n")
    cecho("  <yellow>bday add <name> <day> <month><reset>\n")
    cecho("                      - Manually set a birthday (for hidden ages).\n")
    cecho("                        (e.g. bday add Solina 7 Valnuary)\n")
    
    cecho("\n<green>Management:<reset>\n")
    cecho("  <yellow>bday monitor <name><reset> - Add a player to your watchlist.\n")
    cecho("  <yellow>bday unmonitor <name><reset> - Remove a player from your watchlist.\n")
    cecho("  <yellow>bday list<reset>           - Show all watched birthdays.\n")
    
    cecho("\n<green>System & Diagnostics:<reset>\n")
    cecho("  <yellow>bday date<reset>           - View the date currently stored in the tracker.\n")
    cecho("  <yellow>date<reset>                - (Game Command) Forces Achaea to send the correct date.\n")
    cecho("  <yellow>bday debug<reset>          - Show nerd stuff (for troubleshooting).\n")
    cecho("<gold>-----------------------------------------------------------<reset>\n")
end

-- GMCP Handler
function BirthdayTracker:onStatusChange()
    if not gmcp or not gmcp.Char or not gmcp.Char.Status then return end
    if gmcp.Char.Status.day then
        local newDay = tonumber(gmcp.Char.Status.day)
        if newDay ~= self.currentDate.day then
            self.currentDate.day = newDay
            self.currentDate.month = gmcp.Char.Status.month
            self.currentDate.year = tonumber(gmcp.Char.Status.year)
        end
    end
end
if BirthdayTracker.eventHandlerID then killAnonymousEventHandler(BirthdayTracker.eventHandlerID) end
BirthdayTracker.eventHandlerID = registerAnonymousEventHandler("gmcp.Char.Status", "BirthdayTracker:onStatusChange")

-- Save/Load
function BirthdayTracker:save()
    local path = getMudletHomeDir() .. "/birthday_data.lua"
    table.save(path, {data = self.data, monitored = self.monitored})
end
function BirthdayTracker:load()
    local path = getMudletHomeDir() .. "/birthday_data.lua"
    if io.exists(path) then
        local content = {}
        table.load(path, content)
        self.data = content.data or {}
        self.monitored = content.monitored or {}
    end
end

-- Init
BirthdayTracker:load()
cecho("\n<green>[Solina's Birthday Tracker]: v1.3 Loaded.<reset>\n")