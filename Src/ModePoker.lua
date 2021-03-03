-- Poker Game Mode --

function WoWGoldGambler:pokerStartRolls()
    -- Informs players that the registration phase has ended.
    SendChatMessage("Registration has ended. All players /roll 11111-99999 now!" , self.db.global.game.chatChannel)
end

function WoWGoldGambler:pokerRecordRoll(playerName, actualRoll, minRoll, maxRoll)
    -- If a registered player made the wager roll and has not yet rolled, record the roll
    if (tonumber(minRoll) == 11111 and tonumber(maxRoll) == 99999) then
        for i = 1, #self.session.players do
            if (self.session.players[i].name == playerName and self.session.players[i].roll == nil) then
                local score, hand = self:scorePokerHand(actualRoll)

                self.session.players[i].roll = score
                SendChatMessage(playerName .. " has rolled a " .. hand .. "!" , self.db.global.game.chatChannel)
            end
        end
    end
end

function WoWGoldGambler:pokerCalculateResult()
    -- Calculation logic for the Poker game mode. A tie breaker round will resolve ties
    -- Winner: The player that rolled the best poker hand
    -- Loser: The player that rolled the worst poker hand
    -- Payment Amount: The wager amount
    local winners = {}
    local losers = {}
    local bestScore = 0
    local worstScore = 9999999

    --[[ EXPERIMENTAL WAY

    ISSUE: Winner cannot lose, loser cannot win (ie. when everyone is tied)

    table.sort(self.session.players, function(a, b)
        return a.roll > b.roll
      end)

    tinsert(winners, self.session.players[1])
    tinsert(losers, self.session.players[#self.session.players])

    for i = 2, #self.session.players do
        if (self.session.players[i] == winners[1]) then
            tinsert(winners, self.session.players[i])
        end

        if (self.session.players[i] == losers[1]) then
            tinsert(losers, self.session.players[i])
        end
    end
    ]]--

    -- USUAL WAY
    for i = 1, #self.session.players do
        local pokerHand = tostring(self.session.players[i].roll)
        local playerScore = self:scorePokerHand(pokerHand)

        -- Tied Winner
        if (playerScore == bestScore) then
            tinsert(winners, self.session.players[i])
        end

        -- New Winner
        if (playerScore > bestScore) then
            winners = {self.session.players[i]}
            bestScore = playerScore
        end

        -- Tied Loser
        if (playerScore == worstScore) then
            tinsert(losers, self.session.players[i])
        end

        -- New Loser
        if (playerScore < worstScore) then
            losers = {self.session.players[i]}
        end
    end

    -- In a scenario where all players tie, it's possible to run in to this edge case. Void out the losers so the round can end in a draw.
    if (winners[1].name == losers[1].name) then
        losers = {}
    end

    return {
        winners = winners,
        losers = losers,
        amountOwed = self.db.global.game.wager
    }
end

function WoWGoldGambler:scorePokerHand(hand)
    -- TODO: Determines the hand rolled (ie. High Card, Pair, Two Pair, Three Of A Kind, Straight, Full House, Four Of A Kind, Five Of A Kind)
    -- and scores it appropriatly (ie. a pair of 9's is worth more than a pair of 2's)
    -- Returns the score and type of hand (so we can translate rolls into poker hands for players)
    local score = 0
    local handType = "High Card"

    return score, handType
end

function WoWGoldGambler:pokerDetectTie()
    -- Output a message to the chat channel informing players of which tournament bracket is being resolved
    if (#self.session.result.winners > 1) then
        SendChatMessage("High end tie breaker! " .. self:makeNameString(self.session.players) .. " /roll 11111-99999 now!", self.db.global.game.chatChannel)
    elseif (#self.session.result.losers > 1) then
        SendChatMessage("Low end tie breaker! " .. self:makeNameString(self.session.players) .. " /roll 11111-99999 now!", self.db.global.game.chatChannel)
    end
end