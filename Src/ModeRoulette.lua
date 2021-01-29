-- Roulette Game Mode --

function WoWGoldGambler:rouletteGameStart()
    SendChatMessage("WoWGoldGambler: A new game has been started! Type a number between 1 and 36 to join! (-1 to withdraw)" , self.db.global.game.chatChannel)

     -- DEBUG: REMOVE ME
     tinsert(self.session.players, {name = "Tester1", realm = "Tester", roll = 1})
     tinsert(self.session.players, {name = "Tester2", realm = "Tester", roll = 2})
     tinsert(self.session.players, {name = "Tester3", realm = "Tester", roll = 3})
     tinsert(self.session.players, {name = "Tester4", realm = "Tester", roll = 4})
     tinsert(self.session.players, {name = "Tester5", realm = "Tester", roll = 5})
     tinsert(self.session.players, {name = "Tester6", realm = "Tester", roll = 6})
     tinsert(self.session.players, {name = "Tester7", realm = "Tester", roll = 7})
     tinsert(self.session.players, {name = "Tester8", realm = "Tester", roll = 8})
     tinsert(self.session.players, {name = "Tester9", realm = "Tester", roll = 1})
     tinsert(self.session.players, {name = "Tester10", realm = "Tester", roll = 2})
     tinsert(self.session.players, {name = "Tester11", realm = "Tester", roll = 3})
     tinsert(self.session.players, {name = "Tester12", realm = "Tester", roll = 4})
end

function WoWGoldGambler:rouletteRegister(text, playerName, playerRealm)
    -- Registration for the Roulette game mode
    text = tonumber(text)

    if (text ~= nil and text > 0 and text < 37) then
        self:registerPlayer(playerName, playerRealm)
        
        for i = 1, #self.session.players do
            if (self.session.players[i] == playerName and self.session.players[i].roll == nil) then
                self.session.players[i].roll = text
            end
        end
    elseif (text == -1) then
        self:unregisterPlayer(playerName, playerRealm)
    end
end

function WoWGoldGambler:rouletteStartRolls()
    -- Informs players that the registration phase has ended. Performs a /roll 36 to determine the winning number
    SendChatMessage("Registration has ended. Spinning the wheel..." , self.db.global.game.chatChannel)
    self:rollMe(nil, 36)
end

function WoWGoldGambler:rouletteRecordRoll(playerName, actualRoll, minRoll, maxRoll)
    -- If the dealer performed a /roll 36, record it as the result of the roulette round
    if (self.session.dealer.name == playerName and self.session.dealer.roll == nil and tonumber(minRoll) == 1 and tonumber(maxRoll) == 36) then
        self.session.dealer.roll = tonumber(actualRoll)
        self:calculateResult()
    end
end

function WoWGoldGambler:rouletteCalculateResult()
    -- Calculation logic for the Roulette game mode. Ties are permitted.
    -- Winner: Anyone who registered with the winning number
    -- Loser: Anyone who did not choose the winning number. If there are no winners, there are no losers.
    -- Payment Amount: The wager amount (evenly distributed to all winners)
    for i = 1, #self.session.players do
        if (self.session.players[i].roll == self.session.dealer.roll) then
            tinsert(self.session.result.winners, self.session.players[i])
        else
            tinsert(self.session.result.losers, self.session.players[i])
        end
    end

    if (#self.session.result.winners > 0) then
        self.session.result.amountOwed = math.floor(self.db.global.game.wager / #self.session.result.winners)
    end
end