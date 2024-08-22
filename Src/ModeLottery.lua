-- Lottery Game Mode --
WoWGoldGambler.LOTTERY = {}

-- Default Game Start
WoWGoldGambler.LOTTERY.gameStart = WoWGoldGambler.DEFAULT.gameStart

-- Default Registration
WoWGoldGambler.LOTTERY.register = WoWGoldGambler.DEFAULT.register

WoWGoldGambler.LOTTERY.startRolls = function(self)
    -- Informs players that the registration phase has ended. Performs a /roll for the number of players to determine the winner
    SendChatMessage("Registration has ended. Drawing the winning ticket...", self.db.global.game.chatChannel)
    self:rollMe(#self.session.players)
end

WoWGoldGambler.LOTTERY.recordRoll = function(self, playerName, actualRoll, minRoll, maxRoll)
    -- If the dealer performed a /roll for the number of players, record it as the result of the lottery round
    if (self.session.dealer.name == playerName and self.session.modeData.lotteryResult == nil and tonumber(minRoll) == 1 and tonumber(maxRoll) == #self.session.players) then
        local winnerIndex = tonumber(actualRoll)

        self.session.modeData.lotteryResult = winnerIndex

        SendChatMessage("The winning ticket is " .. actualRoll .. "! Congratulations " .. self.session.players[winnerIndex].name .. "!", self.db.global.game.chatChannel)
    
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

-- Default Tie Resolution
WoWGoldGambler.LOTTERY.detectTie = WoWGoldGambler.DEFAULT.detectTie