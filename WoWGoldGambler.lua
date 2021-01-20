-- GLOBAL VARS --
WoWGoldGambler = LibStub("AceAddon-3.0"):NewAddon("WoWGoldGambler", "AceConsole-3.0", "AceEvent-3.0")

local gameStates = {
    "Idle",
    "Registration",
    "Rolling"
}

local gameModes = {
    "Classic",
    "BigTwo",
    "Roulette",
    "PriceIsRight"
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
    players = {}
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
        rollme = {
            name = "Roll Me",
            desc = "Do a /roll <wager> for me",
            type = "execute",
            func = "RollMe"
        },
        changechannel = {
            name = "Change Channel",
            desc = "Change the chat channel to the next one in the list",
            type = "execute",
            func = "ChangeChannel"
        }
    },
}

-- HANDLERS --

function WoWGoldGambler:OnInitialize()
    -- Called when the addon is loaded
    self.db = LibStub("AceDB-3.0"):New("WoWGoldGamblerDB", defaults, true)
    LibStub("AceConfig-3.0"):RegisterOptionsTable("WoWGoldGambler", options, {"wowgoldgambler", "wgg"})
    session.dealer = UnitName("player")
end

function WoWGoldGambler:StartGame(info)
    -- Starts a new game session for registration when there is no session in progress

    if (session.state == gameStates[1]) then
        SendChatMessage("WoWGoldGambler: A new game has been started! Type 1 to join! (-1 to withdraw)" , self.db.global.game.chatChannel)
        SendChatMessage("GAME MODE - " .. self.db.global.game.mode .. " - WAGER - " .. self.db.global.game.wager, self.db.global.game.chatChannel)

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
        SendChatMessage("Registration has ended. All players /roll " .. self.db.global.game.wager .. " now!" , self.db.global.game.chatChannel)

        self:UnregisterEvent("CHAT_MSG_PARTY")
        self:UnregisterEvent("CHAT_MSG_PARTY_LEADER")
        self:UnregisterEvent("CHAT_MSG_RAID")
        self:UnregisterEvent("CHAT_MSG_RAID_LEADER")
        self:UnregisterEvent("CHAT_MSG_GUILD")

        self:RegisterEvent("CHAT_MSG_SYSTEM")

        session.state = gameStates[3]
    end
end

function WoWGoldGambler:EndGame(info)
    -- Ends the currently running session
    if (session.state ~= gameStates[1]) then
        SendChatMessage("The game has been ended." , self.db.global.game.chatChannel)

        self:UnregisterEvent("CHAT_MSG_PARTY")
        self:UnregisterEvent("CHAT_MSG_PARTY_LEADER")
        self:UnregisterEvent("CHAT_MSG_RAID")
        self:UnregisterEvent("CHAT_MSG_RAID_LEADER")
        self:UnregisterEvent("CHAT_MSG_GUILD")
        self:UnregisterEvent("CHAT_MSG_SYSTEM")

        session.state = gameStates[1]
        session.players = {}
    end
end

function WoWGoldGambler:RollMe(info)
    -- Called when the rollme option is called
    RandomRoll(1, self.db.global.game.wager)
end

function WoWGoldGambler:ChangeChannel(info)
    -- Called when the changechannel option is called
    if (self.db.global.game.chatChannel == "GUILD") then
        self.db.global.game.chatChannel = "PARTY"
    elseif (self.db.global.game.chatChannel == "PARTY") then
        self.db.global.game.chatChannel = "RAID"
    else
        self.db.global.game.chatChannel = "GUILD"
    end

    self:Print("WoWGoldGambler: New chat channel is " .. self.db.global.game.chatChannel)
end

function WoWGoldGambler:CHAT_MSG_PARTY(channelName, text, playerName)
    -- Listens to the PARTY channel for player registration
    handleChatMessage(channelName, text, playerName)
    self:Print(session.players)
end

function WoWGoldGambler:CHAT_MSG_PARTY_LEADER(channelName, text, playerName)
    -- Listens to the PARTY channel for player registration from the party leader
    handleChatMessage(channelName, text, playerName)
    self:Print(session.players)
end

function WoWGoldGambler:CHAT_MSG_RAID(channelName, text, playerName)
    -- Listens to the RAID channel for player registration
    handleChatMessage(channelName, text, playerName)
    self:Print(session.players)
end

function WoWGoldGambler:CHAT_MSG_RAID_LEADER(channelName, text, playerName)
    -- Listens to the RAID channel for player registration from the raid leader
    handleChatMessage(channelName, text, playerName)
    self:Print(session.players)
end

function WoWGoldGambler:CHAT_MSG_GUILD(channelName, text, playerName)
    -- Listens to the GUILD channel for player registration
    handleChatMessage(channelName, text, playerName)
    self:Print(session.players)
end

function WoWGoldGambler:CHAT_MSG_SYSTEM(channelName, text)
    -- Listens to system events in the chat to keep track of user rolls
    self:Print("Recieved System Message '" .. text .. "' in channel " .. channelName)
end

function WoWGoldGambler:handleChatMessage(channelName, text, playerName)
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