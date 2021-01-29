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
    "BIG TWO",
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
        endgame = {
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
                self:bigTwoStartRolls()
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
        local playersToRoll = self:checkPlayerRolls()

        for i = 1, #playersToRoll do
            SendChatMessage(playersToRoll[i] .. " still needs to roll!" , self.db.global.game.chatChannel)
        end
    else
        self:Print("WoWGoldGambler: Player registration must be done before rolling can start!")
    end
end

function WoWGoldGambler:rollMe(info, maxAmount, minAmount)
    -- Automatically performs a roll between [minAmount] and [maxAmount] for the dealer.
    -- If no values are given, they are defaulted to 1 and the wager (or 100 for tie breakers)
    if (maxAmount == nil) then
        if (self.session.state == gameStates[4]) then
            maxAmount = 100
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
    local playerName, actualRoll, minRoll, maxRoll = strmatch(text, "^([^ ]+) .+ (%d+) %((%d+)-(%d+)%)%.?$")

    if (self.session.state == gameStates[3]) then
        -- Perform game mode specific tasks for recording player rolls
        if (self.db.global.game.mode == gameModes[1]) then
            self:classicRecordRoll(playerName, actualRoll, minRoll, maxRoll)
        elseif (self.db.global.game.mode == gameModes[2]) then
            self:bigTwoRecordRoll(playerName, actualRoll, minRoll, maxRoll)
        elseif (self.db.global.game.mode == gameModes[3]) then
            self:rouletteRecordRoll(playerName, actualRoll, minRoll, maxRoll)
        elseif (self.db.global.game.mode == gameModes[4]) then
            self:priceIsRightRecordRoll(playerName, actualRoll, minRoll, maxRoll)
        end
    elseif (self.session.state == gameStates[4]) then
        self:tiebreakerRecordRoll(playerName, actualRoll, minRoll, maxRoll)
    end
end

-- Game-End Functionality --

function WoWGoldGambler:calculateResult()
    -- Calculates the winners and losers of a session and the amount owed
    self.session.result = {
        winners = {},
        losers = {},
        amountOwed = 0
    }

    if (self.db.global.game.mode == gameModes[1]) then
        self:classicCalculateResult()
    elseif (self.db.global.game.mode == gameModes[2]) then
        self:bigTwoCalculateResult()
    elseif (self.db.global.game.mode == gameModes[3]) then
        self:rouletteCalculateResult()
    elseif (self.db.global.game.mode == gameModes[4]) then
        self:priceIsRightCalculateResult()
    else
        self:Print(self.db.global.game.mode .. " is not a valid game mode.")
        self.session.result = nil
        self:endGame()
    end

    self:detectTie()
end

function WoWGoldGambler:detectTie()
    -- Detects when there is a tie on either the winner or loser side. Multiple winners/losers is allowed in the Roulette game mode.
    -- If a tie is detected, set the game state to TIE BREAKER and continue listening for rolls. If a tie is not detected, the game is ended
    if (#self.session.result.winners > 1 and self.db.global.game.mode ~= gameModes[3]) then
        -- High End Tie Breaker
        SendChatMessage("High end tie breaker! " .. self:makeNameString(self.session.result.winners) .. " /roll 100 now!", self.db.global.game.chatChannel)
        self.session.state = gameStates[4]
        self.session.result.tieBreakers = {}

        for i = 1, #self.session.result.winners do
            self.session.result.tieBreakers[i] = self.session.result.winners[i]
            self.session.result.tieBreakers[i].roll = nil

            -- DEBUG: REMOVE ME
            if (self.session.result.tieBreakers[i].name == "Tester2") then
                self.session.result.tieBreakers[i].roll = 2
            end
        end
    elseif (#self.session.result.losers > 1 and self.db.global.game.mode ~= gameModes[3]) then
        -- Low End Tie Breaker
        SendChatMessage("Low end tie breaker! " .. self:makeNameString(self.session.result.losers) .. " /roll 100 now!", self.db.global.game.chatChannel)
        self.session.state = gameStates[4]
        self.session.result.tieBreakers = {}
        
        for i = 1, #self.session.result.losers do
            self.session.result.tieBreakers[i] = self.session.result.losers[i]
            self.session.result.tieBreakers[i].roll = nil

            -- DEBUG: REMOVE ME
            if (self.session.result.tieBreakers[i].name == "Tester1") then
                self.session.result.tieBreakers[i].roll = 1
            end
        end
    else
        self:endGame()
    end
end

function WoWGoldGambler:tiebreakerRecordRoll(playerName, actualRoll, minRoll, maxRoll)
    -- If a tie-breaker player made a 1-100 roll and has not yet made a tie breaker roll, record the tie breaker roll
    if (tonumber(minRoll) == 1 and tonumber(maxRoll) == 100) then
        for i = 1, #self.session.result.tieBreakers do
            if (self.session.result.tieBreakers[i].name == playerName and self.session.result.tieBreakers[i].roll == nil) then
                self.session.result.tieBreakers[i].roll = tonumber(actualRoll)
            end
        end
    end

    -- If all tie breaker players have rolled, attempt to resolve the tie
    if (#self:checkPlayerRolls() == 0) then
        self:resolveTie()
    end
end

function WoWGoldGambler:resolveTie()
    -- Tie breakers are always won and lost by the players who rolled the highest and lowest on a 100 roll
    -- Additional tie breaker rounds are possible if a tie still exists after resolution
    local tieWinners = {self.session.result.tieBreakers[1]}
    local tieLosers = {self.session.result.tieBreakers[1]}

    -- Determine which tied players had the highest and lowest rolls
    for i = 2, #self.session.result.tieBreakers do
        -- New loser
        if (self.session.result.tieBreakers[i].roll < tieLosers[1].roll) then
            tieLosers = {self.session.result.tieBreakers[i]}
        -- New winner
        elseif (self.session.result.tieBreakers[i].roll > tieWinners[1].roll) then
            tieWinners = {self.session.result.tieBreakers[i]}
        else
            -- Handle ties. Due to the way we initialize tieWinners and tieLosers, it's possible for both of these to be true
            if (self.session.result.tieBreakers[i].roll == tieLosers[1].roll) then
                tinsert(tieLosers, self.session.result.tieBreakers[i])
            end
            
            if (self.session.result.tieBreakers[i].roll == tieWinners[1].roll) then
                tinsert(tieWinners, self.session.result.tieBreakers[i])
            end
        end
    end

    -- Replace the result winners or losers with the tie result. High end ties are always resolved first.
    if (#self.session.result.winners > 1) then
        self.session.result.winners = tieWinners
    elseif (#self.session.result.losers > 1) then
        self.session.result.losers = tieLosers
    end

    -- Check the updated results for additional ties
    self:detectTie()
end

function WoWGoldGambler:endGame(info)
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

function WoWGoldGambler:checkPlayerRolls()
    -- Returns a list of the names of all registered or tie breaker players who have not rolled yet
    local players = self.session.players
    local playersToRoll = {}

    if (self.session.state == gameStates[4]) then
        players = self.session.result.tieBreakers
    end

    for i = 1, #players do
        if (players[i].roll == nil) then
            tinsert(playersToRoll, players[i].name)
        end
    end

    return playersToRoll
end