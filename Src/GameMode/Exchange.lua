-- Exchange Game Mode --
WoWGoldGambler.EXCHANGE = {}

-- Default Game Start
WoWGoldGambler.EXCHANGE.gameStart = WoWGoldGambler.DEFAULT.gameStart

-- Default Registration
WoWGoldGambler.EXCHANGE.register = WoWGoldGambler.DEFAULT.register

WoWGoldGambler.EXCHANGE.startRolls = function(self) {
    -- Informs players that the registration phase has ended and performs a /roll 2 to select the first of two players to play
    SendChatMessage("Registration has ended. Let's see which players will be making an exchange!" , self.db.global.game.chatChannel)
    self:rollMe(#self.session.players)
}

WoWGoldGambler.EXCHANGE.recordRoll = function(self, playerName, actualRoll, minRoll, maxRoll)
    -- If the dealer made a roll for the number of players, use it to determine the first player
    -- If the first player made a roll for the number of player, use it to determine the second player (must be different from the first roll)
    -- If the losing player made a roll for the wager amount and the amount owed has not yet been determined, use it to determine the amount owed
    if (self.session.dealer.name == playerName and self.session.modeData.firstPlayerIndex == nil and
        tonumber(minRoll) == 1 and tonumber(maxRoll) == #self.session.players) then
        local firstPlayerIndex = tonumber(actualRoll)
        local firstPlayerName = self.session.players[firstPlayerIndex].name

        self.session.modeData.firstPlayerIndex = firstPlayerIndex
        self.session.modeData.firstPlayerName = firstPlayerName
        self.session.modeData.currentRoll = #self.session.players

        SendChatMessage(firstPlayerName .. ", you have been selected to make an exchange! Now, /roll " .. #self.session.players .. " to determine your opponent!", self.db.global.game.chatChannel)
    elseif (self.session.modeData.firstPlayerName == playerName and self.session.modeData.secondPlayerIndex == nil and
            tonumber(minRoll) == 1 and tonumber(maxRoll) == #self.session.players) then
        local secondPlayerIndex = tonumber(actualRoll)

        if (secondPlayerIndex ~= self.session.modeData.firstPlayerIndex) then
            local secondPlayerName = self.session.players[secondPlayerIndex].name

            self.session.modeData.secondPlayerIndex = secondPlayerIndex
            self.session.modeData.secondPlayerName = secondPlayerName

            SendChatMessage("Alright, " .. playerName .. " and ".. secondPlayerName .. " are about to make an exchange! Here are the possible outcomes!", self.db.global.game.chatChannel)
            SendChatMessage("{Skull} " .. playerName .. " owes " .. secondPlayerName .. " " .. self.db.global.game.wager .. " gold", self.db.global.game.chatChannel)
            SendChatMessage("{Cross} " .. playerName .. " owes " .. secondPlayerName .. " a rolled amount of gold", self.db.global.game.chatChannel)
            SendChatMessage("{Circle} " .. playerName .. " and " .. secondPlayerName .. " must /hug", self.db.global.game.chatChannel)
            SendChatMessage("{Diamond} " .. secondPlayerName .. " owes " .. playerName .. " a rolled amount of gold", self.db.global.game.chatChannel)
            SendChatMessage("{Star} " .. secondPlayerName .. " owes " .. playerName .. " " .. self.db.global.game.wager .. " gold", self.db.global.game.chatChannel)

            self:cycleRaidIconToggle(true)

            SendChatMessage("Now, " .. playerName .. ", notice the raid icons cycling above my head. When you're ready, type STOP in chat to determine the outcome!", self.db.global.game.chatChannel)
        else
            SendChatMessage("You can't play against yourself! Let's try that again. " .. playerName .. ", /roll ".. #self.session.players .. " to determine your opponent!", self.db.global.game.chatChannel)
        end
    elseif (self.session.modeData.loserName == playerName and self.session.modeData.amountOwed == nil and
            tonumber(minRoll) == 1 and tonumber(maxRoll) == self.db.global.game.wager) then
        self.session.modeData.amountOwed = tonumber(actualRoll)

        -- Since all players must have a recorded roll for the game to end, simply give players a default roll
        for i = 1, #self.session.players do
            self.session.players[i].roll = i
        end
    end
end

WoWGoldGambler.EXCHANGE.handleChatMessage = function(self, text, playerName, playerRealm)
    -- During this game mode, we continue listening to chat messages during the rolling phase
    -- Player 1 will use the chat to let us know when to stop cycling raid icons, determining the outcome
    if (self.session.modeData.firstPlayerName == playerName and self.session.modeData.loserName == nil and string.upper(text) == "STOP") then
        -- If Player 1 has sent the message "STOP", and we have not yet determined the outcome,
        -- stop cycling raid icons and use the current raid icon to determine the outcome
        self:cycleRaidIcon(false)

        local raidIcon = GetRaidTargetIndex("player");

        if (raidIcon == 1) then
            -- Star Outcome
            self.session.modeData.loserName = self.session.modeData.secondPlayerName
            self.session.modeData.amountOwed = self.db.global.game.wager
        else if (raidIcon == 2) then
            -- Circle Outcome
            self.session.modeData.amountOwed = 0
        else if (raidIcon == 3) then
            -- Diamond Outcome
            self.session.modeData.loserName = self.session.modeData.secondPlayerName
        else if (raidIcon == 7) then
            -- Cross Outcome
            self.session.modeData.loserName = self.session.modeData.firstPlayerName
        else if (raidIcon == 8) then
            -- Skull Outcome
            self.session.modeData.loserName = self.session.modeData.firstPlayerName
            self.session.modeData.amountOwed = self.db.global.game.wager 
        end
        
        -- If outcome does not require a roll for self.session.modeData.amountOwed, calculate results
        if (self.session.modeData.amountOwed ~= nil) then
            self:calculateResult()
        else
            SendChatMessage("It looks like " .. self.session.modeData.loserName .. " is feeling generous! ".. self.session.modeData.loserName .. ", /roll " .. self.db.global.game.wager .. " now to see how much you'll lose!", self.db.global.game.chatChannel)
        end
    end
end

WoWGoldGambler.EXCHANGE.calculateResult = function(self)
    -- Calculation logic for the Exchange game mode. The game may end in a tie if the Circle outcome was chosen.
    -- Winner: The winner is determined by the selected outcome
    -- Loser: The loser is determined by the selected outcome
    -- Payment Amount: Either the wager amount, or a rolled amount that is less than the wager
    local winners = {}
    local losers = {}

    if (self.session.modeData.firstPlayerName == self.session.modeData.loserName) then
        tinsert(winners, self.session.players[self.session.modeData.secondPlayerIndex])
        tinsert(losers, self.session.players[self.session.modeData.firstPlayerIndex])
    elseif (self.session.modeData.secondPlayerName == self.session.modeData.loserName) then
        tinsert(winners, self.session.players[self.session.modeData.firstPlayerIndex])
        tinsert(losers, self.session.players[self.session.modeData.secondPlayerIndex])
    else
        SendChatMessage("Aww, it looks like " .. self.session.modeData.firstPlayerName .. " and ".. self.session.modeData.secondPlayerName .. " have to exchange hugs!", self.db.global.game.chatChannel)
    end

    return {
        winners = winners,
        losers = losers,
        amountOwed = self.session.modeData.amountOwed
    }
end

-- Default Tie Resolution
WoWGoldGambler.EXCHANGE.detectTie = WoWGoldGambler.DEFAULT.detectTie