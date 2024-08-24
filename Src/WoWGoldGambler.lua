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
    "LOTTERY",
    "PRICE IS RIGHT",
    "POKER",
    "CHICKEN",
    "1v1 DEATH ROLL",
    "EXCHANGE"
}

local chatChannels = {
    "PARTY",
    "RAID",
    "GUILD"
}

-- Defaults for the DB
local defaults = {
    global = {
        minimap = {
            hide = false,
        },
        game = {
            mode = gameModes[1],
            wager = 1000,
            chatChannel = chatChannels[1],
            houseCut = 0,
            realmFilter = true,
        },
        stats = {
            player = {},
            aliases = {},
            house = 0
        },
        bannedPlayers = {},
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
            func = "showUi"
        },
        hide = {
            name = "Hide UI",
            desc = "Hide the WoWGoldGambler UI",
            type = "execute",
            func = "hideUi"
        },
        realmfilter = {
            name = "Toggle Realm Filter",
            desc = "Toggles the realm filter on/off, determining whether or not players from other realms can register.",
            type = "execute",
            func = "toggleRealmFilter"
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
        listaliases = {
            name = "List Aliases",
            desc = "See the list of all defined aliases (ie. joined stats)",
            type = "execute",
            func = "listAliases"
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
        },
        ban = {
            name = "Ban Player",
            desc = "[player] - Ban the given [player], preventing them from registering for games",
            type = "input",
            set = "banPlayer"
        },
        unban = {
            name = "Unban Player",
            desc = "[player] - Unban the given [player], allowing them to once again register for games",
            type = "input",
            set = "unbanPlayer"
        },
        listbans = {
            name = "List Bans",
            desc = "See a list of banned players",
            type = "execute",
            func = "listBans"
        },
    }
}

-- Initialization --

function WoWGoldGambler:OnInitialize()
    -- Sets up the DB and slash command options when the addon is loaded
    self.db = LibStub("AceDB-3.0"):New("WoWGoldGamblerDB", defaults, true)
    LibStub("AceConfig-3.0"):RegisterOptionsTable("WoWGoldGambler", options, {"wowgoldgambler", "wgg"})

    -- Sets up the minimap icon
    local minimapIcon = LibStub("LibDBIcon-1.0")
    local minimapLDB = LibStub("LibDataBroker-1.1"):NewDataObject("MinimapIcon", {
        type = "data source",
        text = "WoWGoldGambler",
        icon = "Interface\\Icons\\inv_misc_coin_17",
        OnClick = function() self:toggleUi() end,
        OnTooltipShow = function(tooltip)
		    tooltip:AddLine("WoWGoldGambler", 1, 1, 1)
            tooltip:AddLine(" ", 1, 1, 1)
            tooltip:AddLine("Click to toggle the WoWGoldGambler UI.", 1, 229 / 255, 153 / 255)
		    tooltip:Show()
		end,
    })

    minimapIcon:Register("MinimapIcon", minimapLDB, self.db.global.minimap)

    -- Stores all session-related game data. Not to be stored in the DB
    self.session = {
        state = gameStates[1],
        dealer = {
            name = UnitName("player"),
        },
        modeData = {}, -- arbitrary data used to run game modes
        players = {},
        result = nil,
        stats = {
            player = {},
            house = {}
        }
    }

    self:drawUi()
    self:updateUi(self.session.state, gameStates)
    self:hideUi()
end

-- Event Handlers --

function WoWGoldGambler:handleChatMessage(_, text, playerName)
    -- Parses chat messages recieved by one of the chat Event Listeners to record player registration
    local playerName, playerRealm = strsplit("-", playerName, 2)

    if (self.session.state == gameStates[2]) then
        WoWGoldGambler[self.db.global.game.mode].register(WoWGoldGambler, text, playerName, playerRealm)
    elseif (self.session.state == gameStates[3]) then
        -- If we're still listening to chat messages during the rolling phase of a game, perform game-mode specific actions
        if (WoWGoldGambler[self.db.global.game.mode].handleChatMessage ~= nil) then
            WoWGoldGambler[self.db.global.game.mode].handleChatMessage(WoWGoldGambler, text, playerName, playerRealm)
        end
    end
end

function WoWGoldGambler:handleSystemMessage(_, text)
    -- Parses system messages recieved by the Event Listener to find and record player rolls
    local playerName, actualRoll, minRoll, maxRoll = strmatch(text, "^([^ ]+) .+ (%d+) %((%d+)-(%d+)%)%.?$")

    -- Perform game mode specific tasks for recording player rolls
    WoWGoldGambler[self.db.global.game.mode].recordRoll(WoWGoldGambler, playerName, actualRoll, minRoll, maxRoll)

    -- If all registered players have rolled, calculate the result
    if (#self:checkPlayerRolls() == 0) then
        self:calculateResult()
    end
end

-- Slash Command Handlers --

function WoWGoldGambler:banPlayer(info, playerName)
    -- Adds the given [playerName] to the list of banned players if they are not already on the list
    for i = 1, #self.db.global.bannedPlayers do
        if (playerName == self.db.global.bannedPlayers[i]) then
            self:Print(playerName .. " is already banned!")
            return
        end
    end

    tinsert(self.db.global.bannedPlayers, playerName)
    self:Print(playerName .. " has been added to the ban list.")
end

function WoWGoldGambler:unbanPlayer(info, playerName)
    -- Removes the given [playerName] from the list of banned players
    for i = 1, #self.db.global.bannedPlayers do
        if (playerName == self.db.global.bannedPlayers[i]) then
            tremove(self.db.global.bannedPlayers, i)
            self:Print(playerName .. " has been removed from the ban list.")
            return
        end
    end

    self:Print(playerName .. " is not currently banned!")
end

function WoWGoldGambler:listBans(info)
    -- Prints out a list of all banned players to the user
    if (#self.db.global.bannedPlayers > 0) then
        self:Print("The following players have been banned from playing:")

        for i = 1, #self.db.global.bannedPlayers do
            self:Print(self.db.global.bannedPlayers[i])
        end
    else
        self:Print("There are no players on the ban list.")
    end
end

function WoWGoldGambler:toggleRealmFilter(info)
    -- Toggles the realm filter on/off, determining whether or not players from other realms are allowed to register
    if (self.db.global.game.realmFilter) then
        self.db.global.game.realmFilter = false
        self:Print("Realm filter has been turned OFF.")
    else
        self.db.global.game.realmFilter = true
        self:Print("Realm filter has been turned ON.")
    end
end

-- Implementation --

function WoWGoldGambler:changeChannel(direction)
    -- Increment or decrement (determined by [direction]) the chat channel to be used by the addon
    local channelIndex

    for i = 1, #chatChannels do
        if (self.db.global.game.chatChannel == chatChannels[i]) then
            channelIndex = i
        end
    end

    if (channelIndex ~= nil) then
        if (direction == "prev") then
            if (channelIndex == 1) then
                self.db.global.game.chatChannel = chatChannels[#chatChannels]
            else
                self.db.global.game.chatChannel = chatChannels[channelIndex - 1]
            end
        elseif (direction == "next") then
            if (channelIndex == #chatChannels) then
                self.db.global.game.chatChannel = chatChannels[1]
            else
                self.db.global.game.chatChannel = chatChannels[channelIndex + 1]
            end
        end
    else
        self.db.global.game.chatChannel = chatChannels[1]
    end
end

function WoWGoldGambler:changeGameMode(direction)
    -- Increment or decrement (determined by [direction]) the game mode to be used by the addon
    local modeIndex

    for i = 1, #gameModes do
        if (self.db.global.game.mode == gameModes[i]) then
            modeIndex = i
        end
    end

    if (modeIndex ~= nil) then
        if (direction == "prev") then
            if (modeIndex == 1) then
                self.db.global.game.mode = gameModes[#gameModes]
            else
                self.db.global.game.mode = gameModes[modeIndex - 1]
            end
        elseif (direction == "next") then
            if (modeIndex == #gameModes) then
                self.db.global.game.mode = gameModes[1]
            else
                self.db.global.game.mode = gameModes[modeIndex + 1]
            end
        end
    else
        self.db.global.game.mode = gameModes[1]
    end
end

function WoWGoldGambler:setWager(amount)
    -- Sets the game's wager amount to [amount]
    amount = tonumber(amount)

    if (amount ~= nil and amount > 0) then
        self.db.global.game.wager = amount
    end
end

function WoWGoldGambler:setHouseCut(amount)
    -- Sets the house cut to the given [amount]. The house cut is a percentage, so amount must be a number between 0 and 100
    amount = tonumber(amount)

    if (amount ~= nil and amount >= 0 and amount <= 100) then
        self.db.global.game.houseCut = amount
    end
end

function WoWGoldGambler:startGame()
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
        WoWGoldGambler[self.db.global.game.mode].gameStart(WoWGoldGambler)

        -- Inform players of the selected Game Mode and Wager
        if (self.db.global.game.houseCut == 0) then
            SendChatMessage("Game Mode - " .. self.db.global.game.mode .. " - Wager - " .. self:formatInt(self.db.global.game.wager) .. "g", self.db.global.game.chatChannel)
        else
            SendChatMessage("Game Mode - " .. self.db.global.game.mode .. " - Wager - " .. self:formatInt(self.db.global.game.wager) .. "g - House Cut - " .. self.db.global.game.houseCut .. "%", self.db.global.game.chatChannel)
        end

        -- Update UI Widgets
        self:updateUi(self.session.state, gameStates)
    else
        self:Print("A game session has already been started!")
    end
end

function WoWGoldGambler:enterMe(leaveFlag)
    -- Post a '1' in the chat channel for the dealer to register for a game.
    -- If [leaveFlag] is given, post a '-1' to the chat instead to unregister for the game.
    local message = "1"

    if (leaveFlag) then
        message = "-1"
    end

    SendChatMessage(message, self.db.global.game.chatChannel)
end

function WoWGoldGambler:lastCall()
    -- Post a message to the chat channel informing players that registration is about to end
    SendChatMessage("Last call to join!", self.db.global.game.chatChannel)
end

function WoWGoldGambler:startRolls()
    -- Ends the registration phase of the currently running session and begins the rolling phase
    if (self.session.state == gameStates[2]) then
        -- At least two players are required to play
        if (#self.session.players > 1) then
            -- Stop listening to chat messages unless they are required for the game mode
            if (WoWGoldGambler[self.db.global.game.mode].handleChatMessage == nil) then
                self:UnregisterEvent("CHAT_MSG_PARTY")
                self:UnregisterEvent("CHAT_MSG_PARTY_LEADER")
                self:UnregisterEvent("CHAT_MSG_RAID")
                self:UnregisterEvent("CHAT_MSG_RAID_LEADER")
                self:UnregisterEvent("CHAT_MSG_GUILD")
            end

            -- Start listening to system messages to recieve rolls
            self:RegisterEvent("CHAT_MSG_SYSTEM", "handleSystemMessage")

            -- Change the game state to ROLLING
            self.session.state = gameStates[3]

            -- Perform game-mode specific tasks required to start the rolling phase
            WoWGoldGambler[self.db.global.game.mode].startRolls(WoWGoldGambler)

            -- Update UI Widgets
            self:updateUi(self.session.state, gameStates)
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
        self:Print("Player registration must be done before rolling can start!")
    end
end

function WoWGoldGambler:rollMe(maxAmount, minAmount)
    -- Automatically performs a roll between [minAmount] and [maxAmount] for the dealer.
    -- If [maxValue] or [minValue] are nil, they are defaulted to appropriate values for the game mode
    if (maxAmount == nil) then
        if (self.session.modeData.currentRoll ~= nil) then
            maxAmount = self.session.modeData.currentRoll
        else
            maxAmount = self.db.global.game.wager
        end
    end

    if (minAmount == nil) then
        if (self.session.modeData.currentMinRoll ~= nil) then
            minAmount = self.session.modeData.currentMinRoll
        else
            minAmount = 1
        end
    end

    RandomRoll(minAmount, maxAmount)
end

function WoWGoldGambler:cancelGame()
    -- Terminates the currently running game session, voiding out any result
    if (self.session.state ~= gameStates[1]) then
        SendChatMessage("Game session has been canceled by " .. self.session.dealer.name , self.db.global.game.chatChannel)
        self.session.result = nil
        self:endGame()
    end
end

function WoWGoldGambler:calculateResult()
    -- Calculates the winners and losers of a session and the amount owed
    local result = {}

    result = WoWGoldGambler[self.db.global.game.mode].calculateResult(WoWGoldGambler)

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
        WoWGoldGambler[self.db.global.game.mode].detectTie(WoWGoldGambler)
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
                local loserName = self.session.result.losers[i].name

                SendChatMessage(loserName .. " owes " .. self:makeNameString(self.session.result.winners) .. " " .. self:formatInt(self.session.result.amountOwed) .. " gold!" , self.db.global.game.chatChannel)
                self:updatePlayerStat(loserName, self.session.result.amountOwed * -1)

                if (self.db.global.game.houseCut > 0) then
                    SendChatMessage(loserName .. " owes the guild bank " .. self:formatInt(houseAmount) .. " gold!" , self.db.global.game.chatChannel)
                    self.db.global.stats.house = self.db.global.stats.house + houseAmount
                    
                    if (self.session.stats.house[loserName] == nil) then
                        self.session.stats.house[loserName] = 0
                    end
                    
                    self.session.stats.house[loserName] = self.session.stats.house[loserName] + houseAmount
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
    self.session.modeData = {}
    self:cycleRaidIcon(false)

    -- Update UI Widgets
    self:updateUi(self.session.state, gameStates)
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
    -- Add a new player to the game if they meet the entry conditions. [playerRoll] can optionally be provided to pre-record a roll for the player.

    -- Check to make sure the player is on the correct realm
    if (self.db.global.game.realmFilter and playerRealm ~= GetNormalizedRealmName()) then
        SendChatMessage("Sorry " .. playerName .. ", you need to be on " .. self.session.dealer.name .. "'s realm (" .. GetNormalizedRealmName() .. ") to play." , self.db.global.game.chatChannel)
        return
    end

    -- Check to make sure the player isn't banned
    for i = 1, #self.db.global.bannedPlayers do
        if (self.db.global.bannedPlayers[i] == playerName) then
            SendChatMessage("Sorry " .. playerName .. ", you've been banned from playing." , self.db.global.game.chatChannel)
            return
        end
    end

    -- Ignore entry if player is already entered
    for i = 1, #self.session.players do
        if (self.session.players[i].name == playerName and self.session.players[i].realm == playerRealm) then
            return
        end
    end

    -- If the player is allowed to enter, create a new player entry for them
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
            return
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

function WoWGoldGambler:formatInt(number)
    -- Formats a given [number], returning it as a string with comma separators between digits
    local i, j, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)')

    int = int:reverse():gsub("(%d%d%d)", "%1,")

    return minus .. int:reverse():gsub("^,", "") .. fraction
end
