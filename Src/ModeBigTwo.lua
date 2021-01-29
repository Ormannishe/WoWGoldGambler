-- BigTwo Game Mode --

function WoWGoldGambler:bigTwoStartRolls()
    -- Informs players that the registration phase has ended.
    SendChatMessage("Registration has ended. All players /roll 2 now!" , self.db.global.game.chatChannel)
end

function WoWGoldGambler:bigTwoRecordRoll(playerName, actualRoll, minRoll, maxRoll)
    -- If a registered player made the wager roll and has not yet rolled, record the roll
    if (tonumber(minRoll) == 1 and tonumber(maxRoll) == 2) then
        for i = 1, #self.session.players do
            if (self.session.players[i].name == playerName and self.session.players[i].roll == nil) then
                self.session.players[i].roll = tonumber(actualRoll)
            end
        end
    end

    -- If all registered players have rolled, calculate the result
    if (#self:checkPlayerRolls() == 0) then
        self:calculateResult()
    end
end

function WoWGoldGambler:bigTwoCalculateResult()
    -- Calculation logic for the BigTwo game mode. Ties are not possible.
    -- Winner: A randomly selected player from the set of players who rolled a 2
    -- Loser: A randomly selected player from the set of players who rolled a 1
    -- Payment Amount: The wager amount
    for i = 1, #self.session.players do
        if (self.session.players[i].roll == 1) then
            tinsert(self.session.result.losers, self.session.players[i])
        elseif (self.session.players[i].roll == 2) then
            tinsert(self.session.result.winners, self.session.players[i])
        end
    end

    if (#self.session.result.losers > 0) then
        self.session.result.losers = {self.session.result.losers[math.random(#self.session.result.losers)]}
    end

    if (#self.session.result.winners > 0) then
        self.session.result.winners = {self.session.result.winners[math.random(#self.session.result.winners)]}
    end

    self.session.result.amountOwed = self.db.global.game.wager
end