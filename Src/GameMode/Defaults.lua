-- Default Functions for Game Modes --
WoWGoldGambler.DEFAULT = {}

WoWGoldGambler.DEFAULT.gameStart = function(self)
    -- Basic game start notification for most game modes
    SendChatMessage("WoWGoldGambler: A new game has been started! Type 1 to join! (-1 to withdraw)" , self.db.global.game.chatChannel)

    -- TODO: REMOVE ME
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