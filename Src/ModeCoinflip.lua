-- Coinflip Game Mode --

function WoWGoldGambler:coinflipStartRolls()
    -- Informs players that the registration phase has ended.
    SendChatMessage("Registration has ended. All players /roll 2 now!" , self.db.global.game.chatChannel)
end

function WoWGoldGambler:coinflipRecordRoll(playerName, actualRoll, minRoll, maxRoll)
    -- If a registered player made the wager roll and has not yet rolled, record the roll
    if (tonumber(minRoll) == 1 and tonumber(maxRoll) == 2) then
        for i = 1, #self.session.players do
            if (self.session.players[i].name == playerName and self.session.players[i].roll == nil) then
                self.session.players[i].roll = tonumber(actualRoll)
            end
        end
    end
end

function WoWGoldGambler:coinflipCalculateResult()
    -- Calculation logic for the Coinflip game mode. Multiple tie-breaker rounds will resolve the ties.
    -- Winner: The player that rolled the most 2's
    -- Loser: The player that rolled the most 1's
    -- Payment Amount: The wager amount
    local winners = {}
    local losers = {}

    for i = 1, #self.session.players do
        if (self.session.players[i].roll == 1) then
            tinsert(losers, self.session.players[i])
        elseif (self.session.players[i].roll == 2) then
            tinsert(winners, self.session.players[i])
        end
    end

    return {
        winners = winners,
        losers = losers,
        amountOwed = self.db.global.game.wager
    }
end

function WoWGoldGambler:coinflipDetectTie()
    -- Output a message to the chat channel informing players of which tournament bracket is being resolved
    if (#self.session.result.winners > 1) then
        SendChatMessage("Winner's Bracket: " .. self:makeNameString(self.session.players) .. " /roll 2 now!", self.db.global.game.chatChannel)
    elseif (#self.session.result.losers > 1) then
        SendChatMessage("Loser's Bracket: " .. self:makeNameString(self.session.players) .. " /roll 2 now!", self.db.global.game.chatChannel)
    end

    -- DEBUG: REMOVE ME
    for i = 1, #self.session.players do
        if (self.session.players[i].name == "Tester1") then
            self.session.players[i].roll = 1
        elseif (self.session.players[i].name == "Tester2") then
            self.session.players[i].roll = 2
        elseif (self.session.players[i].name == "Tester3") then
            self.session.players[i].roll = 1
        elseif (self.session.players[i].name == "Tester4") then
            self.session.players[i].roll = 2
        end
    end
end