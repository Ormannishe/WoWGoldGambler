-- Classic Game Mode --

function WoWGoldGambler:classicGameStart()
    SendChatMessage("WoWGoldGambler: A new game has been started! Type 1 to join! (-1 to withdraw)" , self.db.global.game.chatChannel)
end

function WoWGoldGambler:classicRegister(text, playerName, playerRealm)
    -- Basic registration for most game modes
    if (text == "1") then
        self:registerPlayer(playerName, playerRealm)
    elseif (text == "-1") then
        self:unregisterPlayer(playerName, playerRealm)
    end
end

function WoWGoldGambler:classicStartRolls()
    -- Informs players that the registration phase has ended
    SendChatMessage("Registration has ended. All players /roll " .. self.db.global.game.wager .. " now!" , self.db.global.game.chatChannel)
end

function WoWGoldGambler:classicRecordRoll(playerName, actualRoll, minRoll, maxRoll)
    -- If a registered player made the wager roll and has not yet rolled, record the roll
    if (tonumber(minRoll) == 1 and tonumber(maxRoll) == self.db.global.game.wager) then
        for i = 1, #self.session.players do
            if (self.session.players[i].name == playerName and self.session.players[i].roll == nil) then
                self.session.players[i].roll = tonumber(actualRoll)
            end
        end
    end
end

function WoWGoldGambler:classicCalculateResult()
    -- Calculation logic for the Classic game mode. A tie-breaker round will resolve ties.
    -- Winner: The player(s) with the highest roll
    -- Loser: The player(s) with the lowest roll
    -- Payment Amount: The difference between the losing and winning rolls
    local winners = {self.session.players[1]}
    local losers = {self.session.players[1]}
    local amountOwed = 0

    for i = 2, #self.session.players do
        -- New loser
        if (self.session.players[i].roll < losers[1].roll) then
            losers = {self.session.players[i]}
        -- New winner
        elseif (self.session.players[i].roll > winners[1].roll) then
            winners = {self.session.players[i]}
        else
            -- Handle ties. Due to the way we initialize the winners/losers, it's possible for both of these to be true
            if (self.session.players[i].roll == losers[1].roll) then
                tinsert(losers, self.session.players[i])
            end

            if (self.session.players[i].roll == winners[1].roll) then
                tinsert(winners, self.session.players[i])
            end
        end
    end

    -- In a scenario where all players tie, it's possible to run in to this edge case. Void out the losers so the round can end in a draw.
    if (winners[1].name == losers[1].name) then
        losers = {}
    else
        amountOwed = winners[1].roll - losers[1].roll
    end

    return {
        winners = winners,
        losers = losers,
        amountOwed = amountOwed
    }
end

function WoWGoldGambler:classicDetectTie()
    -- Output a message to the chat channel informing players of a tie (and which end the tie is on)
    if (#self.session.result.winners > 1) then
        SendChatMessage("High end tie breaker! " .. self:makeNameString(self.session.players) .. " /roll " .. self.db.global.game.wager .. " now!", self.db.global.game.chatChannel)
    elseif (#self.session.result.losers > 1) then
        SendChatMessage("Low end tie breaker! " .. self:makeNameString(self.session.players) .. " /roll " .. self.db.global.game.wager .. " now!", self.db.global.game.chatChannel)
    end
end