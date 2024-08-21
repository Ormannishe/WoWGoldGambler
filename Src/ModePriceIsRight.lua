-- Price Is Right --

function WoWGoldGambler:priceIsRightStartRolls()
    -- Informs players that the registration phase has ended. Performs a /roll of the wager amount to set the 'price'
    SendChatMessage("Registration has ended. All players /roll whatever amount you want now!" , self.db.global.game.chatChannel)
    self:rollMe(self.db.global.game.wager)
end

function WoWGoldGambler:priceIsRightRecordRoll(playerName, actualRoll, minRoll, maxRoll)
    -- If the dealer made the wager roll and the 'price' has not yet been set, record it as the 'price'
    -- If a registered player made any roll with a minRoll of 1 and has not yet rolled, record the roll
    if (tonumber(minRoll) == 1) then
        if (self.session.modeData.price == nil) then
            if (playerName == self.session.dealer.name and tonumber(maxRoll) == self.db.global.game.wager) then
                self.session.modeData.price = tonumber(actualRoll)
                SendChatMessage("The price is " .. self:formatInt(self.session.modeData.price) .. "! Be careful not to go over!" , self.db.global.game.chatChannel)
            end
        else
            for i = 1, #self.session.players do
                if (self.session.players[i].name == playerName and self.session.players[i].roll == nil) then
                    self.session.players[i].roll = tonumber(actualRoll)
                end
            end
        end
    end
end

function WoWGoldGambler:priceIsRightCalculateResult()
    -- Calculation logic for the Price Is Right game mode. A tie-breaker round will resolve ties.
    -- Winner: The player(s) who rolled closest to the price without going over
    -- Loser: The player(s) who's roll was furthest from the price (either over or under)
    -- Payment Amount: The absolute difference between the price and the losing player's roll
    local winners = {}
    local losers = {}
    local smallestDiff = self.db.global.game.wager
    local biggestDiff = 0

    for i = 1, #self.session.players do
        local playerRoll = self.session.players[i].roll
        local playerDiff = math.abs(playerRoll - self.session.modeData.price)

        -- Tied Winner
        if (playerDiff == smallestDiff and playerRoll <= self.session.modeData.price) then
            tinsert(winners, self.session.players[i])
        end

        -- New Winner
        if (playerDiff < smallestDiff and playerRoll <= self.session.modeData.price) then
            winners = {self.session.players[i]}
            smallestDiff = playerDiff
        end

        -- Tied Loser
        if (playerDiff == biggestDiff) then
            tinsert(losers, self.session.players[i])
        end

        -- New Loser
        if (playerDiff > biggestDiff) then
            losers = {self.session.players[i]}
            biggestDiff = playerDiff
        end
    end

    -- In a scenario where all players tie, it's possible to run in to this edge case. Void out the losers so the round can end in a draw.
    if (#winners > 0 and
        #losers > 0 and
        winners[1].name == losers[1].name) then
        losers = {}
    end

    return {
        winners = winners,
        losers = losers,
        amountOwed = biggestDiff
    }
end

function WoWGoldGambler:priceIsRightDetectTie()
    -- Output a message to the chat channel informing players of a tie (and which end the tie is on)
    if (#self.session.result.winners > 1) then
        SendChatMessage("High end tie breaker! " .. self:makeNameString(self.session.players) .. " /roll whatever you want now! The price is still " .. self:formatInt(self.session.modeData.price) .. "!", self.db.global.game.chatChannel)
    elseif (#self.session.result.losers > 1) then
        SendChatMessage("Low end tie breaker! " .. self:makeNameString(self.session.players) .. " /roll whatever you want now! The price is still " .. self:formatInt(self.session.modeData.price) .. "!", self.db.global.game.chatChannel)
    end
end