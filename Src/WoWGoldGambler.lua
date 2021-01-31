WoWGoldGambler = LibStub("AceAddon-3.0"):NewAddon("WoWGoldGambler", "AceConsole-3.0", "AceEvent-3.0")

-- GLOBAL VARS --
local gameStates = {
    "IDLE",
    "REGISTRATION",
    "ROLLING",
    "TIE BREAKER"
}

local gameModes = {
    "CLASSIC",
    "COINFLIP",
    "ROULETTE",
    "PRICE IS RIGHT"
}

local chatChannels = {
    "PARTY",
    "RAID",
    "GUILD"
}

-- Defaults for the DB
local defaults = {
    global = {
        game = {
            mode = gameModes[1],
            wager = 1000,
            chatChannel = chatChannels[1]
        },
        stats = {
            player = {},
            aliases = {}
        },
    }
}

-- Initializes slash commands for the addon. Some of these will no longer be slash commands when a UI is implemented
local options = {
    name = "WoWGoldGambler",
    handler = WoWGoldGambler,
    type = 'group',
    args = {
        startgame = {
            name = "Start Game",
            desc = "Start the registration phase of a game session",
            type = "execute",
            func = "startGame"
        },
        startrolls = {
            name = "Start Rolls",
            desc = "Start the rolling phase of a game session",
            type = "execute",
            func = "startRolls"
        },
        cancelgame = {
            name = "Cancel Game",
            desc = "Cancel the currently running game session and void out any results",
            type = "execute",
            func = "cancelGame"
        },
        changechannel = {
            name = "Change Channel",
            desc = "Change the chat channel used by the addon",
            type = "execute",
            func = "changeChannel"
        },
        changegamemode = {
            name = "Change Game Mode",
            desc = "Change the game mode",
            type = "execute",
            func = "changeGameMode"
        },
        setwager = {
            name = "Set Wager",
            desc = "[amount] - Set the wager amount to [amount]",
            type = "input",
            set = "setWager"
        },
        enterme = {
            name = "Enter Me",
            desc = "Register the dealer for a game by entering 1 in chat",
            type = "execute",
            func = "enterMe"
        },
        rollme = {
            name = "Roll Me",
            desc = "Do a /roll for the dealer",
            type = "execute",
            func = "rollMe"
        },
        allstats = {
            name = "All Stats",
            desc = "Output all-time player stats to the chat channel",
            type = "execute",
            func = "allStats"
        },
        sessionstats = {
            name = "Session Stats",
            desc = "Output player stats from the current session to the chat channel",
            type = "execute",
            func = "sessionStats"
        },
        joinstats = {
            name = "Join Stats",
            desc = "[main] [alt] - Merge the stats of [alt] into [main]",
            type = "input",
            set = "joinStats"
        },
        unjoinstats = {
            name = "Unjoin Stats",
            desc = "[alt] - Unmerge the stats of [alt] from whomever they were merged with",
            type = "input",
            set = "unjoinStats"
        },
        updatestat = {
            name = "Update Stat",
            desc = "[player] [amount] - Add [amount] to [player]'s stats (use negative numbers to subtract)",
            type = "input",
            set = "updateStat"
        },
        resetstats = {
            name = "Reset Stats",
            desc = "Permanently deletes all existing stats",
            type = "execute",
            func = "resetStats"
        }
    },
}

-- Initialization --

function WoWGoldGambler:OnInitialize()
    -- Sets up the DB and slash command options when the addon is loaded
    self.db = LibStub("AceDB-3.0"):New("WoWGoldGamblerDB", defaults, true)
    LibStub("AceConfig-3.0"):RegisterOptionsTable("WoWGoldGambler", options, {"wowgoldgambler", "wgg"})

    -- Stores all session-related game data. Not to be stored in the DB
    self.session = {
        state = gameStates[1],
        dealer = {
            name = UnitName("player"),
            roll = nil
        },
        players = {},
        result = nil,
        stats = {
            player = {}
        }
    }
end

-- Slash Command Handlers --

function WoWGoldGambler:changeChannel(info)
    -- Increment the chat channel to be used by the addon
    if (self.db.global.game.chatChannel == chatChannels[1]) then
        self.db.global.game.chatChannel = chatChannels[2]
    elseif (self.db.global.game.chatChannel == chatChannels[2]) then
        self.db.global.game.chatChannel = chatChannels[3]
    else
        self.db.global.game.chatChannel = chatChannels[1]
    end

    self:Print("WoWGoldGambler: New chat channel is " .. self.db.global.game.chatChannel)
end

function WoWGoldGambler:changeGameMode(info)
    -- Increment the game mode to be used by the addon
    if (self.db.global.game.mode == gameModes[1]) then
        self.db.global.game.mode = gameModes[2]
    elseif (self.db.global.game.mode == gameModes[2]) then
        self.db.global.game.mode = gameModes[3]
    elseif (self.db.global.game.mode == gameModes[3]) then
        self.db.global.game.mode = gameModes[4]
    else
        self.db.global.game.mode = gameModes[1]
    end

    self:Print("WoWGoldGambler: New game mode is " .. self.db.global.game.mode)
end

function WoWGoldGambler:setWager(info, amount)
    -- Sets the game's wager amount to [amount]
    amount = tonumber(amount)

    if (amount ~= nil and amount > 0) then
        self.db.global.game.wager = amount
        self:Print("New wager amount is " .. tostring(amount))
    end
end

function WoWGoldGambler:startGame(info)
    -- Starts a new game session for registration when there is no session in progress
    if (self.session.state == gameStates[1]) then
        -- Start listening to chat messages
        if (self.db.global.game.chatChannel == chatChannels[1]) then
            self:RegisterEvent("CHAT_MSG_PARTY", "handleChatMessage")
            self:RegisterEvent("CHAT_MSG_PARTY_LEADER", "handleChatMessage")
        elseif (self.db.global.game.chatChannel == chatChannels[2]) then
            self:RegisterEvent("CHAT_MSG_RAID", "handleChatMessage")
            self:RegisterEvent("CHAT_MSG_RAID_LEADER", "handleChatMessage")
        else
            self:RegisterEvent("CHAT_MSG_GUILD", "handleChatMessage")
        end

        -- Change the game state to REGISTRATION
        self.session.state = gameStates[2]

        -- Perform game-mode specific tasks required to start the game
        if (self.db.global.game.mode == gameModes[3]) then
            self:rouletteGameStart()
        else
            self:classicGameStart()
        end

        -- Inform players of the selected Game Mode and Wager
        SendChatMessage("Game Mode - " .. self.db.global.game.mode .. " - Wager - " .. self.db.global.game.wager, self.db.global.game.chatChannel)
    else
        self:Print("WoWGoldGambler: A game session has already been started!")
    end
end

function WoWGoldGambler:enterMe()
    -- Post a '1' in the chat channel for the dealer to register for a game
    SendChatMessage("1", self.db.global.game.chatChannel)
end

function WoWGoldGambler:startRolls(info)
    -- Ends the registration phase of the currently running session and begins the rolling phase
    if (self.session.state == gameStates[2]) then
        -- At least two players are required to play
        if (#self.session.players > 1) then
            -- Stop listening to chat messages
            self:UnregisterEvent("CHAT_MSG_PARTY")
            self:UnregisterEvent("CHAT_MSG_PARTY_LEADER")
            self:UnregisterEvent("CHAT_MSG_RAID")
            self:UnregisterEvent("CHAT_MSG_RAID_LEADER")
            self:UnregisterEvent("CHAT_MSG_GUILD")

            -- Start listening to system messages to recieve rolls
            self:RegisterEvent("CHAT_MSG_SYSTEM", "handleSystemMessage")

            -- Change the game state to ROLLING
            self.session.state = gameStates[3]

            -- Perform game-mode specific tasks required to start the rolling phase
            if (self.db.global.game.mode == gameModes[1]) then
                self:classicStartRolls()
            elseif (self.db.global.game.mode == gameModes[2]) then
                self:coinflipStartRolls()
            elseif (self.db.global.game.mode == gameModes[3]) then
                self:rouletteStartRolls()
            elseif (self.db.global.game.mode == gameModes[4]) then
                self:priceIsRightStartRolls()
            end
        else
            SendChatMessage("Not enough players have registered to play!" , self.db.global.game.chatChannel)
        end
    elseif (self.session.state == gameStates[3] or self.session.state == gameStates[4]) then
        -- If a rolling phase or tie breaker phase is in progress, post the names of the players who have yet to roll in the chat channel
        local playersToRoll = self:checkPlayerRolls(self.session.players)

        for i = 1, #playersToRoll do
            SendChatMessage(playersToRoll[i] .. " still needs to roll!" , self.db.global.game.chatChannel)
        end
    else
        self:Print("WoWGoldGambler: Player registration must be done before rolling can start!")
    end
end

function WoWGoldGambler:rollMe(info, maxAmount, minAmount)
    -- Automatically performs a roll between [minAmount] and [maxAmount] for the dealer.
    -- If [maxValue] or [minValue] are nil, they are defaulted to appropriate values for the game mode and game state
    if (maxAmount == nil) then
        if (self.session.state == gameStates[4]) then
            maxAmount = 100
        elseif (self.db.global.game.chatChannel == gameModes[2]) then
            maxAmount = 2
        else
            maxAmount = self.db.global.game.wager
        end
    end

    if (minAmount == nil) then
        minAmount = 1
    end

    RandomRoll(minAmount, maxAmount)
end

function WoWGoldGambler:cancelGame(info)
    -- Terminates the currently running game session, voiding out any result
    if (self.session.state ~= gameStates[1]) then
        SendChatMessage("Game session has been canceled by " .. self.session.dealer.name , self.db.global.game.chatChannel)
        self.session.result = nil
        self:endGame()
    end
end

-- Event Handlers --

function WoWGoldGambler:handleChatMessage(_, text, playerName)
    -- Parses chat messages recieved by one of the chat Event Listeners to record player registration
    if (self.session.state == gameStates[2]) then
        local playerName, playerRealm = strsplit("-", playerName)

        -- All game modes except roulette use the same registration rules
        if (self.db.global.game.mode == gameModes[3]) then
            self:rouletteRegister(text, playerName, playerRealm)
        else
            self:classicRegister(text, playerName, playerRealm)
        end
    end
end

function WoWGoldGambler:handleSystemMessage(_, text)
    -- Parses system messages recieved by the Event Listener to find and record player rolls
    local players = self.session.players
    local playerName, actualRoll, minRoll, maxRoll = strmatch(text, "^([^ ]+) .+ (%d+) %((%d+)-(%d+)%)%.?$")

    if (self.session.state == gameStates[4]) then
        players = self.session.result.tieBreakers
    end

    -- Perform game mode specific tasks for recording player rolls
    if (self.db.global.game.mode == gameModes[1]) then
        self:classicRecordRoll(players, playerName, actualRoll, minRoll, maxRoll)
    elseif (self.db.global.game.mode == gameModes[2]) then
        self:coinflipRecordRoll(players, playerName, actualRoll, minRoll, maxRoll)
    elseif (self.db.global.game.mode == gameModes[3]) then
        self:rouletteRecordRoll(playerName, actualRoll, minRoll, maxRoll)
    elseif (self.db.global.game.mode == gameModes[4]) then
        self:priceIsRightRecordRoll(players, playerName, actualRoll, minRoll, maxRoll)
    end

    -- If all registered players have rolled, calculate the result
    if (#self:checkPlayerRolls(players) == 0) then
        self:calculateResult(players)
    end
end

-- Game-End Functionality --

function WoWGoldGambler:calculateResult(players)
    -- Calculates the winners and losers of a session and the amount owed
    local result = {}

    if (self.db.global.game.mode == gameModes[1]) then
        result = self:classicCalculateResult(players)
    elseif (self.db.global.game.mode == gameModes[2]) then
        result = self:coinflipCalculateResult(players)
    elseif (self.db.global.game.mode == gameModes[3]) then
        result = self:rouletteCalculateResult(players)
    elseif (self.db.global.game.mode == gameModes[4]) then
        result = self:priceIsRightCalculateResult(players)34
    else
        self:Print(self.db.global.game.mode .. " is not a valid game mode.")
        self.session.result = nil
        self:endGame()
    end

    if (self.session.state == gameStates[3]) then
        self.session.result = result
    -- If the result is a tie-breaker result, only replace the portion of the result for which there was a tie. High-end ties are resolved first.
    elseif  (self.session.state == gameStates[4]) then
        if (#self.session.result.winners > 1) then
            self.session.result.winners = result.winners
        elseif (#self.session.result.losers > 1) then
            self.session.result.losers = result.losers
        end
    end

    self:detectTie()
end

function WoWGoldGambler:detectTie()
    -- Detects when there is a tie on either the winner or loser side. High-end ties are decided first.
    -- Ties will not be resolved if there are no winners or no losers (resolving the tie would be pointless)
    local tieBreakers = {}

    if (#self.session.result.winners > 1 and #self.session.result.losers ~= 0) then
        -- High End Tie Breaker
        tieBreakers = self.session.result.winners
    elseif (#self.session.result.losers > 1 and #self.session.result.winners ~= 0) then
        -- Low End Tie Breaker
        tieBreakers = self.session.result.winners
    end

    if (#tieBreakers > 0) then
        -- If a tie is detected, set up the session for tie-breaing and continue listening for rolls.
        self.session.state = gameStates[4]
        self.session.result.tieBreakers = tieBreakers

        for i = 1, #self.session.result.tieBreakers do
            self.session.result.tieBreakers[i].roll = nil
        end

        -- Perform game-mode specific tasks required to enter the TIE BREAKER phase
        if (self.db.global.game.mode == gameModes[2]) then
            self:coinflipDetectTie()
        elseif (self.db.global.game.mode == gameModes[3]) then
            self:rouletteDetectTie()
        else
            self:classicDetectTie()
        end
    else
         -- If a tie is not detected, the game is ended
        self:endGame()
    end
end

function WoWGoldGambler:endGame()
    -- Posts the result of the game session to the chat channel and updates stats before terminating the game session
    if (self.session.result ~= nil) then
        if (#self.session.result.losers > 0 and #self.session.result.winners > 0) then
            for i = 1, #self.session.result.losers do
                SendChatMessage(self.session.result.losers[i].name .. " owes " .. self:makeNameString(self.session.result.winners) .. " " .. self.session.result.amountOwed .. " gold!" , self.db.global.game.chatChannel)
                self:updatePlayerStat(self.session.result.losers[i].name, self.session.result.amountOwed * -1)
            end
            
            for i = 1, #self.session.result.winners do
                self:updatePlayerStat(self.session.result.winners[i].name, self.session.result.amountOwed * #self.session.result.losers)
            end
        else
            SendChatMessage("Looks like nobody wins this round!" , self.db.global.game.chatChannel)
        end
    end

    -- Restore IDLE state
    self:UnregisterEvent("CHAT_MSG_PARTY")
    self:UnregisterEvent("CHAT_MSG_PARTY_LEADER")
    self:UnregisterEvent("CHAT_MSG_RAID")
    self:UnregisterEvent("CHAT_MSG_RAID_LEADER")
    self:UnregisterEvent("CHAT_MSG_GUILD")
    self:UnregisterEvent("CHAT_MSG_SYSTEM")
    self.session.state = gameStates[1]
    self.session.players = {}
    self.session.result = nil
    self.session.dealer.roll = nil
end

-- Helper Functions --

function WoWGoldGambler:makeNameString(players)
    -- Given a list of players, returns a string of all player names concatenated together with commas and "and"
    local nameString = players[1].name

    if (#players > 1) then
        for i = 2, #players do
            if (i == #players) then
                nameString = nameString .. " and " .. players[i].name
            else
                nameString = nameString .. ", " .. players[i].name
            end
        end
    end

    return nameString
end

function WoWGoldGambler:registerPlayer(playerName, playerRealm)
    -- Ignore entry if player is already entered
    for i = 1, #self.session.players do
        if (self.session.players[i].name == playerName and self.session.players[i].realm == playerRealm) then
            return
        end
    end

    -- If the player is not already entered, create a new player entry for them
    local newPlayer = {
        name = playerName,
        realm = playerRealm,
        roll = nil
    }

    tinsert(self.session.players, newPlayer)
end

function WoWGoldGambler:unregisterPlayer(playerName, playerRealm)
    -- Remove the player from the currently running game session if they have previously entered
    for i = 1, #self.session.players do
        if (self.session.players[i].name == playerName and self.session.players[i].realm == playerRealm) then
            tremove(self.session.players, i)
        end
    end
end

function WoWGoldGambler:checkPlayerRolls(players)
    -- Returns a list of the names of all registered or tie breaker players who have not rolled yet
    local playersToRoll = {}

    for i = 1, #players do
        if (players[i].roll == nil) then
            tinsert(playersToRoll, players[i].name)
        end
    end

    return playersToRoll
end