-- Poker Game Mode --
WoWGoldGambler.POKER = {}

local handRankings = {
    ["Five Of A Kind"] = 1,
    ["Four Of A Kind"] = 2,
    ["Full House"] = 3,
    ["Straight"] = 4,
    ["Three Of A Kind"] = 5,
    ["Two Pair"] = 6,
    ["Pair"] = 7,
    ["High Card"] = 8
}

-- Default Game Start
WoWGoldGambler.POKER.gameStart = WoWGoldGambler.DEFAULT.gameStart

-- Default Registration
WoWGoldGambler.POKER.register = WoWGoldGambler.DEFAULT.register

WoWGoldGambler.POKER.startRolls = function(self)
    -- Informs players that the registration phase has ended.
    SendChatMessage("Registration has ended. All players /roll 11111-99999 now!" , self.db.global.game.chatChannel)
end

WoWGoldGambler.POKER.recordRoll = function(self, playerName, actualRoll, minRoll, maxRoll)
    -- If a registered player made the wager roll and has not yet rolled, record the roll
    if (tonumber(minRoll) == 11111 and tonumber(maxRoll) == 99999) then
        for i = 1, #self.session.players do
            if (self.session.players[i].name == playerName and self.session.players[i].roll == nil) then
                -- Translate rolls to poker hands as they come in and inform the players
                local hand = self:getPokerHand(actualRoll)

                self.session.players[i].roll = actualRoll
                self.session.players[i].pokerHand = hand
                self:postPokerResult(playerName, hand)
            end
        end
    end
end

WoWGoldGambler.POKER.calculateResult = function(self)
    -- Calculation logic for the Poker game mode. A tie breaker round will resolve ties
    -- Winner: The player that rolled the best poker hand
    -- Loser: The player that rolled the worst poker hand
    -- Payment Amount: The wager amount
    local winners = {}
    local losers = {}
    local bestHand = {
        type = "High Card",
        cardRanks = {1}
    }
    local worstHand = {
        type = "Five Of A Kind",
        cardRanks = {9}
    }

    for i = 1, #self.session.players do
        local playerHand = self.session.players[i].pokerHand
        local betterThanBest = self:comparePokerHands(playerHand, bestHand)
        local betterThanWorst = self:comparePokerHands(playerHand, worstHand)

        if (betterThanBest == nil) then
            -- Tied Winner
            tinsert(winners, self.session.players[i])
        elseif (betterThanBest == true) then
            -- New Winner
            winners = {self.session.players[i]}
            bestHand = playerHand
        end

        if (betterThanWorst == nil) then
            -- Tied Loser
            tinsert(losers, self.session.players[i])
        elseif (betterThanWorst == false) then
            -- New Loser
            losers = {self.session.players[i]}
            worstHand = playerHand
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
        amountOwed = self.db.global.game.wager
    }
end

WoWGoldGambler.POKER.detectTie = function(self)
    -- Output a message to the chat channel informing players of which tournament bracket is being resolved
    if (#self.session.result.winners > 1) then
        SendChatMessage("High end tie breaker! " .. self:makeNameString(self.session.players) .. " /roll 11111-99999 now!", self.db.global.game.chatChannel)
    elseif (#self.session.result.losers > 1) then
        SendChatMessage("Low end tie breaker! " .. self:makeNameString(self.session.players) .. " /roll 11111-99999 now!", self.db.global.game.chatChannel)
    end
end

-- Custom implementation for Poker game mode
-- These helper functions help us convert player rolls into poker hands and score them

function WoWGoldGambler:getPokerHand(roll)
    -- Transforms the given roll into a poker hand.
    -- Each digit in the roll is treated as a 'Card' with a rank equal to its value
    local groupedCards = {}
    local hand = {
        type = nil,
        cardRanks = {}
    }

    -- Group cards by their rank to discover pairs
    for card in string.gmatch(tostring(roll), "%d") do
        if (groupedCards[card] == nil) then
            groupedCards[card] = 0
        end

        groupedCards[card] = groupedCards[card] + 1
    end

    -- Keep track of the ranks of all unique card groups
    for key in pairs(groupedCards) do
        table.insert(hand.cardRanks, key)
    end

    -- Sort card ranks by the size of their group, ordering them by relevancy
    -- ie. The Three Of a Kind portion of a Full house is more important than the Pair portion
    -- If two groups have the same size (ie. Two Pairs), order by card rank instead (ie. The higher pair is more relevant)
    table.sort(hand.cardRanks, function(a, b)
        if (groupedCards[a] == groupedCards[b]) then
            return tonumber(a) > tonumber(b)
        else
            return groupedCards[a] > groupedCards[b]
        end
    end)

    -- Iterate through the sorted list of unique cards and determine the poker hand
    -- Since the list is ordered by relevancy, we should encounter the highest value part of the hand first
    for i = 1, #hand.cardRanks do
        local groupSize = groupedCards[hand.cardRanks[i]]

        if (groupSize == 5) then
            hand.type = "Five Of A Kind"
        elseif (groupSize == 4) then
            hand.type = "Four Of A Kind"
        elseif (groupSize == 3) then
            hand.type = "Three Of A Kind"
        elseif (groupSize == 2) then
            if (hand.type == "Three Of A Kind") then
                -- If we've already detected a Three Of A Kind and are now detecting a Pair, then the hand is a Full House
                hand.type = "Full House"
            elseif (hand.type == "Pair") then
                -- If we've already detected a Pair and are now detecting a second Pair, then the hand is a Two Pair
                hand.type = "Two Pair"
            else
                hand.type = "Pair"
            end
        elseif (groupSize == 1) then
            if (hand.type == nil) then
                -- If we have not detected a larger group, then the hand is all singles
                if (hand.cardRanks[1] - hand.cardRanks[#hand.cardRanks] == 4) then
                    -- If the hand is all singles, and the difference between the largest and smallest card is 4, the hand must be a straight
                    hand.type = "Straight"
                else
                    hand.type = "High Card"
                end
            end
        end
    end

    return hand
end

function WoWGoldGambler:comparePokerHands(hand1, hand2)
    -- Compares two poker hands, returning true if [hand1] is better than [hand2], false if [hand2] is better than [hand1], and nil if the hands are identical.

    -- First compare the hand types to determine which hand is higher scoring (in accordance with the handRankings)
    if (handRankings[hand1.type] < handRankings[hand2.type]) then
        return true
    elseif (handRankings[hand1.type] > handRankings[hand2.type]) then
        return false
    else
        -- If both hands are of the same type, look at individual card rankings (ordered by relevancy) to determine the better hand
        for i = 1, #hand1.cardRanks do
            if (tonumber(hand1.cardRanks[i]) > tonumber(hand2.cardRanks[i])) then
                return true
            elseif (tonumber(hand1.cardRanks[i]) < tonumber(hand2.cardRanks[i])) then
                return false
            end
        end

        -- If both hands are the same type, and all cards are of the same rank, then the hands are identical
        return nil
    end
end

function WoWGoldGambler:postPokerResult(playerName, hand)
    -- Inform players of the best poker hand taken from their roll
    if (hand.type == "Five Of A Kind") then
        SendChatMessage("JACKPOT!! " .. playerName .. " has rolled a Five Of A Kind (" .. hand.cardRanks[1] .. "'s)!!!", self.db.global.game.chatChannel)
    elseif (hand.type == "Four Of A Kind") then
        SendChatMessage("Incredible! " .. playerName .. " has rolled a Four Of A Kind (" .. hand.cardRanks[1] .. "'s with " .. hand.cardRanks[2] .. " kicker)!", self.db.global.game.chatChannel)
    elseif (hand.type == "Full House") then
        SendChatMessage("Awesome roll! " .. playerName .. " has rolled a Full House (" .. hand.cardRanks[1] .. "'s over " .. hand.cardRanks[2] .. "'s)!", self.db.global.game.chatChannel)
    elseif (hand.type == "Straight") then
        SendChatMessage("Nice Save! " .. playerName .. " has rolled a Straight (" .. hand.cardRanks[5] .. " to " .. hand.cardRanks[1] .. ")!", self.db.global.game.chatChannel)
    elseif (hand.type == "Three Of A Kind") then
        SendChatMessage("Great roll! " .. playerName .. " has rolled a Three Of A Kind (" .. hand.cardRanks[1] .. "'s with " .. hand.cardRanks[2] .. " kicker)!", self.db.global.game.chatChannel)
    elseif (hand.type == "Two Pair") then
        SendChatMessage("Double nice! " .. playerName .. " has rolled a Two Pair (" .. hand.cardRanks[1] .. "'s and " .. hand.cardRanks[2] .. "'s with " .. hand.cardRanks[3] .. " kicker)!", self.db.global.game.chatChannel)
    elseif (hand.type == "Pair") then
        SendChatMessage("Nice pair! " .. playerName .. " has rolled a Pair (" .. hand.cardRanks[1] .. "'s with " .. hand.cardRanks[2] .. " kicker)!", self.db.global.game.chatChannel)
    elseif (hand.type == "High Card") then
        SendChatMessage("Yikes! " .. playerName .. " has rolled a High Card (" .. hand.cardRanks[1] .. ")!", self.db.global.game.chatChannel)
    end
end