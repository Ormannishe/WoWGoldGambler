-- 1v1 Death Roll Game Mode --
WoWGoldGambler["1v1 DEATH ROLL"] = {}

WoWGoldGambler["1v1 DEATH ROLL"].gameStart = function(self)
    ChatMessage("WoWGoldGambler: A new 1v1 Death Roll game has been started! The first two players to type 1 will 1v1 roll to the death! (-1 to withdraw)")
    self.session.modeData.currentRoll = self.db.global.game.wager
end

WoWGoldGambler["1v1 DEATH ROLL"].register = function(self, text, playerName, playerRealm)
    -- Same as regular registration, but capped at only two players
    if (text == "1" and #self.session.players < 2) then
        self:registerPlayer(playerName, playerRealm)
    elseif (text == "1" and #self.session.players == 2) then
        if (playerName ~= self.session.players[1].name and playerName ~= self.session.players[2].name) then
            ChatMessage("Sorry " .. playerName .. ", both spots have already been claimed! Maybe next time!")
        end
    elseif (text == "-1") then
        local playerOne = self.session.players[1]
        local playerTwo = self.session.players[2]

        if ((playerOne ~= nil and playerName == playerOne.name) or (playerTwo ~= nil and playerName == playerTwo.name)) then
            self:unregisterPlayer(playerName, playerRealm)
            ChatMessage(playerName .. " has backed out! Will anyone else claim their spot?")
        end
    end
end

WoWGoldGambler["1v1 DEATH ROLL"].startRolls = function(self)
    -- Informs players that the registration phase has ended and performs a /roll 2 to determine which player goes first
    ChatMessage("Registration has ended. Let's see who goes first. " .. self.session.players[1].name .. " (1) or " .. self.session.players[2].name .. " (2)!")
    self:rollMe(2)
end

WoWGoldGambler["1v1 DEATH ROLL"].recordRoll = function(self, playerName, actualRoll, minRoll, maxRoll)
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

        ChatMessage(chosenPlayerName .. " will go first! " .. chosenPlayerName .. ", /roll " .. self.db.global.game.wager .. " now!")
    -- If the current player made the current death roll, record the roll and adjust the other player's roll accordingly
    elseif (self.session.modeData.currentPlayerName == playerName and tonumber(minRoll) == 1 and tonumber(maxRoll) == self.session.modeData.currentRoll) then
        local result = tonumber(actualRoll)
        
        self.session.players[self.session.modeData.currentPlayerIndex].roll = result

        -- If the roll is not 1, it's now the other player's turn to roll. Their previous roll is voided and they are prompted to roll again with the new roll amount
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

            ChatMessage(playerName .. " survived their roll! " .. nextPlayerName .. ", now it's your turn. /roll " .. result .. " now!")
        else
            ChatMessage("May You Rest In Peace, " .. playerName .. ".")
        end
    end
end

WoWGoldGambler["1v1 DEATH ROLL"].calculateResult = function(self)
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

-- Default Tie Resolution
WoWGoldGambler["1v1 DEATH ROLL"].detectTie = WoWGoldGambler.DEFAULT.detectTie