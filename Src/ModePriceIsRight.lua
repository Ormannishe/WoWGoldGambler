-- Price Is Right --

function WoWGoldGambler:priceIsRightStartRolls()
    -- Informs players that the registration phase has ended. Performs a /roll of the wager amount to set the 'price'
    SendChatMessage("Registration has ended. All players /roll " .. self.db.global.game.wager .. " now!" , self.db.global.game.chatChannel)
    self:rollMe(nil, self.db.global.game.wager)
end

function WoWGoldGambler:priceIsRightRecordRoll(players, playerName, actualRoll, minRoll, maxRoll)
    -- If the dealer made the wager roll and the 'price' has not yet been set, record it as the 'price'
    -- If a registered player made the wager roll and has not yet rolled, record the roll
    if (tonumber(minRoll) == 1 and tonumber(maxRoll) == self.db.global.game.wager) then
        if (self.session.dealer.roll == nil) then
            if (self.session.dealer.name == playerName) then
                self.session.dealer.roll = tonumber(actualRoll)
                SendChatMessage("The price is " .. self.session.dealer.roll .. "! Be careful not to go over!" , self.db.global.game.chatChannel)
            end
        else
            for i = 1, #players do
                if (players[i].name == playerName and players[i].roll == nil) then
                    players[i].roll = tonumber(actualRoll)
                end
            end
        end
    end
end

function WoWGoldGambler:priceIsRightCalculateResult(players)
    -- Calculation logic for the Price Is Right game mode. A tie-breaker round will resolve ties.
    -- Winner: The player(s) who rolled closest to the price without going over
    -- Loser: The player(s) who's roll was furthest from the price (either over or under)
    -- Payment Amount: The absolute difference between the price and the losing player's roll
    local winners = {players[1]}
    local losers = {players[1]}
    local biggestDiff = 0

    for i = 2, #players do
        -- Roll was lower than or equal to the price
        if (players[i].roll <= self.session.dealer.roll) then
            -- New Winner
            if (players[i].roll > winners[1].roll) then
                winners = {players[i]}
            -- New Loser
            elseif (self.session.dealer.roll - players[i].roll > biggestDiff) then
                losers = {players[i]}
                biggestDiff = self.session.dealer.roll - players[i].roll
            else
                -- Handle ties. Due to the way we initialize the winners/losers, it's possible for both of these to be true
                if (players[i].roll == winners[1].roll) then
                    tinsert(winners, players[i])
                end
            
                if (self.session.dealer.roll - players[i].roll == biggestDiff) then
                    tinsert(losers, players[i])
                end
            end
        -- Roll was higher than the price
        else
            -- New Loser
            if (players[i].roll - self.session.dealer.roll > biggestDiff) then
                losers = {players[i]}
                biggestDiff = players[i].roll - self.session.dealer.roll
            -- Tied Loser
            elseif (players[i].roll - self.session.dealer.roll == biggestDiff) then
                tinsert(losers, layers[i])
            end
        end
    end

    -- In a scenario where all players tie, it's possible to run in to this edge case. In this case, nobody wins or loses.
    if (winners == losers) then
        winners = {}
        losers = {}
    end

    return {
        winners = winners,
        losers = losers,
        amountOwed = biggestDiff
    }
end