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

-- Stores all session-related game data. Not to be stored in the DB
local session = {
    state = gameStates[1],
    dealer = nil,
    players = {},
    result = nil,
    stats = {
        player = {}
    }
}

-- Defaults for the DB, which stores game data that should persist between sessions
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
            desc = "Change the chat channel to the next one in the list",
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
            desc = "Change the wager amount to a given amount",
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
            desc = "Output all player stats to the chat channel",
            type = "execute",
            func = "allStats"
        },
        sessionStats = {
            name = "Session Stats",
            desc = "Output player stats from the current session to the chat channel",
            type = "execute",
            func = "sessionStats"
        },
        joinstats = {
            name = "Join Stats",
            desc = "Merge the stats of two given players",
            type = "input",
            set = "joinStats"
        },
        unjoinstats = {
            name = "Unjoin Stats",
            desc = "Un-merge the stats of two given players",
            type = "input",
            set = "unjoinStats"
        },
        updateStat = {
            name = "Update Stat",
            desc = "Manually add the given amount to a given player's stats (use negative numbers to subtract)",
            type = "input",
            set = "updatePlayerStat" -- Make another function which accepts info, playerName, amount and tonumber's amount
        },
        resetstats = {
            name = "Reset Stats",
            desc = "Delete all existing stats",
            type = "execute",
            func = "resetStats"
        }
    },
}

-- Initialization --

function WoWGoldGambler:OnInitialize()
    -- Sets up the DB and slash options when the addon is loaded
    self.db = LibStub("AceDB-3.0"):New("WoWGoldGamblerDB", defaults, true)
    LibStub("AceConfig-3.0"):RegisterOptionsTable("WoWGoldGambler", options, {"wowgoldgambler", "wgg"})
    session.dealer = UnitName("player")
end

-- Slash Command Handlers --

function WoWGoldGambler:startGame(info)
    -- Starts a new game session for registration when there is no session in progress
    if (session.state == gameStates[1]) then
        SendChatMessage("WoWGoldGambler: A new game has been started! Type 1 to join! (-1 to withdraw)" , self.db.global.game.chatChannel)
        SendChatMessage("Game Mode - " .. self.db.global.game.mode .. " - Wager - " .. self.db.global.game.wager, self.db.global.game.chatChannel)

        if (self.db.global.game.chatChannel == chatChannels[1]) then
            self:RegisterEvent("CHAT_MSG_PARTY")
            self:RegisterEvent("CHAT_MSG_PARTY_LEADER")
        elseif (self.db.global.game.chatChannel == chatChannels[2]) then
            self:RegisterEvent("CHAT_MSG_RAID")
            self:RegisterEvent("CHAT_MSG_RAID_LEADER")
        else
            self:RegisterEvent("CHAT_MSG_GUILD")
        end

        session.state = gameStates[2]

        -- DEBUG: REMOVE ME
        tinsert(session.players, {name = "Tester1", realm = "Tester", roll = 1})
        tinsert(session.players, {name = "Tester2", realm = "Tester", roll = 2})
    else
        self:Print("WoWGoldGambler: A game session has already been started!")
    end
end

function WoWGoldGambler:startRolls(info)
    -- Ends the registration phase of the currently running session and begins the rolling phase
    if (session.state == gameStates[2]) then
        -- At least two players are required to play
        if (#session.players > 1) then
            SendChatMessage("Registration has ended. All players /roll " .. self.db.global.game.wager .. " now!" , self.db.global.game.chatChannel)

            -- Stop listening to chat messages
            self:UnregisterEvent("CHAT_MSG_PARTY")
            self:UnregisterEvent("CHAT_MSG_PARTY_LEADER")
            self:UnregisterEvent("CHAT_MSG_RAID")
            self:UnregisterEvent("CHAT_MSG_RAID_LEADER")
            self:UnregisterEvent("CHAT_MSG_GUILD")

            -- Start listening to system messages to recieve rolls
            self:RegisterEvent("CHAT_MSG_SYSTEM")

            session.state = gameStates[3]
        else
            SendChatMessage("Not enough players have registered to play!" , self.db.global.game.chatChannel)
        end
    elseif (session.state == gameStates[3] or session.state == gameStates[4]) then
        -- If a rolling phase or tie breaker phase is in progress, post the names of the players who have yet to roll in the chat channel
        local playersToRoll = self:checkPlayerRolls()

        for i = 1, #playersToRoll do
            SendChatMessage(playersToRoll[i] .. " still needs to roll!" , self.db.global.game.chatChannel)
        end
    else
        self:Print("WoWGoldGambler: Player registration must be done before rolling can start!")
    end
end

function WoWGoldGambler:cancelGame(info)
    -- Terminates the currently running game session, voiding out any result
    if (session.state ~= gameStates[1]) then
        SendChatMessage("Game session has been canceled by " .. session.dealer , self.db.global.game.chatChannel)
        session.result = nil
        self:endGame()
    end
end

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
    -- Sets the game's wager amount to the given amount
    amount = tonumber(amount)

    if (amount ~= nil and amount > 0) then
        self.db.global.game.wager = amount
        self:Print("New wager amount is " .. tostring(amount))
    end
end

function WoWGoldGambler:rollMe(info, maxAmount, minAmount)
    -- Automatically performs a roll between the given values for the dealer.
    -- If no values are given, they are defaulted to 1 and the wager (or 100 for tie breakers)
    if (maxAmount == nil) then
        if (session.state == gameStates[4]) then
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

function WoWGoldGambler:enterMe()
    -- Post a '1' in the chat channel for the dealer to register for a game
    SendChatMessage("1", self.db.global.game.chatChannel)
end

function WoWGoldGambler:allStats()
    -- Post all player stats in the db to the chat channel
    WoWGoldGambler:printStats()
end

function WoWGoldGambler:sessionStats()
    -- Post all player stats in the db to the chat channel
    WoWGoldGambler:printStats(true)
end

function WoWGoldGambler:joinStats(info, newMain, newAlt)
    -- Create an alias for a player, allowing them to play on multiple characters and have their stats tracked under one name
    for main, _ in pairs(#self.db.global.stats.aliases) do
        -- Check all aliases for all mains to ensure newAlt is not already associated with a main
        for i = 1, #self.db.global.stats.aliases[main] do
            if (self.db.global.stats.aliases[main][i] == newAlt) then
                self:Print("WoWGoldGambler: Unjoining " .. newAlt .. " from " .. main .. " so it can be joined with " .. newMain .. " instead.")
                self:unjoinStats(main, newAlt)
            elseif (self.db.global.stats.aliases[main][i] == newMain) then
                self:Print("WoWGoldGambler: Joining " .. newAlt .. " to " .. main .. " instead, as it is already joined with " .. newMain)
                newMain = main
            end
        end
    end

    -- Add an alias entry for newMain if one does not already exist
    if (self.db.global.stats.aliases[newMain] == nil) then
        self.db.global.stats.aliases[newMain] = {}
    end

    -- Add newAlt as an alias for newMain
    tinsert(self.db.global.stats.aliases[newMain], newAlt)

    -- If newAlt previously had aliases of its own, add them as aliases for newMain before removing them for newAlt
    if (self.db.global.stats.aliases[newAlt] ~= nil) then
        for i = 1, #self.db.global.stats.aliases[newAlt] do
            tinsert(self.db.global.stats.aliases[newMain], self.db.global.stats.aliases[newAlt][i])
        end

        self.db.global.stats.aliases[newAlt] = nil
    end
end

function WoWGoldGambler:unjoinStats(oldMain, oldAlt)
    -- TODO
end

function WoWGoldGambler:resetStats()
    -- Deletes all stats!
    self.db.global.stats = {
        player = {}
    }

    session.stats = {
        player = {}
    }
end

-- Event Handlers --
function WoWGoldGambler:CHAT_MSG_PARTY(channelName, text, playerName)
    -- Listens to the PARTY channel for player registration
    self:handleChatMessage(channelName, text, playerName)
end

function WoWGoldGambler:CHAT_MSG_PARTY_LEADER(channelName, text, playerName)
    -- Listens to the PARTY channel for player registration from the party leader
    self:handleChatMessage(channelName, text, playerName)
end

function WoWGoldGambler:CHAT_MSG_RAID(channelName, text, playerName)
    -- Listens to the RAID channel for player registration
    self:handleChatMessage(channelName, text, playerName)
end

function WoWGoldGambler:CHAT_MSG_RAID_LEADER(channelName, text, playerName)
    -- Listens to the RAID channel for player registration from the raid leader
    self:handleChatMessage(channelName, text, playerName)
end

function WoWGoldGambler:CHAT_MSG_GUILD(channelName, text, playerName)
    -- Listens to the GUILD channel for player registration
    self:handleChatMessage(channelName, text, playerName)
end

function WoWGoldGambler:CHAT_MSG_SYSTEM(channelName, text)
    -- Listens to system events in the chat to keep track of user rolls
    self:handleSystemMessage(channelName, text)
end

-- Implementation Functions --

function WoWGoldGambler:handleChatMessage(channelName, text, playerName)
    -- Parses chat messages recieved by one of the chat Event Listeners to record player registration
    if (session.state == gameStates[2]) then
        local playerName, playerRealm = strsplit("-", playerName)

        if (text == "1") then
            -- Ignore entry if player is already entered
            for i = 1, #session.players do
                if (session.players[i].name == playerName and session.players[i].realm == playerRealm) then
                    return
                end
            end

            -- If the player is not already entered, create a new player entry for them
            local newPlayer = {
                name = playerName,
                realm = playerRealm,
                roll = nil
            }

            tinsert(session.players, newPlayer)
        elseif (text == "-1") then
            -- Remove the player if they have previously entered
            for i = 1, #session.players do
                if (session.players[i].name == playerName and session.players[i].realm == playerRealm) then
                    tremove(session.players, i)
                end
            end
        end
    end
end

function WoWGoldGambler:handleSystemMessage(channelName, text)
    -- Parses system messages recieved by the Event Listener to find and record player rolls
    local playerName, actualRoll, minRoll, maxRoll = strmatch(text, "^([^ ]+) .+ (%d+) %((%d+)-(%d+)%)%.?$")

    if (session.state == gameStates[3]) then
        -- If a registered player made the wager roll and has not yet rolled, record the roll
        if (tonumber(minRoll) == 1 and tonumber(maxRoll) == self.db.global.game.wager) then
            for i = 1, #session.players do
                if (session.players[i].name == playerName and session.players[i].roll == nil) then
                    session.players[i].roll = tonumber(actualRoll)
                end
            end
        end

        -- If all registered players have rolled, calculate the result
        if (#self:checkPlayerRolls() == 0) then
            self:calculateResult()
        end
    elseif (session.state == gameStates[4]) then
        -- If a tie-breaker player made a 1-100 roll and has not yet made a tie breaker roll, record the tie breaker roll
        if (tonumber(minRoll) == 1 and tonumber(maxRoll) == 100) then
            for i = 1, #session.result.tieBreakers do
                if (session.result.tieBreakers[i].name == playerName and session.result.tieBreakers[i].roll == nil) then
                    session.result.tieBreakers[i].roll = tonumber(actualRoll)
                end
            end
        end

        -- If all tie breaker players have rolled, attempt to resolve the tie
        if (#self:checkPlayerRolls() == 0) then
            self:resolveTie()
        end
    end
end

function WoWGoldGambler:calculateResult()
    -- Calculates the winners and losers of a session and the amount owed
    session.result = {
        winners = {},
        losers = {},
        amountOwed = 0
    }

    if (self.db.global.game.mode == gameModes[1]) then
        self:calculateClassicResult()
    elseif (self.db.global.game.mode == gameModes[2]) then
        self:calculateBigTwoResult()
    elseif (self.db.global.game.mode == gameModes[3]) then
        -- Roulette
    elseif (self.db.global.game.mode == gameModes[4]) then
        -- PriceIsRight
    else
        self:Print(self.db.global.game.mode .. " is not a valid game mode.")
        session.result = nil
        self:endGame()
    end

    self:detectTie()
end

function WoWGoldGambler:detectTie()
    -- Detects when there is a tie on either the winner or loser side. Multiple winners/losers is allowed in the Roulette game mode.
    -- If a tie is detected, set the game state to TIE BREAKER and continue listening for rolls. If a tie is not detected, the game is ended
    if (#session.result.winners > 1 and self.db.global.game.mode ~= gameModes[3]) then
        -- High End Tie Breaker
        SendChatMessage("High end tie breaker! " .. self:makeNameString(session.result.winners) .. " /roll 100 now!", self.db.global.game.chatChannel)
        session.state = gameStates[4]
        session.result.tieBreakers = {}

        for i = 1, #session.result.winners do
            session.result.tieBreakers[i] = session.result.winners[i]
            session.result.tieBreakers[i].roll = nil

            -- DEBUG: REMOVE ME
            if (session.result.tieBreakers[i].name == "Tester2") then
                session.result.tieBreakers[i].roll = 2
            end
        end
    elseif (#session.result.losers > 1 and self.db.global.game.mode ~= gameModes[3]) then
        -- Low End Tie Breaker
        SendChatMessage("Low end tie breaker! " .. self:makeNameString(session.result.losers) .. " /roll 100 now!", self.db.global.game.chatChannel)
        session.state = gameStates[4]
        session.result.tieBreakers = {}
        
        for i = 1, #session.result.losers do
            session.result.tieBreakers[i] = session.result.losers[i]
            session.result.tieBreakers[i].roll = nil

            -- DEBUG: REMOVE ME
            if (session.result.tieBreakers[i].name == "Tester1") then
                session.result.tieBreakers[i].roll = 1
            end
        end
    else
        self:endGame()
    end
end

function WoWGoldGambler:resolveTie()
    -- Tie breakers are always won and lost by the players who rolled the highest and lowest on a 100 roll
    -- Additional tie breaker rounds are possible if a tie still exists after resolution
    local tieWinners = {session.result.tieBreakers[1]}
    local tieLosers = {session.result.tieBreakers[1]}

    -- Determine which tied players had the highest and lowest rolls
    for i = 2, #session.result.tieBreakers do
        -- New loser
        if (session.result.tieBreakers[i].roll < tieLosers[1].roll) then
            tieLosers = {session.result.tieBreakers[i]}
        -- New winner
        elseif (session.result.tieBreakers[i].roll > tieWinners[1].roll) then
            tieWinners = {session.result.tieBreakers[i]}
        else
            -- Handle ties. Due to the way we initialize tieWinners and tieLosers, it's possible for both of these to be true
            if (session.result.tieBreakers[i].roll == tieLosers[1].roll) then
                tinsert(tieLosers, session.result.tieBreakers[i])
            end
            
            if (session.result.tieBreakers[i].roll == tieWinners[1].roll) then
                tinsert(tieWinners, session.result.tieBreakers[i])
            end
        end
    end

    -- Replace the result winners or losers with the tie result. High end ties are always resolved first.
    if (#session.result.winners > 1) then
        session.result.winners = tieWinners
    elseif (#session.result.losers > 1) then
        session.result.losers = tieLosers
    end

    -- Check the updated results for additional ties
    self:detectTie()
end

function WoWGoldGambler:endGame(info)
    -- Posts the result of the game session to the chat channel and updates stats before terminating the game session
    if (session.result ~= nil) then
        if (#session.result.losers > 0 and #session.result.winners > 0) then
            for i = 1, #session.result.losers do
                SendChatMessage(session.result.losers[i].name .. " owes " .. self:makeNameString(session.result.winners) .. " " .. session.result.amountOwed .. " gold!" , self.db.global.game.chatChannel)
                self:updatePlayerStat(session.result.losers[i].name, session.result.amountOwed * -1)
            end
            
            for i = 1, #session.result.winners do
                self:updatePlayerStat(session.result.winners[i].name, session.result.amountOwed)
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
    session.state = gameStates[1]
    session.players = {}
    session.result = nil
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

function WoWGoldGambler:checkPlayerRolls()
    -- Returns a list of the names of all registered or tie breaker players who have not rolled yet
    local players = session.players
    local playersToRoll = {}

    if (session.state == gameStates[4]) then
        players = session.result.tieBreakers
    end

    for i = 1, #players do
        if (players[i].roll == nil) then
            tinsert(playersToRoll, players[i].name)
        end
    end

    return playersToRoll
end

function WoWGoldGambler:calculateClassicResult()
    -- Calculation logic for the Classic game mode. A tie-breaker round will resolve ties.
    -- Winner: The player(s) with the highest roll
    -- Loser: The player(s) with the lowest roll
    -- Payment Amount: The difference between the losing and winning rolls
    tinsert(session.result.winners, session.players[1])
    tinsert(session.result.losers, session.players[1])

    for i = 2, #session.players do
        -- New loser
        if (session.players[i].roll < session.result.losers[1].roll) then
            session.result.losers = {session.players[i]}
        -- New winner
        elseif (session.players[i].roll > session.result.winners[1].roll) then
            session.result.winners = {session.players[i]}
        else
            -- Handle ties. Due to the way we initialize the winners/losers, it's possible for both of these to be true
            if (session.players[i].roll == session.result.losers[1].roll) then
                tinsert(session.result.losers, session.players[i])
            end
            if (session.players[i].roll == session.result.winners[1].roll) then
                tinsert(session.result.winners, session.players[i])
            end
        end
    end

    -- In a scenario where all players tie, it's possible to run in to this edge case. In this case, nobody wins or loses.
    if (session.result.winners == session.result.losers) then
        session.result.winner = {}
        session.result.losers = {}
    end

    session.result.amountOwed = session.result.winners[1].roll - session.result.losers[1].roll
end

function WoWGoldGambler:calculateBigTwoResult()
    -- Calculation logic for the BigTwo game mode. Ties are not possible.
    -- Winner: A randomly selected player from the set of players who rolled a 2
    -- Loser: A randomly selected player from the set of players who rolled a 1
    -- Payment Amount: The wager amount
    for i = 1, #session.players do
        if (session.players[i].roll == 1) then
            tinsert(session.result.losers, session.players[i])
        elseif (session.players[i].roll == 2) then
            tinsert(session.result.winners, session.players[i])
        end
    end

    if (#session.result.losers > 0) then
        session.result.losers = {session.result.losers[math.random(#session.result.losers)]}
    end

    if (#session.result.winners > 0) then
        session.result.winners = {session.result.winners[math.random(#session.result.winners)]}
    end

    session.result.amountOwed = self.db.global.game.wager
end

function WoWGoldGambler:updatePlayerStat(playerName, amount)
    -- Update a given player's stats by adding the given amount
    if (self.db.global.stats.player[playerName] == nil) then
        self.db.global.stats.player[playerName] = 0
    end

    if (session.stats.player[playerName] == nil) then
        session.stats.player[playerName] = 0
    end

    self.db.global.stats.player[playerName] = self.db.global.stats.player[playerName] + amount
    session.stats.player[playerName] = session.stats.player[playerName] + amount
end

function WoWGoldGambler:printStats(sessionFlag)
    -- Post all player stats to the chat channel, ordered from highest winnings to lowest losings.
    -- If the sessionFlag is true, print session stats instead of all-time stats
    local sortedPlayers = {}
    local stats = self.db.global.stats.player

    if (sessionFlag == true) then
        stats = session.stats.player
    end

    -- Merge alias player stats into their mains and populate the sortedPlayers array
    for player, winnings in pairs(stats) do
        tinsert(sortedPlayers, player)

        if (self.db.global.stats.aliases[player] ~= nil) then
            for i = 1, #self.db.global.stats.aliases[player] do
                stats[player] = winnings + stats[self.db.global.stats.aliases[player][i]]
                stats[self.db.global.stats.aliases[player][i]] = nil
            end
        end
    end

    -- Sort the sortedPlayers array by their winnings
    table.sort(sortedPlayers, function(a, b)
        return stats[a] > stats[b]
    end)

    if (sessionFlag) then
        SendChatMessage("-- WoWGoldGambler Session Stats --", self.db.global.game.chatChannel)
    else
        SendChatMessage("-- WoWGoldGambler All Time Stats --", self.db.global.game.chatChannel)
    end

    -- Post each player's stats to the chat channel
    for i = 1, #sortedPlayers do
        local amount = stats[sortedPlayers[i]]
        local wonOrLost = " has won "

        if (amount < 0) then
            wonOrLost = " has lost "
        end

        SendChatMessage(sortedPlayers[i] .. wonOrLost .. amount .. " gold!", self.db.global.game.chatChannel)
    end
end