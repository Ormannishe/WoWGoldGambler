-- Lottery Game Mode --
WoWGoldGambler.LOTTERY = {}

-- Default Game Start
WoWGoldGambler.LOTTERY.gameStart = WoWGoldGambler.DEFAULT.gameStart

-- Default Registration
WoWGoldGambler.LOTTERY.register = WoWGoldGambler.DEFAULT.register

WoWGoldGambler.LOTTERY.startRolls = function(self)
    -- Informs players that the registration phase has ended. Performs a /roll for the number of players to determine the winner
    self:ChatMessage("Registration has ended. Drawing the winning ticket...")
    self:rollMe(#self.session.players)
end

WoWGoldGambler.LOTTERY.recordRoll = function(self, playerName, actualRoll, minRoll, maxRoll)
    -- If the dealer performed a /roll for the number of players, record it as the result of the lottery round
    if (self.session.dealer.name == playerName and self.session.modeData.lotteryResult == nil and tonumber(minRoll) == 1 and tonumber(maxRoll) == #self.session.players) then
        local winnerIndex = tonumber(actualRoll)

        self.session.modeData.lotteryResult = winnerIndex

        self:ChatMessage("The winning ticket is " .. actualRoll .. "! Congratulations " .. self.session.players[winnerIndex].name .. "!")
    
        -- Since all players must have a recorded roll for the game to end, simply give players a default roll
        for i = 1, #self.session.players do
            self.session.players[i].roll = i
        end
    end
end

WoWGoldGambler.LOTTERY.calculateResult = function(self)
    -- Calculation logic for the Lottery game mode. Ties are permitted.
    -- Winner: The player who's number was drawn
    -- Loser: ALL players who did not have their number drawn
    -- Payment Amount: The wager amount
    local winners = {}
    local losers = {}

    for i = 1, #self.session.players do
        if (i == self.session.modeData.lotteryResult) then
            tinsert(winners, self.session.players[i])
        else
            tinsert(losers, self.session.players[i])
        end
    end

    return {
        winners = winners,
        losers = losers,
        amountOwed = self.db.global.game.wager
    }
end

WoWGoldGambler.LOTTERY.setRecords = function(self)
    -- Updates records for the Lottery game mode
    self:luckiestLotteryNumber()
end

-- Game-mode specific records

function WoWGoldGambler:luckiestLotteryNumber()
    local counts
    local luckiestNumber
    local winningNumber = self.session.modeData.lotteryResult

    if (self.db.global.stats.records.LOTTERY["Luckiest Number"] == nil) then
        counts = {}
    else
        counts = self.db.global.stats.records.LOTTERY["Luckiest Number"].recordData
        luckiestNumber = counts.luckiestNumber
    end

    if (counts[winningNumber] == nil) then
        counts[winningNumber] = 1
    else
        counts[winningNumber] = counts[winningNumber] + 1
    end

    if (luckiestNumber == nil or counts[winningNumber] > counts[luckiestNumber]) then
        counts.luckiestNumber = winningNumber
    end

    self.db.global.stats.records.LOTTERY["Luckiest Number"] = {
        record = counts.luckiestNumber .. " (drawn " .. self:formatInt(counts[counts.luckiestNumber]) .. " times)",
        recordData = counts
    }
end