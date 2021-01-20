WoWGoldGambler = LibStub("AceAddon-3.0"):NewAddon("WoWGoldGambler", "AceConsole-3.0", "AceEvent-3.0")

-- Global Vars --
local gameStates = [
    "Ready",
    "Registration",
    "InProgress"
]

local gameModes = [
    "Classic",
    "BigTwo",
    "Roulette",
    "PriceIsRight"
]

local chatChannels = [
    "PARTY",
    "RAID",
    "GUILD"
]

local defaults = {
    global = {
        game = {
            state = gameStates[1],
            mode = gameModes[1],
            wager = 1000,
            chatChannel = chatChannels[1],
            players = [],
        }
        stats = {

        } 
    }
}

local options = {
    name = "WoWGoldGambler",
    handler = WoWGoldGambler,
    type = 'group',
    args = {
        startround = {
            name = "Start Round",
            desc = "Start a new round",
            type = "execute",
            func = "StartRound"
        },
        rollme = {
            name = "Roll Me",
            desc = "Do a /roll <wager> for me",
            type = "execute",
            func = "RollMe"
        }
    },
}

function WoWGoldGambler:OnInitialize()
    -- Called when the addon is loaded
    self.db = LibStub("AceDB-3.0"):New("WoWGoldGamblerDB", defaults, true)
    LibStub("AceConfig-3.0"):RegisterOptionsTable("WoWGoldGambler", options, {"wowgoldgambler", "wgg"})
    self:Print("WoWGoldGambler Initialized!")
end

function WoWGoldGambler:OnEnable()
    -- Called when the addon is enabled
    self.db.global.game.dealer = UnitName("player")
    self:RegisterEvent("CHAT_MSG_SYSTEM")

    if (self.db.global.game.chatChannel == "PARTY") then
        self:RegisterEvent("CHAT_MSG_PARTY")
        self:RegisterEvent("CHAT_MSG_PARTY_LEADER")
    elseif (self.db.global.game.chatChannel == "RAID") then
        self:RegisterEvent("CHAT_MSG_RAID")
        self:RegisterEvent("CHAT_MSG_RAID_LEADER")
    elseif (self.db.global.game.chatChannel == "GUILD") then
        self:RegisterEvent("CHAT_MSG_GUILD")
    end

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

function WoWGoldGambler:CHAT_MSG_GUILD()
    -- Called when a message is recieved in the GUILD channel
    self:Print("Recieved Guild Message")
end

function WoWGoldGambler:StartRound(info)
    -- Called when the startround option is called
    self:Print("Round is starting!")
end

function WoWGoldGambler:RollMe(info)
    -- Called when the rollme option is called
    self:Print("Rolling " .. self.global.game.wager .. "!")
    RandomRoll(1, game.wager)
end