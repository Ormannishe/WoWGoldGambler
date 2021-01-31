-- Classic Game Mode --

function WoWGoldGambler:classicGameStart()
    SendChatMessage("WoWGoldGambler: A new game has been started! Type 1 to join! (-1 to withdraw)" , self.db.global.game.chatChannel)

     -- DEBUG: REMOVE ME
     tinsert(self.session.players, {name = "Tester1", realm = "Tester", roll = 1})
     tinsert(self.session.players, {name = "Tester2", realm = "Tester", roll = 2})
end

function WoWGoldGambler:classicRegister(text, playerName, playerRealm)
    -- Registration for non-roulette game modes
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

function WoWGoldGambler:classicRecordRoll(players, playerName, actualRoll, minRoll, maxRoll)
    -- If a registered player made the wager roll and has not yet rolled, record the roll
    if (tonumber(minRoll) == 1 and tonumber(maxRoll) == self.db.global.game.wager) then
        for i = 1, #players do
            if (players[i].name == playerName and players[i].roll == nil) then
                players[i].roll = tonumber(actualRoll)
            end
        end
    end
end

function WoWGoldGambler:classicCalculateResult(players)
    -- Calculation logic for the Classic game mode. A tie-breaker round will resolve ties.
    -- Winner: The player(s) with the highest roll
    -- Loser: The player(s) with the lowest roll
    -- Payment Amount: The difference between the losing and winning rolls
    local winners = {players[1]}
    local losers = {players[1]}

    for i = 2, #players do
        -- New loser
        if (players[i].roll < losers[1].roll) then
            losers = {players[i]}
        -- New winner
        elseif (players[i].roll > winners[1].roll) then
            winners = {players[i]}
        else
            -- Handle ties. Due to the way we initialize the winners/losers, it's possible for both of these to be true
            if (players[i].roll == losers[1].roll) then
                tinsert(losers, players[i])
            end
            if (players[i].roll == winners[1].roll) then
                tinsert(winners, players[i])
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
        amountOwed = winners[1].roll - losers[1].roll
    }
end

function WoWGoldGambler:classicDetectTie(tieBreakers)
    -- Output a message to the chat channel informing players of a tie (and which end the tie is on)
    if (#self.session.result.tieBreakerType == "winner") then
        SendChatMessage("High end tie breaker! " .. self:makeNameString(self.session.result.tieBreakers) .. " /roll " .. self.db.global.game.wager .. " now!", self.db.global.game.chatChannel)
    elseif (#self.session.result.tieBreakerType == "loser") then
        SendChatMessage("Low end tie breaker! " .. self:makeNameString(self.session.result.tieBreakers) .. " /roll " .. self.db.global.game.wager .. " now!", self.db.global.game.chatChannel)
    end
end