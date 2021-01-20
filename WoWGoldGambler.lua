WoWGoldGambler = LibStub("AceAddon-3.0"):NewAddon("WoWGoldGambler", "AceConsole-3.0", "AceEvent-3.0")

-- Global Vars --
local gameStates = {
    "Ready",
    "Registration",
    "InProgress"
}

local gameModes = {
    "Classic",
    "BigTwo",
    "Roulette",
    "PriceIsRight"
}

local chatChannels = {
    "SAY",
    "PARTY",
    "RAID",
    "GUILD"
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

-- Stores all session-related game data. Not to be stored in the DB
local session = {
    state = gameStates[1],
    dealer = nil,
    players = {}
}

function WoWGoldGambler:OnInitialize()
    -- Called when the addon is loaded
    self:Print("Initializing WoWGoldGambler...")
    self.db = LibStub("AceDB-3.0"):New("WoWGoldGamblerDB", defaults, true)
    LibStub("AceConfig-3.0"):RegisterOptionsTable("WoWGoldGambler", options, {"wowgoldgambler", "wgg"})
    self:Print("WoWGoldGambler Initialized!")
end

function WoWGoldGambler:OnEnable()
    -- Called when the addon is enabled
    self:Print("Enabling WoWGoldGambler...")
    session.dealer = UnitName("player")
    self:Print("WoWGoldGambler Enabled!")
end

function WoWGoldGambler:OnDisable()
    -- Called when the addon is disabled
    self:Print("WoWGoldGambler Disabled!")
end

function WoWGoldGambler:CHAT_MSG_SYSTEM()
    -- Called when a roll is done
    self:Print("Recieved Roll!")
end

function WoWGoldGambler:CHAT_MSG_PARTY()
    -- Called when a message is recieved in the PARTY channel
    self:Print("Recieved Party Message")
end

function WoWGoldGambler:CHAT_MSG_PARTY_LEADER()
    -- Called when a message is recieved in the PARTY channel from the party leader
    self:Print("Recieved Party Leader Message")
end

function WoWGoldGambler:CHAT_MSG_RAID()
    -- Called when a message is recieved in the RAID channel
    self:Print("Recieved Raid Message")
end

function WoWGoldGambler:CHAT_MSG_RAID_LEADER()
    -- Called when a message is recieved in the RAID channel from the raid leader
    self:Print("Recieved Raid Leader Message")
end

function WoWGoldGambler:CHAT_MSG_GUILD(text, playerName, channelName)
    -- Called when a message is recieved in the GUILD channel
    self:Print("Recieved Guild Message '" .. text .. "' in channel " .. channelName .. " from " .. playerName)
end

function WoWGoldGambler:StartGame(info)
    -- Called when the startgame option is called
    self:Print("Session state is " .. session.state)
    if (session.state == gameStates[1]) then
        self:Print(session.dealer .. " is starting a new game...")

        if (self.db.global.game.chatChannel == "PARTY") then
            self:RegisterEvent("CHAT_MSG_PARTY")
            self:RegisterEvent("CHAT_MSG_PARTY_LEADER")
        elseif (self.db.global.game.chatChannel == "RAID") then
            self:RegisterEvent("CHAT_MSG_RAID")
            self:RegisterEvent("CHAT_MSG_RAID_LEADER")
        elseif (self.db.global.game.chatChannel == "GUILD") then
            self:RegisterEvent("CHAT_MSG_GUILD")
        end

        session.state = gameStates[2]
    end
end

function WoWGoldGambler:StartRolls(info)
    -- Called when the startrolls option is called
    self:Print("Session state is " .. session.state)
    if (session.state == gameStates[2]) then
        self:Print(session.dealer .. " is starting a new game...")

        if (self.db.global.game.chatChannel == "PARTY") then
            self:UnregisterEvent("CHAT_MSG_PARTY")
            self:UnregisterEvent("CHAT_MSG_PARTY_LEADER")
        elseif (self.db.global.game.chatChannel == "RAID") then
            self:UnregisterEvent("CHAT_MSG_RAID")
            self:UnregisterEvent("CHAT_MSG_RAID_LEADER")
        elseif (self.db.global.game.chatChannel == "GUILD") then
            self:UnregisterEvent("CHAT_MSG_GUILD")
        end

        self:RegisterEvent("CHAT_MSG_SYSTEM")
        session.state = gameStates[3]
    end
end

function WoWGoldGambler:EndGame(info)
    -- Called when the endgame option is called
    self:Print("Session state is " .. session.state)
    if (session.state ~= gameStates[1]) then
        self:Print("Game Ended!")

        if (self.db.global.game.chatChannel == "PARTY") then
            self:UnregisterEvent("CHAT_MSG_PARTY")
            self:UnregisterEvent("CHAT_MSG_PARTY_LEADER")
        elseif (self.db.global.game.chatChannel == "RAID") then
            self:UnregisterEvent("CHAT_MSG_RAID")
            self:UnregisterEvent("CHAT_MSG_RAID_LEADER")
        elseif (self.db.global.game.chatChannel == "GUILD") then
            self:UnregisterEvent("CHAT_MSG_GUILD")
        end

        self:UnregisterEvent("CHAT_MSG_SYSTEM")

        session.state = gameStates[1]
    end
end

function WoWGoldGambler:RollMe(info)
    -- Called when the rollme option is called
    self:Print("Rolling " .. self.db.global.game.wager .. "!")
    RandomRoll(1, self.db.global.game.wager)
end

function WoWGoldGambler:ChangeChannel(info)
    -- Called when the changechannel option is called
    if (self.db.game.chatChannel == "SAY") then
        self.db.game.chatChannel = "PARTY"
    elseif (self.db.game.chatChannel == "PARTY") then
        self.db.game.chatChannel = "RAID"
    elseif (self.db.game.chatChannel == "RAID") then
        self.db.game.chatChannel = "GUILD"
    else
        self.db.game.chatChannel = "SAY"
    end

    self:Print("New chat channel is " + self.db.game.chatChannel)
end