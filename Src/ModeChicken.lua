-- Chicken Game Mode --

function WoWGoldGambler:chickenRegister(text, playerName, playerRealm)
    -- Registration for chicken game mode
    if (text == "1") then
        self:registerPlayer(playerName, playerRealm)
    elseif (text == "-1") then
        self:unregisterPlayer(playerName, playerRealm)
    end
end

function WoWGoldGambler:chickenStartRolls()
    -- Informs players that the registration phase has ended and determine the roll amount (65% - 105% of the wager amount)
    if (self.session.dealer.roll == nil) then
        self.session.dealer.roll = math.floor(self.db.global.game.wager * (math.random(65, 105) / 100))
    end

    SendChatMessage("Registration has ended. All players /roll " .. self.session.dealer.roll .. " now!" , self.db.global.game.chatChannel)
end

function WoWGoldGambler:chickenRecordRoll(playerName, actualRoll, minRoll, maxRoll)
    -- If a registered player made the wager roll and has not yet rolled, record the roll
    -- rollTotal will keep track of the total amount the player has rolled across all rounds of the session
    if (tonumber(minRoll) == 1 and tonumber(maxRoll) == self.session.dealer.roll) then
        for i = 1, #self.session.players do
            if (self.session.players[i].name == playerName and self.session.players[i].roll == nil) then
                self.session.players[i].roll = tonumber(actualRoll)

                if (self.session.players[i].rollTotal == nil) then
                    self.session.players[i].rollTotal = 0
                end

                self.session.players[i].rollTotal = self.session.players[i].rollTotal + tonumber(actualRoll)
            end
        end
    end
end

function WoWGoldGambler:chickenCalculateResult()
    -- Calculation logic for the Chicken game mode. Ties are allowed. Results are not final until all players opt out of playing or exceed the wager amount.
    -- Winner: The player(s) with the highest roll total while not being larger than the wager amount
    -- Loser: ALL player(s) who's roll total is higher than the wager amount. If no player's roll total exceeds the wager amount, then the player with the lowest roll total.
    -- Payment Amount: The wager amount OR the difference between the losing and winning rolls
    local winners = {}
    local losers = {}
    local bestRollTotal = 0
    local worstRollTotal = self.db.global.game.wager
    local amountOwed = 0
    local moreRounds = false

    for i = 1, #self.session.players do
        -- Check to see if the player qualifies for another round
        if (self.session.players[i].optIn == true and self.session.players[i].rollTotal < self.db.global.game.wager) then
            moreRounds = true
        end

        if (self.session.players[i].rollTotal > self.session.dealer.roll) then
            -- Clear the loser list if it previously contained a loser who did not exceed the wager amount
            -- Set worstRollTotal to 0 so no players with a roll less than the wager amount can lose
            if (losers[1].rollTotal <= self.db.global.game.wager) then
                losers = {}
                worstRollTotal = 0
            end

            tinsert(losers, self.session.players[i])
        else
            -- Tied Winner
            if (self.session.players[i].rollTotal == bestRollTotal) then
                tinsert(winners, self.session.players[i])
            end

            -- New Winner
            if (self.session.players[i].rollTotal > bestRollTotal) then
                winners = {self.session.players[i]}
                bestRollTotal = self.session.players[i].rollTotal
            end

            -- Tied Loser
            if (self.session.players[i].rollTotal == worstRollTotal) then
                tinsert(losers, self.session.players[i])
            end

            -- New Loser
            if (self.session.players[i].rollTotal < worstRollTotal) then
                losers = {self.session.players[i]}
                worstRollTotal = self.session.players[i].rollTotal
            end
        end
    end

    -- In a scenario where all players tie, it's possible to run in to this edge case. Void out the losers so the round can end in a draw.
    if (winners[1].name == losers[1].name) then
        losers = {}
    else
        if (losers[1].rollTotal > self.db.global.game.wager) then
            -- If a player exceeded the wager amount, they owe the full wager
            amountOwed = self.db.global.game.wager
        else
            -- If no player exceeded the wager amount, they owe the difference between the rollTotals
            amountOwed = winners[1].rollTotal - losers[1].rollTotal
        end
    end

    if (moreRounds) then
        -- Report the current standings and do another round
    else
        -- Return the final result
        return {
            winners = winners,
            losers = losers,
            amountOwed = amountOwed
        }
    end
end

-- TODO: Decide if there will be ties
function WoWGoldGambler:chickenDetectTie()
    -- Output a message to the chat channel informing players of a tie (and which end the tie is on)
    if (#self.session.result.winners > 1) then
        SendChatMessage("High end tie breaker! " .. self:makeNameString(self.session.players) .. " /roll " .. self.db.global.game.wager .. " now!", self.db.global.game.chatChannel)
    elseif (#self.session.result.losers > 1) then
        SendChatMessage("Low end tie breaker! " .. self:makeNameString(self.session.players) .. " /roll " .. self.db.global.game.wager .. " now!", self.db.global.game.chatChannel)
    end
end