-- Default Functions for Game Modes --
WoWGoldGambler.DEFAULT = {}

WoWGoldGambler.DEFAULT.gameStart = function(self)
    -- Basic game start notification for most game modes
    self:ChatMessage("WoWGoldGambler: A new game has been started! Type 1 to join! (-1 to withdraw)")
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
    self:ChatMessage("Registration has ended. All players /roll " .. self.db.global.game.wager .. " now!")
end