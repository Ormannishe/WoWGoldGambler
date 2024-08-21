-- Chicken Game Mode --

function WoWGoldGambler:chickenStartRolls()
    -- Informs players that the registration phase has ended and determines the roll amount (50% - 120% of the wager amount)
    SendChatMessage("Registration has ended. The bust amount is " ..  self:formatInt(self.db.global.game.wager) ..". Deciding the roll amount..." , self.db.global.game.chatChannel)

    self.session.modeData.rollAmount = math.floor(self.db.global.game.wager * (math.random(50, 120) / 100))

    SendChatMessage("All players /roll " .. self.session.modeData.rollAmount .. " now! Be careful not to bust!" , self.db.global.game.chatChannel)

    for i = 1, #self.session.players do
        self.session.players[i].rollTotal = 0
    end
end

function WoWGoldGambler:chickenOptOut(text, playerName, playerRealm)
    -- If a registered player who has not yet locked in their roll enters "-1" in the chat, lock in their roll
    if (text == "-1") then
        for i = 1, #self.session.players do
            if (self.session.players[i].name == playerName and self.session.players[i].roll == nil) then
                self.session.players[i].roll = self.session.players[i].rollTotal
                SendChatMessage(self.session.players[i].name .. " is done rolling!" , self.db.global.game.chatChannel)

                if (#self:checkPlayerRolls() == 0) then
                    self:calculateResult()
                end

                return
            end
        end
    end
end

function WoWGoldGambler:chickenRecordRoll(playerName, actualRoll, minRoll, maxRoll)
    -- If a registered player rolled the correct amount and has not opted out of rolling, add the roll amount to their rollTotal
    -- If their rollTotal exceeds the wager amount, they bust and cannot continue rolling
    if (tonumber(minRoll) == 1 and tonumber(maxRoll) == self.session.modeData.rollAmount) then
        for i = 1, #self.session.players do
            if (self.session.players[i].name == playerName and self.session.players[i].roll == nil) then
                self.session.players[i].rollTotal = self.session.players[i].rollTotal + tonumber(actualRoll)

                if (self.session.players[i].rollTotal > self.db.global.game.wager) then
                    SendChatMessage("BUST! " .. self.session.players[i].name .. " has exceeded the maximum roll amount!" , self.db.global.game.chatChannel)
                    self.session.players[i].roll = self.session.players[i].rollTotal
                else
                    SendChatMessage(self.session.players[i].name .. ", your total roll so far is " .. self:formatInt(self.session.players[i].rollTotal) .. ". Keep rolling or lock in your roll by typing '-1' in chat." , self.db.global.game.chatChannel)
                end

                return
            end
        end
    end
end

function WoWGoldGambler:chickenCalculateResult()
    -- Calculation logic for the Chicken game mode. Ties are allowed.
    -- Winner: The player(s) with the highest roll while not being larger than the wager amount
    -- Loser: ALL player(s) who's roll is higher than the wager amount. If no player's roll exceeds the wager amount, then the player(s) with the lowest roll.
    -- Payment Amount: The wager amount OR if no player's roll exceeds the wager amount, the difference between the losing and winning rolls
    local winners = {}
    local losers = {}
    local bestRoll = 0
    local worstRoll = self.db.global.game.wager
    local amountOwed = 0

    for i = 1, #self.session.players do
        if (self.session.players[i].roll > self.db.global.game.wager) then
            -- If this is the first time encountering a roll which exceeds the wager amount, clear the loser list. Players who roll below the wager amount can no longer lose.
            if (worstRoll > 0) then
                losers = {}
                worstRoll = 0
            end

            tinsert(losers, self.session.players[i])
        else
            -- Tied Winner
            if (self.session.players[i].roll == bestRoll) then
                tinsert(winners, self.session.players[i])
            end

            -- New Winner
            if (self.session.players[i].roll > bestRoll) then
                winners = {self.session.players[i]}
                bestRoll = self.session.players[i].roll
            end

            -- Tied Loser
            if (self.session.players[i].roll == worstRoll) then
                tinsert(losers, self.session.players[i])
            end

            -- New Loser
            if (self.session.players[i].roll < worstRoll) then
                losers = {self.session.players[i]}
                worstRoll = self.session.players[i].roll
            end
        end
    end

    -- Handle cases where there are no winners, no losers, or everyone is tied.
    if (#winners == 0 or #losers == 0 or winners[1].name == losers[1].name) then
        winners = {}
        losers = {}
    else
        if (losers[1].roll > self.db.global.game.wager) then
            -- If a player exceeded the wager amount, they owe the full amount split among all winners
            amountOwed = math.floor(self.db.global.game.wager / #winners)
        else
            -- If no player exceeded the wager amount, they owe the difference between the winning and losing rolls, split among all winners
            amountOwed = math.floor((winners[1].roll - losers[1].roll) / #winners)
        end
    end

    return {
        winners = winners,
        losers = losers,
        amountOwed = amountOwed
    }
end
