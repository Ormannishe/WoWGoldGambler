WoWGoldGambler = LibStub("AceAddon-3.0"):NewAddon("WoWGoldGambler", "AceConsole-3.0", "AceEvent-3.0")

-- GLOBAL VARS --
local gameStates = {
    "IDLE",
    "REGISTRATION",
    "ROLLING"
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
    result = nil
}

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
            desc = "Start a new game",
            type = "execute",
            func = "StartGame"
        },
        startrolls = {
            name = "Start Rolls",
            desc = "Start listening for player rolls",
            type = "execute",
            func = "StartRolls"
        },
        endgame = {
            name = "End Game",
            desc = "End the currently running game",
            type = "execute",
            func = "EndGame"
        },
        changechannel = {
            name = "Change Channel",
            desc = "Change the chat channel to the next one in the list",
            type = "execute",
            func = "ChangeChannel"
        },
        rollme = {
            name = "Roll Me",
            desc = "Do a /roll <wager> for me",
            type = "execute",
            func = "RollMe"
        }
    },
}

-- Initialization --

function WoWGoldGambler:OnInitialize()
    -- Called when the addon is loaded
    self.db = LibStub("AceDB-3.0"):New("WoWGoldGamblerDB", defaults, true)
    LibStub("AceConfig-3.0"):RegisterOptionsTable("WoWGoldGambler", options, {"wowgoldgambler", "wgg"})
    session.dealer = UnitName("player")
end

-- Slash Command Handlers --

function WoWGoldGambler:StartGame(info)
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
        else
            self:RegisterEvent("CHAT_MSG_GUILD")
        end

        session.state = gameStates[2]
    end
end

function WoWGoldGambler:StartRolls(info)
    -- Ends the registration phase of the currently running session and begins the rolling phase
    if (session.state == gameStates[2]) then
        if (#session.players > 1) then
            SendChatMessage("Registration has ended. All players /roll " .. self.db.global.game.wager .. " now!" , self.db.global.game.chatChannel)

            self:UnregisterEvent("CHAT_MSG_PARTY")
            self:UnregisterEvent("CHAT_MSG_PARTY_LEADER")
            self:UnregisterEvent("CHAT_MSG_RAID")
            self:UnregisterEvent("CHAT_MSG_RAID_LEADER")
            self:UnregisterEvent("CHAT_MSG_GUILD")

            self:RegisterEvent("CHAT_MSG_SYSTEM")

            session.state = gameStates[3]
        else
            SendChatMessage("Not enough players have registered to play!" , self.db.global.game.chatChannel)
        end
    end
end

function WoWGoldGambler:EndGame(info)
    -- Ends the currently running session
    if (session.state ~= gameStates[1]) then
        -- Post results to the chat channel if there are any
        if (session.result ~= nil) then
            SendChatMessage(result.losers[1].name .. " owes " .. result.winners[1].name .. " " .. result.amountOwed .. " gold!" , self.db.global.game.chatChannel)
        end

        -- Restore original idle state
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
end

function WoWGoldGambler:ChangeChannel(info)
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

function WoWGoldGambler:RollMe(info)
    -- Automatically performs the correct roll for the dealer
    RandomRoll(1, self.db.global.game.wager)
end

-- Event Handlers

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

-- Helper Functions --

function WoWGoldGambler:handleChatMessage(channelName, text, playerName)
    -- Parses chat messages recieved by one of the chat Event Listeners to find and record player registration
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

    for i = 1, #session.players do
        self.Print(session.players[i].name .. " - " .. session.players[i].realm)
    end
end

function WoWGoldGambler:handleSystemMessage(channelName, text)
    -- Parses system messages recieved by the Event Listener to find and record player rolls
    local playerName, actualRoll, minRoll, maxRoll = strmatch(text, "^([^ ]+) .+ (%d+) %((%d+)-(%d+)%)%.?$")

    -- If a registered player made the correct roll and has not yet rolled, record the roll
    if (minRoll == 1 and maxRoll == self.db.global.game.wager) then
        for i = 1, #session.players do
            if (session.players[i].name == playerName and session.players[i].roll == nil) then
                session.players[i].roll = actualRoll
        end
    end

    -- If all registered players have rolled, calculate the results and end the session
    if (#self:checkPlayerRolls() == 0) then
        self:calculateResult()
        self:EndGame()
    end
end

function WoWGoldGambler:checkPlayerRolls()
    -- Returns a list of the names of all registered players who have not rolled yet
    local players = {}

    for i = 1, #session.players do
        if (session.players[i].roll == nil) then
            tinsert(players, session.players[i].name)
        end
    end

    return players
end

function WoWGoldGambler:calculateResult()
    -- Calculates the winners and losers of a session and the amount owed
    local result = {
        winners = {},
        losers = {},
        amountOwed = 0
    }

    if (self.db.global.game.mode == gameModes[1]) then
        -- Classic
        local highestRoller = session.players[1]
        local lowestRoller = session.players[1]

        for i = 2, #session.players do
            if (session.players[i].roll < lowestRoller.roll) then
                lowestRoller = session.players[i]
            end

            if (session.players[i].roll > highestRoller.roll) then
                highestRoller = session.players[i]
            end
        end

        tinsert(result.winners, highestRoller)
        tinsert(result.losers, lowestRoller)
        result.amountOwed = highestRoller.roll - lowestRoller.roll
    elseif (self.db.global.game.mode == gameModes[2]) then
        -- BigTwo
    elseif (self.db.global.game.mode == gameModes[3]) then
        -- Roulette
    elseif (self.db.global.game.mode == gameModes[4]) then
        -- PriceIsRight
    else
        -- ???
    end

    session.result = result
end