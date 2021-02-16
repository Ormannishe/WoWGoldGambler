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
        if (self.session.dealer.roll == nil) then
            if (playerName == self.session.dealer.name and tonumber(maxRoll) == self.db.global.game.wager) then
                self.session.dealer.roll = tonumber(actualRoll)
                SendChatMessage("The price is " .. self.session.dealer.roll .. "! Be careful not to go over!" , self.db.global.game.chatChannel)
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
    local winners = {self.session.players[1]}
    local losers = {self.session.players[1]}
    local biggestDiff = math.abs(self.session.dealer.roll - self.session.players[1].roll)

    for i = 2, #self.session.players do
        -- Roll was lower than or equal to the price
        if (self.session.players[i].roll <= self.session.dealer.roll) then
            -- New Winner
            if (self.session.players[i].roll > winners[1].roll) then
                winners = {self.session.players[i]}
            -- New Loser
            elseif (self.session.dealer.roll - self.session.players[i].roll > biggestDiff) then
                losers = {self.session.players[i]}
                biggestDiff = self.session.dealer.roll - self.session.players[i].roll
            else
                -- Handle ties. Due to the way we initialize the winners/losers, it's possible for both of these to be true
                if (self.session.players[i].roll == winners[1].roll) then
                    tinsert(winners, self.session.players[i])
                end
            
                if (self.session.dealer.roll - self.session.players[i].roll == biggestDiff) then
                    tinsert(losers, self.session.players[i])
                end
            end
        -- Roll was higher than the price
        else
            -- New Loser
            if (self.session.players[i].roll - self.session.dealer.roll > biggestDiff) then
                losers = {self.session.players[i]}
                biggestDiff = self.session.players[i].roll - self.session.dealer.roll
            -- Tied Loser
            elseif (self.session.players[i].roll - self.session.dealer.roll == biggestDiff) then
                tinsert(losers, self.session.players[i])
            end
        end
    end

    -- In a scenario where all players tie, it's possible to run in to this edge case. Void out the losers as everyone tied.
    if (winners[1].name == losers[1].name) then
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
        SendChatMessage("High end tie breaker! " .. self:makeNameString(self.session.players) .. " /roll whatever you want now! The price is still " .. self.session.dealer.roll .. "!", self.db.global.game.chatChannel)
    elseif (#self.session.result.losers > 1) then
        SendChatMessage("Low end tie breaker! " .. self:makeNameString(self.session.players) .. " /roll whatever you want now! The price is still " .. self.session.dealer.roll .. "!", self.db.global.game.chatChannel)
    end
end