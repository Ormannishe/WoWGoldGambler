-- Price Is Right Game Mode--
WoWGoldGambler["PRICE IS RIGHT"] = {}

-- Default Game Start
WoWGoldGambler["PRICE IS RIGHT"].gameStart = WoWGoldGambler.DEFAULT.gameStart

-- Default Registration
WoWGoldGambler["PRICE IS RIGHT"].register = WoWGoldGambler.DEFAULT.register

WoWGoldGambler["PRICE IS RIGHT"].startRolls = function(self)
    -- Informs players that the registration phase has ended. Performs a /roll of the wager amount to set the 'price'
    self:ChatMessage("Registration has ended. All players /roll whatever amount you want now! The price is " .. self:formatInt(self.db.global.game.wager) .. ". Be careful not to go over!")
end

WoWGoldGambler["PRICE IS RIGHT"].recordRoll = function(self, playerName, actualRoll, minRoll, maxRoll)
    -- If a registered player made any roll with a minRoll of 1 and has not yet rolled, record the roll
    if (tonumber(minRoll) == 1) then
        for i = 1, #self.session.players do
            if (self.session.players[i].name == playerName and self.session.players[i].roll == nil) then
                self.session.players[i].roll = tonumber(actualRoll)
            end
        end
    end
end

WoWGoldGambler["PRICE IS RIGHT"].calculateResult = function(self)
    -- Calculation logic for the Price Is Right game mode. A tie-breaker round will resolve ties.
    -- Winner: The player who rolled closest to the price without going over
    -- Loser: The player who's roll was furthest from the price (either over or under)
    -- Payment Amount: The difference between the loser's roll and the 'price', up to the wager amount
    local winners = {}
    local losers = {}
    local smallestDiff = 1000000 -- The biggest number that can be rolled is /roll 999999
    local biggestDiff = 0

    for i = 1, #self.session.players do
        local playerRoll = self.session.players[i].roll
        local playerDiff = math.abs(playerRoll - self.db.global.game.wager)

        -- Tied Winner
        if (playerDiff == smallestDiff and playerRoll <= self.db.global.game.wager) then
            tinsert(winners, self.session.players[i])
        end

        -- New Winner
        if (playerDiff < smallestDiff and playerRoll <= self.db.global.game.wager) then
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
        amountOwed = math.min(biggestDiff, self.db.global.game.wager)
    }
end

WoWGoldGambler["PRICE IS RIGHT"].detectTie = function(self)
    -- Output a message to the chat channel informing players of a tie (and which end the tie is on)
    if (#self.session.result.winners > 1) then
        self:ChatMessage("High end tie breaker! " .. self:makeNameString(self.session.players) .. " /roll whatever you want now! The price is still " .. self:formatInt(self.db.global.game.wager) .. "!")
    elseif (#self.session.result.losers > 1) then
        self:ChatMessage("Low end tie breaker! " .. self:makeNameString(self.session.players) .. " /roll whatever you want now! The price is still " .. self:formatInt(self.db.global.game.wager) .. "!")
    end
end

WoWGoldGambler["PRICE IS RIGHT"].setRecords = function(self)
    -- Updates records for the Price Is Right game mode and reports when records are broken
    self:biggestPriceDiff()
end

-- Game-mode specific records

function WoWGoldGambler:biggestPriceDiff()
    local loserRoll = self.session.result.losers[1].roll
    local loserName = self.session.result.losers[1].name
    local loserDiff = math.abs(loserRoll - self.db.global.game.wager)

    if (self.db.global.stats.records["PRICE IS RIGHT"]["Worst Roll"] == nil or
        loserDiff > self.db.global.stats.records["PRICE IS RIGHT"]["Worst Roll"].record) then

        self.db.global.stats.records["PRICE IS RIGHT"]["Worst Roll"] = {
            record = loserDiff,
            holders = loserName
        }

        self:ChatMessage("New Record! That was the worst Price Is Right roll I've ever seen! " .. loserName .. ", you were off by " .. self:formatInt(loserDiff) .. "!")
    end
end