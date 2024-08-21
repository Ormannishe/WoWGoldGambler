-- 1v1 Death Roll Game Mode --

function WoWGoldGambler:deathRollGameStart()
    SendChatMessage("WoWGoldGambler: A new 1v1 Death Roll game has been started! The first two players to type 1 will 1v1 roll to the death! (-1 to withdraw)" , self.db.global.game.chatChannel)
    self.session.modeData.currentRoll = self.db.global.game.wager
end

function WoWGoldGambler:deathRollRegister(text, playerName, playerRealm)
    -- Same as regular registration, but capped at only two players
    if (text == "1" and #self.session.players < 2) then
        self:registerPlayer(playerName, playerRealm)
    elseif (text == "1" and #self.session.players == 2) then
        if (playerName ~= self.session.players[1].name and playerName ~= self.session.players[2].name) then
            SendChatMessage("Sorry " .. playerName .. ", both spots have already been claimed! Maybe next time!" , self.db.global.game.chatChannel)
        end
    elseif (text == "-1") then
        local playerOne = self.session.players[1]
        local playerTwo = self.session.players[2]

        if ((playerOne ~= nil and playerName == playerOne.name) or (playerTwo ~= nil and playerName == playerTwo.name)) then
            self:unregisterPlayer(playerName, playerRealm)
            SendChatMessage(playerName .. " has backed out! Will anyone else claim their spot?" , self.db.global.game.chatChannel)
        end
    end
end

function WoWGoldGambler:deathRollStartRolls()
    -- Informs players that the registration phase has ended
    SendChatMessage("Registration has ended. Let's see who goes first. " .. self.session.players[1].name .. " (1) or " .. self.session.players[2].name .. " (2)!", self.db.global.game.chatChannel)
    self:rollMe(2)
end

function WoWGoldGambler:deathRollRecordRoll(playerName, actualRoll, minRoll, maxRoll)
    -- If the dealer performed a /roll 2 and player turn order has not been decided yet, use the result to determine which player goes first
    if (self.session.dealer.name == playerName and self.session.modeData.currentPlayerIndex == nil and tonumber(minRoll) == 1 and tonumber(maxRoll) == 2) then
        local result = tonumber(actualRoll)
        local chosenPlayerName = self.session.players[result].name

        self.session.modeData.currentPlayerName = chosenPlayerName
        self.session.modeData.currentPlayerIndex = result

        -- The idle player gets a default roll for now
        if (result == 1) then
            self.session.players[2].roll = self.db.global.game.wager
        else
            self.session.players[1].roll = self.db.global.game.wager
        end

        SendChatMessage(chosenPlayerName .. " will go first! " .. chosenPlayerName .. ", /roll " .. self.db.global.game.wager .. " now!", self.db.global.game.chatChannel)
    -- If the current player made the current death roll, record the roll and adjust the other player's roll accordingly
    elseif (self.session.modeData.currentPlayerName == playerName and tonumber(minRoll) == 1 and tonumber(maxRoll) == self.session.modeData.currentRoll) then
        local result = tonumber(actualRoll)
        
        self.session.players[self.session.modeData.currentPlayerIndex].roll = result

        -- If the roll is not 1, it's now the other player's turn to roll. Their previous roll is voided and they are prompted to roll again with the new roll amount.
        if (result ~= 1) then
            local nextPlayerName
            local nextPlayerIndex

            if (self.session.modeData.currentPlayerIndex == 1) then
                nextPlayerIndex = 2
                nextPlayerName = self.session.players[2].name
            else
                nextPlayerIndex = 1
                nextPlayerName = self.session.players[1].name
            end

            self.session.modeData.currentRoll = result
            self.session.modeData.currentPlayerName = nextPlayerName
            self.session.modeData.currentPlayerIndex = nextPlayerIndex
            self.session.players[nextPlayerIndex].roll = nil

            SendChatMessage(playerName .. " survived their roll! " .. nextPlayerName .. ", now it's your turn. /roll " .. result .. " now!", self.db.global.game.chatChannel)
        else
            SendChatMessage("May You Rest In Peace, " .. playerName .. ".", self.db.global.game.chatChannel)
        end
    end
end

function WoWGoldGambler:deathRollCalculateResult()
    -- Calculation logic for the 1v1 Death Roll game mode. Ties should not be possible.
    -- Winner: The player who did not roll 1
    -- Loser: The player who rolled 1
    -- Payment Amount: The wager amount
    local winners = {}
    local losers = {}
    local amountOwed = self.db.global.game.wager

    for i = 1, #self.session.players do
        -- New loser
        if (self.session.players[i].roll == 1) then
            tinsert(losers, self.session.players[i])
        -- New winner
        else
            tinsert(winners, self.session.players[i])
        end
    end

    return {
        winners = winners,
        losers = losers,
        amountOwed = amountOwed
    }
end
