WoWGoldGambler = LibStub("AceAddon-3.0"):NewAddon("WoWGoldGambler", "AceConsole-3.0", "AceEvent-3.0")

-- GLOBAL VARS --
local gameStates = {
    "IDLE",
    "REGISTRATION",
    "ROLLING"
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
            chatChannel = chatChannels[1],
            houseCut = 0
        },
        stats = {
            player = {},
            aliases = {},
            house = 0
        },
    }
}

-- Initializes slash commands for the addon. Some of these will no longer be slash commands when a UI is implemented
local options = {
    name = "WoWGoldGambler",
    handler = WoWGoldGambler,
    type = 'group',
    args = {
        show = {
            name = "Show UI",
            desc = "Show the WoWGoldGambler UI",
            type = "execute",
            func = "drawUi"
        },
        sethousecut = {
            name = "Set House Cut",
            desc = "[amount] - Set the percentage (0% - 100%) of winnings taken by the house (ie. guild).",
            type = "input",
            func = "setHouseCut"
        },
        changechannel = {
            name = "Change Channel",
            desc = "Change the chat channel used by the addon",
            type = "execute",
            func = "changeChannel"
        },
        changemode = {
            name = "Change Game Mode",
            desc = "Change the game mode",
            type = "execute",
            func = "changeGameMode"
        },
        allstats = {
            name = "All Stats",
            desc = "Output all-time player stats to the chat channel",
            type = "execute",
            func = "allStats"
        },
        stats = {
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
        deletestat = {
            name = "Delete Stat",
            desc = "[player] - Permanently delete the stats for the given [player]",
            type = "input",
            set = "deleteStat"
        },
        resetstats = {
            name = "Reset Stats",
            desc = "Permanently deletes all existing stats",
            type = "execute",
            func = "resetStats"
        }
    }
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
            player = {},
            house = 0
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

function WoWGoldGambler:setWager(amount)
    -- Sets the game's wager amount to [amount]
    amount = tonumber(amount)

    if (amount ~= nil and amount > 0) then
        self.db.global.game.wager = amount
    end
end

function WoWGoldGambler:setHouseCut(_, amount)
    -- Sets the house cut to the given [amount]. The house cut is a percentage, so amount must be a number between 0 and 100
    amount = tonumber(amount)

    if (amount ~= nil and amount >= 0 and amount <= 100) then
        self.db.global.game.houseCut = amount
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
    elseif (self.session.state == gameStates[3]) then
        -- If a rolling phase is in progress, post the names of the players who have yet to roll in the chat channel
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
    -- If [maxValue] or [minValue] are nil, they are defaulted to appropriate values for the game mode
    if (maxAmount == nil) then
        if (self.db.global.game.mode == gameModes[2]) then
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
    local playerName, actualRoll, minRoll, maxRoll = strmatch(text, "^([^ ]+) .+ (%d+) %((%d+)-(%d+)%)%.?$")

    -- Perform game mode specific tasks for recording player rolls
    if (self.db.global.game.mode == gameModes[1]) then
        self:classicRecordRoll(playerName, actualRoll, minRoll, maxRoll)
    elseif (self.db.global.game.mode == gameModes[2]) then
        self:coinflipRecordRoll(playerName, actualRoll, minRoll, maxRoll)
    elseif (self.db.global.game.mode == gameModes[3]) then
        self:rouletteRecordRoll(playerName, actualRoll, minRoll, maxRoll)
    elseif (self.db.global.game.mode == gameModes[4]) then
        self:priceIsRightRecordRoll(playerName, actualRoll, minRoll, maxRoll)
    end

    -- If all registered players have rolled, calculate the result
    if (#self:checkPlayerRolls() == 0) then
        self:calculateResult()
    end
end

-- Game-End Functionality --

function WoWGoldGambler:calculateResult()
    -- Calculates the winners and losers of a session and the amount owed
    local result = {}

    if (self.db.global.game.mode == gameModes[1]) then
        result = self:classicCalculateResult()
    elseif (self.db.global.game.mode == gameModes[2]) then
        result = self:coinflipCalculateResult()
    elseif (self.db.global.game.mode == gameModes[3]) then
        result = self:rouletteCalculateResult()
    elseif (self.db.global.game.mode == gameModes[4]) then
        result = self:priceIsRightCalculateResult()
    else
        self:Print(self.db.global.game.mode .. " is not a valid game mode.")
        self.session.result = nil
        self:endGame()
    end

    if  (self.session.result == nil) then
        self.session.result = result
    else
        -- If the result is a tie-breaker result, only replace the portion of the result for which there was a tie. High-end ties are resolved first.
        if (#self.session.result.winners > 1) then
            if (#result.winners > 0) then
                self.session.result.winners = result.winners
            else
                self.session.result.winners = result.losers
            end
        elseif (#self.session.result.losers > 1) then
            if (#result.losers > 0) then
                self.session.result.losers = result.losers
            else
                self.session.result.losers = result.winners
            end
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
        tieBreakers = self.session.result.losers
    end

    if (#tieBreakers > 0) then
        -- If a tie is detected, set up the session for tie-breaking and continue listening for rolls.
        self.session.players = tieBreakers

        for i = 1, #self.session.players do
            self.session.players[i].roll = nil
        end

        -- Perform game-mode specific tasks when entering a tie-breaker
        if (self.db.global.game.mode == gameModes[2]) then
            self:coinflipDetectTie()
        elseif (self.db.global.game.mode == gameModes[3]) then
            self:rouletteDetectTie()
        elseif (self.db.global.game.mode == gameModes[4]) then
            self:priceIsRightDetectTie()
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
            local houseAmount = 0

            -- If a house cut is set, determine the amount owed to the house and adjust the amountOwed to the winner(s)
            if (self.db.global.game.houseCut > 0) then
                houseAmount = math.floor(self.session.result.amountOwed * (self.db.global.game.houseCut / 100))
                self.session.result.amountOwed = self.session.result.amountOwed - houseAmount
            end

            -- Notify players of the results and update player/house stats
            for i = 1, #self.session.result.losers do
                SendChatMessage(self.session.result.losers[i].name .. " owes " .. self:makeNameString(self.session.result.winners) .. " " .. self.session.result.amountOwed .. " gold!" , self.db.global.game.chatChannel)
                self:updatePlayerStat(self.session.result.losers[i].name, self.session.result.amountOwed * -1)

                if (self.db.global.game.houseCut > 0) then
                    SendChatMessage(self.session.result.losers[i].name .. " owes the guild bank " .. houseAmount .. " gold!" , self.db.global.game.chatChannel)
                    self.db.global.stats.house = self.db.global.stats.house + houseAmount
                    self.session.stats.house = self.session.stats.house + houseAmount
                end
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

function WoWGoldGambler:registerPlayer(playerName, playerRealm, playerRoll)
    -- Add a new player to the game if they are not already registered. [playerRoll] can optionally be provided to pre-record a roll for the player.

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
        roll = playerRoll
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
    -- Returns a list of the names of all registered players who have not rolled yet
    local playersToRoll = {}

    for i = 1, #self.session.players do
        if (self.session.players[i].roll == nil) then
            tinsert(playersToRoll, self.session.players[i].name)
        end
    end

    return playersToRoll
end