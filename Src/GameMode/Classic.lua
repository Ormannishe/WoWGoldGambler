-- Classic Game Mode --
WoWGoldGambler.CLASSIC = {}

-- Default Game Start
WoWGoldGambler.CLASSIC.gameStart = WoWGoldGambler.DEFAULT.gameStart

-- Default Registration
WoWGoldGambler.CLASSIC.register = WoWGoldGambler.DEFAULT.register

-- Default Roll Start
WoWGoldGambler.CLASSIC.startRolls = WoWGoldGambler.DEFAULT.startRolls

WoWGoldGambler.CLASSIC.recordRoll = function(self, playerName, actualRoll, minRoll, maxRoll)
    -- If a registered player made the wager roll and has not yet rolled, record the roll
    if (tonumber(minRoll) == 1 and tonumber(maxRoll) == self.db.global.game.wager) then
        for i = 1, #self.session.players do
            if (self.session.players[i].name == playerName and self.session.players[i].roll == nil) then
                self.session.players[i].roll = tonumber(actualRoll)
            end
        end
    end
end

WoWGoldGambler.CLASSIC.calculateResult = function(self)
    -- Calculation logic for the Classic game mode. A tie-breaker round will resolve ties.
    -- Winner: The player(s) with the highest roll
    -- Loser: The player(s) with the lowest roll
    -- Payment Amount: The difference between the losing and winning rolls
    local winners = {self.session.players[1]}
    local losers = {self.session.players[1]}
    local amountOwed = 0

    for i = 2, #self.session.players do
        -- New loser
        if (self.session.players[i].roll < losers[1].roll) then
            losers = {self.session.players[i]}
        -- New winner
        elseif (self.session.players[i].roll > winners[1].roll) then
            winners = {self.session.players[i]}
        else
            -- Handle ties. Due to the way we initialize the winners/losers, it's possible for both of these to be true
            if (self.session.players[i].roll == losers[1].roll) then
                tinsert(losers, self.session.players[i])
            end

            if (self.session.players[i].roll == winners[1].roll) then
                tinsert(winners, self.session.players[i])
            end
        end
    end

    -- In a scenario where all players tie, it's possible to run in to this edge case. Void out the losers so the round can end in a draw.
    if (winners[1].name == losers[1].name) then
        losers = {}
    else
        amountOwed = winners[1].roll - losers[1].roll
    end

    return {
        winners = winners,
        losers = losers,
        amountOwed = amountOwed
    }
end

WoWGoldGambler.CLASSIC.detectTie = function(self)
    -- Output a message to the chat channel informing players of a tie (and which end the tie is on)
    if (#self.session.result.winners > 1) then
        self:ChatMessage("High end tie breaker! " .. self:makeNameString(self.session.players) .. " /roll " .. self.db.global.game.wager .. " now!")
    elseif (#self.session.result.losers > 1) then
        self:ChatMessage("Low end tie breaker! " .. self:makeNameString(self.session.players) .. " /roll " .. self.db.global.game.wager .. " now!")
    end
end

WoWGoldGambler.CLASSIC.setRecords = function(self)
    -- Updates records for the Classic game mode and reports when records are broken
    self:luckiestRollRecord()
    self:unluckiestRollRecord()
end

-- Game-mode specific records

function WoWGoldGambler:luckiestRollRecord()
    if (self.session.result.winners ~= nil and #self.session.result.winners > 0) then
        local currentPercentile
        local percentile = (self.db.global.game.wager - self.session.result.winners[1].roll + 1) / self.db.global.game.wager * 100
    
        if (self.db.global.stats.records.CLASSIC["Luckiest Roll"] == nil) then
            currentPercentile = 100
        else
            currentPercentile = self.db.global.stats.records.CLASSIC["Luckiest Roll"].recordData
        end
    
        if (percentile < currentPercentile) then
            local formatted_percentile = self:formatFloat(percentile)
    
            self.db.global.stats.records.CLASSIC["Luckiest Roll"] = {
                record = "Top " .. tostring(formatted_percentile) .. " percentile win",
                holders = self:makeNameString(self.session.result.winners),
                recordData = percentile
            }
    
            self:NewRecordMessage("New Record! That was the luckiest Classic roll I've ever seen! That roll was in the top " .. formatted_percentile .. "% of possible rolls!")
        end
    end
end

function WoWGoldGambler:unluckiestRollRecord()
    if (self.session.result.losers ~= nil and #self.session.result.losers > 0) then
        local currentPercentile
        local percentile = self.session.result.losers[1].roll / self.db.global.game.wager * 100
    
        if (self.db.global.stats.records.CLASSIC["Unluckiest Roll"] == nil) then
            currentPercentile = 100
        else
            currentPercentile = self.db.global.stats.records.CLASSIC["Unluckiest Roll"].recordData
        end
    
        if (percentile < currentPercentile) then
            local formatted_percentile = self:formatFloat(percentile)
    
            self.db.global.stats.records.CLASSIC["Unluckiest Roll"] = {
                record = "Bottom " .. tostring(formatted_percentile) .. " percentile loss",
                holders = self:makeNameString(self.session.result.losers),
                recordData = percentile
            }
    
            self:NewRecordMessage("New Record! That was the unluckiest Classic roll I've ever seen! That roll was in the bottom " .. formatted_percentile .. "% of possible rolls!")
        end
    end
end