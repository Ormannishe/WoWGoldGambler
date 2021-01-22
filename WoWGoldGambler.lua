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
    "GUILD",
    "SAY" -- DEBUG: REMOVE ME
}

-- Stores all session-related game data. Not to be stored in the DB
local session = {
    state = gameStates[1],
    dealer = nil,
    players = {},
    result = nil
}

-- Stores game-related data that should persist between sessions
local defaults = {
    global = {
        game = {
            mode = gameModes[1],
            wager = 1000,
            chatChannel = chatChannels[1]
        },
        stats = {

        }
    }
}

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
        setwager = {
            name = "Set Wager",
            desc = "Change the wager amount to a given amount",
            type = "execute",
            func = "setWager"
        },
        rollme = {
            name = "Roll Me",
            desc = "Do a /roll for the dealer",
            type = "execute",
            func = "rollMe"
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

        if (self.db.global.game.chatChannel == "PARTY") then
            self:RegisterEvent("CHAT_MSG_PARTY")
            self:RegisterEvent("CHAT_MSG_PARTY_LEADER")
        elseif (self.db.global.game.chatChannel == "RAID") then
            self:RegisterEvent("CHAT_MSG_RAID")
            self:RegisterEvent("CHAT_MSG_RAID_LEADER")
        elseif (self.db.global.game.chatChannel == "SAY") then -- DEBUG: REMOVE ME
            self:RegisterEvent("CHAT_MSG_SAY")
        else
            self:RegisterEvent("CHAT_MSG_GUILD")
        end

        session.state = gameStates[2]

        -- DEBUG: REMOVE ME
        tinsert(session.players, {name = "Tester", realm = "Tester", roll = 1})
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
            self:UnregisterEvent("CHAT_MSG_SAY") -- DEBUG: REMOVE ME
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
    elseif (session.state == gameStates[3]) then
        -- If the rolling phase has already started, post the names of the players who have yet to roll in the chat channel
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
    elseif (self.db.global.game.chatChannel == chatChannels[3]) then -- DEBUG: REMOVE ME
        self.db.global.game.chatChannel = chatChannels[4]
    else
        self.db.global.game.chatChannel = chatChannels[1]
    end

    self:Print("WoWGoldGambler: New chat channel is " .. self.db.global.game.chatChannel)
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
    -- If no values are given, they are defaulted to 1 and the wager
    if (maxAmount == nil) then
        maxAmount = self.db.global.game.wager
    end

    if (minAmount == nil) then
        minAmount = 1
    end
    
    RandomRoll(minAmount, maxAmount)
end

-- Event Handlers --
function WoWGoldGambler:CHAT_MSG_SAY(channelName, text, playerName)
    -- Listens to the SAY channel for player registration
    -- DEBUG: REMOVE ME
    self:handleChatMessage(channelName, text, playerName)
end

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
                roll = 0
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
                if (session.players[i].name == playerName and session.players[i].roll == 0) then
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

        -- Attempt to resolve the tie
        self:resolveTie()
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
        -- BigTwo
    elseif (self.db.global.game.mode == gameModes[3]) then
        -- Roulette
    elseif (self.db.global.game.mode == gameModes[4]) then
        -- PriceIsRight
    else
        -- ???
    end

    self:detectTie()
end

function WoWGoldGambler:detectTie()
    -- Detects when there is a tie on either the winner or loser side. There are no ties in the Roulette game mode.
    -- If a tie is detected, set the game state to TIE BREAKER and continue listening for rolls
    -- If a tie is not detected, the game is ended
    if (#session.result.winners > 1 and self.db.global.game.mode ~= gameModes[3]) then
        -- High End Tie Breaker
        SendChatMessage("High end tie breaker! " .. self:makeNameString(session.result.winners) .. " /roll 100 now!", self.db.global.game.chatChannel)
        session.state = gameStates[4]
        session.result.tieBreakers = {}

        for i = 1, #session.result.winners do
            session.result.tieBreakers[i] = session.result.winners
            session.result.tieBreakers[i].roll = nil
        end
    elseif (#session.result.losers > 1 and self.db.global.game.mode ~= gameModes[3]) then
        -- Low End Tie Breaker
        SendChatMessage("Low end tie breaker! " .. self:makeNameString(session.result.losers) .. " /roll 100 now!", self.db.global.game.chatChannel)
        session.state = gameStates[4]
        session.result.tieBreakers = {}
        
        for i = 1, #session.result.losers do
            session.result.tieBreakers[i] = session.result.losers
            session.result.tieBreakers[i].roll = 0
        end
    else
        self:endGame()
    end
end

function WoWGoldGambler:resolveTie()
    -- Tie breakers are always won by the player who rolled the highest on a 100 roll
    local tieWinners = {session.result.tieBreakers[1]}
    local tieLosers = {session.result.tieBreakers[1]}

    -- Make sure all tied players have rolled
    for i = 1, #session.result.tieBreakers do
        if (session.result.tieBreakers[i].roll == nil) then
            return
        end
    end

    -- Determine which tied players had the highest and lowest rolls
    for i = 2, #session.result.tieBreakers do
        -- New loser
        if (session.result.tieBreakers[i].roll < tieLosers[1].roll) then
            tieLosers = {session.result.tieBreakers[i]}
        -- New winner
        elseif (session.result.tieBreakers[i].roll > tieWinners[1].roll) then
            tieWinners = {session.result.tieBreakers[i]}
        -- Tied loser
        elseif (session.result.tieBreakers[i].roll == tieLosers[1].roll) then
            tinsert(tieLosers, session.result.tieBreakers[i])
        -- Tied winner
        elseif (session.result.tieBreakers[i].roll == tieWinners[1].roll) then
            tinsert(tieWinners, session.result.tieBreakers[i])
        end
    end

    -- Replace the result winners or losers with the tie result. High end ties are always resolved first.
    if (#session.results.winners > 1) then
        session.results.winners = tieWinners
    elseif (#session.results.losers > 1) then
        session.results.losers = tieLosers
    end

    -- Check the updated results for additional ties
    self:detectTie()
end

function WoWGoldGambler:endGame(info)
    -- Posts the result of the game session to the chat channel and updates stats before terminating the game session    
    if (session.result ~= nil) then
        for i = 1, #session.result.losers do
            SendChatMessage(session.result.losers[1].name .. " owes " .. self:makeNameString(session.result.winners) .. " " .. session.result.amountOwed .. " gold!" , self.db.global.game.chatChannel)
        end
        -- TODO: Updates stats
    end

    -- Restore original IDLE state
    self:UnregisterEvent("CHAT_MSG_SAY") -- DEBUG: REMOVE ME
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

function WoWGoldGambler:makeNameString(names)
    local nameString = ""

    for i = 1, #names do
        if (i == #names) then
            nameString = nameString .. " and " .. names[i]
        else
            nameString = nameString .. ", " .. names[i]
        end
    end

    return nameString
end

function WoWGoldGambler:checkPlayerRolls()
    -- Returns a list of the names of all registered players who have not rolled yet
    local players = {}

    for i = 1, #session.players do
        if (session.players[i].roll == 0) then
            tinsert(players, session.players[i].name)
        end
    end

    return players
end

function WoWGoldGambler:calculateClassicResult()
    -- Calculation logic for the Classic game mode
    tinsert(session.result.winners, session.players[1])
    tinsert(session.result.losers, session.players[1])

    for i = 2, #session.players do
        -- New loser
        if (session.players[i].roll < session.result.losers[1].roll) then
            session.result.losers = {session.players[i]}
        -- New winner
        elseif (session.players[i].roll > session.result.winners[1].roll) then
            session.result.winners = {session.players[i]}
        -- Tied loser
        elseif (session.players[i].roll == session.result.losers[1].roll) then
            tinsert(session.result.losers, session.players[i])
        -- Tied winner
        elseif (session.players[i].roll == session.result.winners[1].roll) then
            tinsert(session.result.winners, session.players[i])
        end
    end

    session.result.amountOwed = session.result.winners[1].roll - session.result.losers[1].roll
end