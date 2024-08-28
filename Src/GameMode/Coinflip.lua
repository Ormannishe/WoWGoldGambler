-- Coinflip Game Mode --
WoWGoldGambler.COINFLIP = {}

-- Default Game Start
WoWGoldGambler.COINFLIP.gameStart = WoWGoldGambler.DEFAULT.gameStart

-- Default Registration
WoWGoldGambler.COINFLIP.register = WoWGoldGambler.DEFAULT.register

WoWGoldGambler.COINFLIP.startRolls = function(self)
    -- Informs players that the registration phase has ended.
    SendChatMessage("Registration has ended. All players /roll 2 now!" , self.db.global.game.chatChannel)
    self.session.modeData.currentRoll = 2
    self.session.modeData.roundNumber = 1
end

WoWGoldGambler.COINFLIP.recordRoll = function(self, playerName, actualRoll, minRoll, maxRoll)
    -- If a registered player made the wager roll and has not yet rolled, record the roll
    if (tonumber(minRoll) == 1 and tonumber(maxRoll) == 2) then
        for i = 1, #self.session.players do
            if (self.session.players[i].name == playerName and self.session.players[i].roll == nil) then
                self.session.players[i].roll = tonumber(actualRoll)
            end
        end
    end
end

WoWGoldGambler.COINFLIP.calculateResult = function(self)
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

WoWGoldGambler.COINFLIP.detectTie = function(self)
    -- Output a message to the chat channel informing players of which tournament bracket is being resolved
    if (#self.session.result.winners > 1) then
        SendChatMessage("Winner's Bracket: " .. self:makeNameString(self.session.players) .. " /roll 2 now!", self.db.global.game.chatChannel)
    elseif (#self.session.result.losers > 1) then
        SendChatMessage("Loser's Bracket: " .. self:makeNameString(self.session.players) .. " /roll 2 now!", self.db.global.game.chatChannel)
    end

    self.session.modeData.roundNumber = self.session.modeData.roundNumber + 1
end

WoWGoldGambler.COINFLIP.setRecords = function(self)
    -- Updates records for the Coinflip game mode and reports when records are broken
    self:longestCoinflipRecord()
end

-- Implementation for records

function WoWGoldGambler:longestCoinflipRecord()
    -- TODO: Test this
    if (self.db.global.stats.records["Longest Coinflip"] == nil or
        self.session.modeData.roundNumber > self.db.global.stats.records["Longest Coinflip"].record) then

        self.db.global.stats.records["Longest Coinflip"] = {
            record = self.session.modeData.roundNumber,
            holders = self:makeNameString(self.session.players) -- Record holders should be just the players involved in the final round
        }

        SendChatMessage("New Record! That was the longest coinflip game I've ever seen (" .. self.session.modeData.roundNumber .. " rounds)!", self.db.global.game.chatChannel)
    end
end