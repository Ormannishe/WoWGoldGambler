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
                tinsert(losers, layers[i])
            end
        end
    end

    -- In a scenario where all players tie, it's possible to run in to this edge case. In this case, nobody wins or loses.
    if (winners[1].name == losers[1].name) then
        return {
            winners = {},
            losers = {},
            amountOwed = 0
        }
    end

    return {
        winners = winners,
        losers = losers,
        amountOwed = biggestDiff
    }
end