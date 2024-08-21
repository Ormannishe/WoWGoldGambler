-- Roulette Game Mode --

function WoWGoldGambler:rouletteGameStart()
    SendChatMessage("WoWGoldGambler: A new game has been started! Type a number between 1 and 36 to join! (-1 to withdraw)" , self.db.global.game.chatChannel)
end

function WoWGoldGambler:rouletteRegister(text, playerName, playerRealm)
    -- Registration for the Roulette game mode
    text = tonumber(text)

    if (text ~= nil and text > 0 and text < 37) then
        self:registerPlayer(playerName, playerRealm, text)
    elseif (text == -1) then
        self:unregisterPlayer(playerName, playerRealm)
    end
end

function WoWGoldGambler:rouletteStartRolls()
    -- Informs players that the registration phase has ended. Performs a /roll 36 to determine the winning number
    SendChatMessage("Registration has ended. Spinning the wheel...", self.db.global.game.chatChannel)
    self:rollMe(36)
end

function WoWGoldGambler:rouletteRecordRoll(playerName, actualRoll, minRoll, maxRoll)
    -- If the dealer performed a /roll 36, record it as the result of the roulette round
    if (self.session.dealer.name == playerName and self.session.modeData.rouletteResult == nil and tonumber(minRoll) == 1 and tonumber(maxRoll) == 36) then
        self.session.modeData.rouletteResult = tonumber(actualRoll)
        SendChatMessage("The ball has landed on " .. actualRoll .. "!", self.db.global.game.chatChannel)
    end
end

function WoWGoldGambler:rouletteCalculateResult()
    -- Calculation logic for the Roulette game mode. Ties are permitted.
    -- Winner: Anyone who registered with the winning number
    -- Loser: Anyone who did not choose the winning number. If there are no winners, there are no losers.
    -- Payment Amount: The wager amount (evenly distributed to all winners)
    local winners = {}
    local losers = {}
    local amountOwed = nil

    for i = 1, #self.session.players do
        if (self.session.players[i].roll == self.session.modeData.rouletteResult) then
            tinsert(winners, self.session.players[i])
        else
            tinsert(losers, self.session.players[i])
        end
    end

    if (#winners > 0) then
        amountOwed = math.floor(self.db.global.game.wager / #winners)
    end

    return {
        winners = winners,
        losers = losers,
        amountOwed = amountOwed
    }
end
