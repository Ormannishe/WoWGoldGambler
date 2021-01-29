-- Price Is Right --

function WoWGoldGambler:priceIsRightStartRolls()
    -- Informs players that the registration phase has ended. Performs a /roll of the wager amount to set the 'price'
    SendChatMessage("Registration has ended. All players /roll " .. self.db.global.game.wager .. " now!" , self.db.global.game.chatChannel)
    self:rollMe(nil, self.db.global.game.wager)
end

function WoWGoldGambler:priceIsRightRecordRoll(playerName, actualRoll, minRoll, maxRoll)
    -- If the dealer made the wager roll and the 'price' has not yet been set, record it as the 'price'
    -- If a registered player made the wager roll and has not yet rolled, record the roll
    if (tonumber(minRoll) == 1 and tonumber(maxRoll) == self.db.global.game.wager) then
        if (self.session.dealer.roll == nil) then
            if (self.session.dealer.name == playerName) then
                self.session.dealer.roll = tonumber(actualRoll)
                SendChatMessage("The price is " .. self.session.dealer.roll .. "! Be careful not to go over!" , self.db.global.game.chatChannel)
            end
        else
            for i = 1, #self.session.players do
                if (self.session.players[i].name == playerName and self.session.players[i].roll == nil) then
                    self.session.players[i].roll = tonumber(actualRoll)
                end
            end
        
            -- If all registered players have rolled, calculate the result
            if (#self:checkPlayerRolls() == 0) then
                self:calculateResult()
            end
        end
    end
end

function WoWGoldGambler:priceIsRightCalculateResult()
    -- Calculation logic for the Price Is Right game mode. A tie-breaker round will resolve ties.
    -- Winner: The player(s) who rolled closest to the price without going over
    -- Loser: The player(s) who's roll was furthest from the price (either over or under)
    -- Payment Amount: The absolute difference between the price and the losing player's roll
    local smallestDiff = self.db.global.game.wager
    local biggestDiff = 0

    -- TODO: FIX ME
    tinsert(self.session.result.winners, self.session.players[1])
    tinsert(self.session.result.losers, self.session.players[1])


    for i = 2, #self.session.players do
        -- Roll was lower than or equal to the price
        if (self.session.players[i].roll <= self.session.dealer.roll) then
            -- New Winner
            if (self.session.dealer.roll - self.session.players[i].roll < smallestDiff) then
                smallestDiff = self.session.dealer.roll - self.session.players[i].roll
                self.session.result.winners = {self.session.players[i]}
            -- Tied Winner
            elseif (self.session.dealer.roll - self.session.players[i].roll == smallestDiff) then
                tinsert(self.session.result.winners, self.session.players[i])
            -- New Loser
            elseif (self.session.dealer.roll - self.session.players[i].roll > biggestDiff) then
                biggestDiff = self.session.dealer.roll - self.session.players[i].roll
                self.session.result.losers = {self.session.players[i]}
            -- Tied Loser
            elseif (self.session.dealer.roll - self.session.players[i].roll == biggestDiff) then
                tinsert(self.session.result.losers, self.session.players[i])
            end
        -- Roll was higher than the price
        elseif (self.session.players[i].roll > self.session.dealer.roll) then
            -- New Loser
            if (self.session.players[i].roll - self.session.dealer.roll > biggestDiff) then
                biggestDiff = self.session.players[i].roll - self.session.dealer.roll
                self.session.result.losers = {self.session.players[i]}
            -- Tied Loser
            elseif (self.session.players[i].roll - self.session.dealer.roll == biggestDiff) then
                tinsert(self.session.result.losers, self.session.players[i])
            end
        end
    end

    self.session.result.amountOwed = biggestDiff
end