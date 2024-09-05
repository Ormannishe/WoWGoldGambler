function WoWGoldGambler:setRecords = function()
    -- Performs first-time setup for records, records overall records, and records game-mode specific records
    if (self.db.global.stats.records.OVERALL == nil) then
        self.db.global.stats.records.OVERALL = {}
    end

    self:gamesPlayedRecord("OVERALL")
    self:biggestWagerRecord("OVERALL")
    self:biggestWinRecord("OVERALL")

    -- Game mode specific records
    if (self.db.global.stats.records[self.db.global.game.mode] == nil) then
        self.db.global.stats.records[self.db.global.game.mode] = {}
    end

    self:gamesPlayedRecord(self.db.global.game.mode)

    if (WoWGoldGambler[self.db.global.game.mode].setRecords ~= nil) then
        WoWGoldGambler[self.db.global.game.mode].setRecords(WoWGoldGambler)
    end
end

-- Implementation for generic records --

function WoWGoldGambler:gamesPlayedRecord(category)
    if (self.db.global.stats.records[category]["Games Played"] == nil) then
        self.db.global.stats.records[category]["Games Played"] = {
            record = 1
        }
    else
        self.db.global.stats.records[category]["Games Played"].record = self.db.global.stats.records[category]["Games Played"].record + 1
    end
end

function WoWGoldGambler:biggestWagerRecord(category)
    if (self.db.global.stats.records[category]["Biggest Wager"] == nil or
        self.db.global.game.wager > self.db.global.stats.records[category]["Biggest Wager"].record) then

        self.db.global.stats.records[category]["Biggest Wager"] = {
            record = self.db.global.game.wager,
            holders = self:makeNameString(self.session.players)
        }

        ChatMessage("New Record! " .. self:formatInt(self.db.global.game.wager) .. "g is the most money I've ever seen wagered!")
    end
end

function WoWGoldGambler:biggestWinRecord(category)
    local amountWon = ((self.session.result.amountOwed * #self.session.result.losers) / #self.session.result.winners)

    if (self.db.global.stats.records[category]["Biggest Win"] == nil or
        amountWon > self.db.global.stats.records[category]["Biggest Win"].record) then

        self.db.global.stats.records[category]["Biggest Win"] = {
            record = amountWon,
            holders = self:makeNameString(self.session.result.winners)
        }

        ChatMessage("New Record! " .. self:formatInt(self.session.result.amountOwed) .. "g is the most money I've ever seen won in a single wager!")
    end
end

function WoWGoldGambler:mostRoundsRecord()
    -- TODO: Test this
    local category = self.db.global.game.mode

    if (self.session.modeData.roundNumber != nil) then
        if (self.db.global.stats.records[category]["Most Rounds"] == nil or
            self.session.modeData.roundNumber > self.db.global.stats.records[category]["Most Rounds"].record) then

            self.db.global.stats.records[category]["Most Rounds"] = {
                record = self.session.modeData.roundNumber,
                holders = self:makeNameString(self.session.players) -- Record holders should be just the players involved in the final round
            }

            ChatMessage("New Record! That was the longest" .. self:capitalize(category) .. " game I've ever seen, lasting " .. self.session.modeData.roundNumber .. " rounds!")
        end
    end
end