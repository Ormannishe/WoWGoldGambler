-- Coinflip Game Mode --

function WoWGoldGambler:coinflipStartRolls()
    -- Informs players that the registration phase has ended.
    SendChatMessage("Registration has ended. All players /roll 2 now!" , self.db.global.game.chatChannel)
end

function WoWGoldGambler:coinflipRecordRoll(players, playerName, actualRoll, minRoll, maxRoll)
    -- If a registered player made the wager roll and has not yet rolled, record the roll
    if (tonumber(minRoll) == 1 and tonumber(maxRoll) == 2) then
        for i = 1, #players do
            if (players[i].name == playerName and players[i].roll == nil) then
                players[i].roll = tonumber(actualRoll)
            end
        end
    end
end

function WoWGoldGambler:coinflipCalculateResult(players)
    -- Calculation logic for the Coinflip game mode. Ties are not possible.
    -- Winner: A randomly selected player from the set of players who rolled a 2
    -- Loser: A randomly selected player from the set of players who rolled a 1
    -- Payment Amount: The wager amount
    local winners = {}
    local losers = {}

    for i = 1, #players do
        if (players[i].roll == 1) then
            tinsert(losers, players[i])
        elseif (players[i].roll == 2) then
            tinsert(winners, players[i])
        end
    end

    return {
        winners = winners,
        losers = losers,
        amountOwed = self.db.global.game.wager
    }
end

function WoWGoldGambler:coinflipDetectTie(tieBreakers)
    -- Output a message to the chat channel informing players of which tournament bracket is being resolved
    if (#self.session.result.tieBreakerType == "winner") then
        SendChatMessage("Winner's Bracket: " .. self:makeNameString(self.session.result.tieBreakers) .. " /roll 2 now!", self.db.global.game.chatChannel)
    elseif (#self.session.result.tieBreakerType == "loser") then
        SendChatMessage("Loser's Bracket: " .. self:makeNameString(self.session.result.tieBreakers) .. " /roll 2 now!", self.db.global.game.chatChannel)
    end
end