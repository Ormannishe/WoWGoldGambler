-- Chicken Game Mode --
WoWGoldGambler.CHICKEN = {}

-- Default Game Start
WoWGoldGambler.CHICKEN.gameStart = WoWGoldGambler.DEFAULT.gameStart

-- Default Registration
WoWGoldGambler.CHICKEN.register = WoWGoldGambler.DEFAULT.register

WoWGoldGambler.CHICKEN.startRolls = function(self)
    -- Informs players that the registration phase has ended and determines the roll amount (50% - 120% of the wager amount)
    ChatMessage("Registration has ended. The bust amount is " ..  self:formatInt(self.db.global.game.wager) ..". Deciding the roll amount...")

    self.session.modeData.currentRoll = math.floor(self.db.global.game.wager * (math.random(50, 120) / 100))

    ChatMessage("All players /roll " .. self.session.modeData.currentRoll .. " now! Be careful not to bust!")

    for i = 1, #self.session.players do
        self.session.players[i].rollTotal = 0
    end
end

WoWGoldGambler.CHICKEN.recordRoll = function(self, playerName, actualRoll, minRoll, maxRoll)
    -- If a registered player rolled the correct amount and has not opted out of rolling, add the roll amount to their rollTotal
    -- If their rollTotal exceeds the wager amount, they bust and cannot continue rolling
    if (tonumber(minRoll) == 1 and tonumber(maxRoll) == self.session.modeData.currentRoll) then
        for i = 1, #self.session.players do
            if (self.session.players[i].name == playerName and self.session.players[i].roll == nil) then
                self.session.players[i].rollTotal = self.session.players[i].rollTotal + tonumber(actualRoll)

                if (self.session.players[i].rollTotal > self.db.global.game.wager) then
                    ChatMessage("BUST! " .. self.session.players[i].name .. " has exceeded the maximum roll amount!")
                    self.session.players[i].roll = self.session.players[i].rollTotal
                else
                    ChatMessage(self.session.players[i].name .. ", your total roll so far is " .. self:formatInt(self.session.players[i].rollTotal) .. ". Keep rolling or lock in your roll by typing '-1' in chat.")
                end

                return
            end
        end
    end
end

-- During this game mode, we continue listening to chat messages during the rolling phase
-- Players will use the chat to let us know when they're done rolling
WoWGoldGambler.CHICKEN.handleChatMessage = function(self, text, playerName, playerRealm)
    -- If a registered player who has not yet locked in their roll enters "-1" in the chat, lock in their roll
    if (text == "-1") then
        for i = 1, #self.session.players do
            if (self.session.players[i].name == playerName and self.session.players[i].roll == nil) then
                self.session.players[i].roll = self.session.players[i].rollTotal
                ChatMessage(self.session.players[i].name .. " is done rolling!")

                if (#self:checkPlayerRolls() == 0) then
                    self:calculateResult()
                end

                return
            end
        end
    end
end

WoWGoldGambler.CHICKEN.calculateResult = function(self)
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

-- Default Tie Resolution
WoWGoldGambler.CHICKEN.detectTie = WoWGoldGambler.DEFAULT.detectTie

WoWGoldGambler.CHICKEN.setRecords = function(self)
    -- Updates records for the Chicken game mode and reports when records are broken
    self:biggestBustRecord()
    self:mostBustsRecord()
    self:mostRollsRecord()
end

-- Game-mode specific records

function WoWGoldGambler:biggestBustRecord()
    -- TODO: Test this
    -- This record can only be broken if the losers busted
    if (self.session.result.losers[1].roll > self.db.global.game.wager) then
        local worstDiff = self.session.result.losers[1].roll - self.db.global.game.wager
        local loserName = self.session.result.losers[1].name

        for i = 2, #self.session.result.losers do
            local diff = self.session.result.losers[i].roll - self.db.global.game.wager

            if (diff > worstDiff) then
                worstDiff = diff
                loserName = self.session.result.losers[i].name
            elseif (diff == worstDiff) then
                -- It's possible multiple losers broke the record with the same roll, in which case they are all record holders
                loserName = loserName .. ", " .. self.session.result.losers[i].name
            end
        end

        if (self.db.global.stats.records.CHICKEN["Biggest Bust"] == nil or
            worstDiff > self.db.global.stats.records.CHICKEN["Biggest Bust"].record) then

            self.db.global.stats.records.CHICKEN["Biggest Bust"] = {
                record = worstDiff,
                holders = loserName
            }

            ChatMessage("New Record! That was the biggest Chicken bust I've ever seen! You were over the bust amount by " .. self:formatInt(worstDiff) .. "!")
        end
    end
end

function WoWGoldGambler:mostBustsRecord()
    -- TODO: Test this
    -- This record can only be broken if the losers busted
    if (self.session.result.losers[1].roll > self.db.global.game.wager) then
        local totalBusts = #self.session.result.losers

        if (self.db.global.stats.records.CHICKEN["Most Busts"] == nil or
            totalBusts > self.db.global.stats.records.CHICKEN["Most Busts"].record) then

            self.db.global.stats.records.CHICKEN["Most Busts"] = {
                record = totalBusts,
                holders = self:makeNameString(self.session.result.losers)
            }

            ChatMessage("New Record! That was the most amount of busts I've ever seen in a game of Chicken! " .. totalBusts .. " of you totally blew it!")
        end
    end
end

function WoWGoldGambler:mostRollsRecord()
    -- TODO: Test this
    local mostRolls = self.session.players[1].numRolls
    local playerName = self.session.players[1].name

        for i = 2, #self.session.players do
            local rolls = self.session.players[i].numRolls

            if (rolls > mostRolls) then
                mostRolls = rolls
                playerName = self.session.players[i].name
            elseif (rolls == mostRolls) then
                -- It's possible multiple players broke the record with the same number of roll, in which case they are all record holders
                playerName = playerName .. ", " .. self.session.players[i].name
            end
        end

        if (self.db.global.stats.records.CHICKEN["Most Rolls"] == nil or
            mostRolls > self.db.global.stats.records.CHICKEN["Most Rolls"].record) then

            self.db.global.stats.records.CHICKEN["Most Rolls"] = {
                record = mostRolls,
                holders = playerName
            }

            ChatMessage("New Record! That was the highest number of rolls I've ever seen in a game of Chicken! " .. playerName .. ", you rolled " .. mostRolls .. " times!")
        end
end