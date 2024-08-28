-- Default Functions for Game Modes --
WoWGoldGambler.DEFAULT = {}

WoWGoldGambler.DEFAULT.gameStart = function(self)
    -- Basic game start notification for most game modes
    SendChatMessage("WoWGoldGambler: A new game has been started! Type 1 to join! (-1 to withdraw)" , self.db.global.game.chatChannel)

    -- TODO: Remove me
    local newPlayer = {
        name = "Tester",
        realm = "Ravencrest",
        roll = 1,
        pokerHand = {
            type = "High Card",
            cardRanks = {1}
        }
    }

    tinsert(self.session.players, newPlayer)

    local newPlayer2 = {
        name = "Tester2",
        realm = "Ravencrest",
        roll = 2,
        pokerHand = {
            type = "High Card",
            cardRanks = {2}
        }
    }

    tinsert(self.session.players, newPlayer2)
end

WoWGoldGambler.DEFAULT.register = function(self, text, playerName, playerRealm)
    -- Basic registration for most game modes
    if (text == "1") then
        self:registerPlayer(playerName, playerRealm)
    elseif (text == "-1") then
        self:unregisterPlayer(playerName, playerRealm)
    end
end

WoWGoldGambler.DEFAULT.startRolls = function(self)
    -- Informs players that the registration phase has ended
    SendChatMessage("Registration has ended. All players /roll " .. self.db.global.game.wager .. " now!" , self.db.global.game.chatChannel)
end

WoWGoldGambler.DEFAULT.detectTie = function(self)
    -- Ties are assumed to be allowed unless a game mode implements its own tie resolution
    self:endGame()
end

WoWGoldGambler.DEFAULT.setRecords = function(self)
    -- Updates game mode agnostic records and reports when records are broken
    self:gamesPlayedRecord()
    self:biggestWagerRecord()
    self:biggestWinRecord()
end

-- Implementation for records

function WoWGoldGambler:gamesPlayedRecord()
    if (self.db.global.stats.records["Games Played"] == nil) then
        self.db.global.stats.records["Games Played"] = {
            record = 1
        }
    else
        self.db.global.stats.records["Games Played"].record = self.db.global.stats.records["Games Played"].record + 1
    end
end

function WoWGoldGambler:biggestWagerRecord()
    if (self.db.global.stats.records["Biggest Wager"] == nil or
        self.db.global.game.wager > self.db.global.stats.records["Biggest Wager"].record) then

        self.db.global.stats.records["Biggest Wager"] = {
            record = self.db.global.game.wager,
            holders = self:makeNameString(self.session.players)
        }

        SendChatMessage("New Record! " .. self:formatInt(self.db.global.game.wager) .. "g is the most money I've ever seen wagered!", self.db.global.game.chatChannel)
    end
end

function WoWGoldGambler:biggestWinRecord()
    local amountWon = (self.session.result.amountOwed * #self.session.result.losers)

    if (self.db.global.stats.records["Biggest Win"] == nil or
        amountWon > self.db.global.stats.records["Biggest Win"].record) then

        self.db.global.stats.records["Biggest Win"] = {
            record = amountWon,
            holders = self:makeNameString(self.session.result.winners)
        }

        SendChatMessage("New Record! " .. self:formatInt(self.session.result.amountOwed) .. "g is the most money I've ever seen won in a single wager!", self.db.global.game.chatChannel)
    end
end