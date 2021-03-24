-- Slash Command Handlers --

function WoWGoldGambler:allStats()
    -- Post all player stats in the db to the chat channel
    WoWGoldGambler:reportStats()
end

function WoWGoldGambler:sessionStats()
    -- Post player stats from the current session to the chat channel
    WoWGoldGambler:reportStats(true)
end

function WoWGoldGambler:joinStats(info, args)
    -- Set up an alias of [newAlt] for [newMain]. Players with one or more aliases will have the aliased players' stats joined with their own at reporting time.
    -- [newMain] and [newAlt] are parsed out of the given [args] via a string split on the space character
    local newMain, newAlt = strsplit(" ", args)

    for main, aliases in pairs(self.db.global.stats.aliases) do
        -- Check all aliases for all mains to ensure newMain and newAlt are not already associated with a main
        for i = 1, #aliases do
            -- newAlt is already an alias for someone else
            if (aliases[i] == newAlt) then
                self:Print("Unjoining " .. newAlt .. " from " .. main .. " so it can be joined with " .. newMain .. " instead.")
                tremove(self.db.global.stats.aliases[main], i)
            -- newMain is already an alias for someone else
            elseif (aliases[i] == newMain) then
                self:Print("Joining " .. newAlt .. " to " .. main .. " instead, as it is already joined with " .. newMain)
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
            self:Print("Joining " .. self.db.global.stats.aliases[newAlt][i] .. " to " .. newMain .. " as it was previously joined to " .. newAlt)
            tinsert(self.db.global.stats.aliases[newMain], self.db.global.stats.aliases[newAlt][i])
        end

        self.db.global.stats.aliases[newAlt] = nil
    end

    self:Print("Successfully joined [main] " .. newMain .. " and [alt] " .. newAlt .. ".")
end

function WoWGoldGambler:unjoinStats(info, player)
    -- Remove all aliases for [player] and ensure [player] isn't an alias for anyone else
    for main, aliases in pairs(self.db.global.stats.aliases) do
        if (main == player) then
            self.db.global.stats.aliases[main] = nil
            self:Print("Successfully unjoined " .. player .. " from all aliases.")
        else
            for i = 1, #aliases do
                if (aliases[i] == player) then
                    tremove(self.db.global.stats.aliases[main], i)

                    -- If this was the only alias for the main, remove it from the alias list
                    if (#self.db.global.stats.aliases[main] == 0) then
                        self.db.global.stats.aliases[main] = nil
                    end

                    self:Print("Successfully unjoined " .. player .. " from " .. main .. ".")

                    return
                end
            end
        end
    end
end

function WoWGoldGambler:listAliases(info)
    -- Prints out the list of all aliases to the user
    for main, aliases in pairs(self.db.global.stats.aliases) do
        local nameString = aliases[1]

        for i = 2, #aliases do
            nameString = nameString .. ", " .. aliases[i]    
        end

        self:Print("[main] " .. main .. " is merged with [alts] " .. nameString)
    end
end

function WoWGoldGambler:updateStat(info, args)
    -- Add [amount] to the [player]'s stats. Negative numbers can be used to subtract from [player]'s stats
    -- [player] and [amount] are parsed out of the given [args] via a string split on the space character
    local player, amount = strsplit(" ", args)

    amount = tonumber(amount)

    if (player ~= nil and amount ~= nil) then
        local oldAmount = self.db.global.stats.player[player]

        if (oldAmount == nil) then
            oldAmount = 0
        end

        self:updatePlayerStat(player, amount)
        self:Print("Successfully updated stats for " .. player .. " (" .. oldAmount .. " -> " .. self.db.global.stats.player[player] .. ")")
    else
        self:Print("Could not add given amount (" .. tostring(amount) .. ") to " .. tostring(player) .. "'s stats due to invalid input.")
    end
end

function WoWGoldGambler:deleteStat(info, player)
    -- Permanently delete the stats for the given [player]
    if (self.db.global.stats.player[player] ~= nil) then
        self.db.global.stats.player[player] = nil
    end

    if (self.session.stats.player[player] ~= nil) then
        self.session.stats.player[player] = nil
    end

    self:Print("Successfully removed stats for " .. player .. ".")
end

function WoWGoldGambler:resetStats(info)
    -- Deletes all stats!
    self.db.global.stats = {
        player = {},
        aliases = {}
    }

    self.session.stats = {
        player = {}
    }

    self:Print("Stats have been reset!")
end

-- Implementation --

function WoWGoldGambler:updatePlayerStat(playerName, amount)
    -- Update a given player's stats by adding the given amount
    if (self.db.global.stats.player[playerName] == nil) then
        self.db.global.stats.player[playerName] = 0
    end

    if (self.session.stats.player[playerName] == nil) then
        self.session.stats.player[playerName] = 0
    end

    self.db.global.stats.player[playerName] = self.db.global.stats.player[playerName] + amount
    self.session.stats.player[playerName] = self.session.stats.player[playerName] + amount
end

function WoWGoldGambler:reportStats(sessionFlag)
    -- Post all player stats to the chat channel, ordered from highest winnings to lowest losings.
    -- If the sessionFlag is true, print session stats instead of all-time stats and track house stats per-player
    local sortedPlayers = {}
    local stats = {}
    local houseStats = {}
    local houseTotal = 0

    -- Create a copy of the appropriate stats
    if (sessionFlag) then
        for player, winnings in pairs(self.session.stats.player) do
            stats[player] = winnings
        end

        for player, owings in pairs(self.session.stats.house) do
            houseStats[player] = owings
            houseTotal = houseTotal + owings
        end
    else
        for player, winnings in pairs(self.db.global.stats.player) do
            stats[player] = winnings
        end
    end

    -- Merge alias player stats into their mains
    for player, _ in pairs(stats) do
        if (self.db.global.stats.aliases[player] ~= nil) then
            for i = 1, #self.db.global.stats.aliases[player] do
                local alias = self.db.global.stats.aliases[player][i]

                if (stats[alias] ~= nil) then
                    stats[player] = stats[player] + stats[alias]
                    stats[alias] = nil

                    if (houseStats[alias] ~= nil) then
                        if (houseStats[player] == nil) then
                            houseStats[player] = 0
                        end

                        houseStats[player] = houseStats[player] + houseStats[alias]
                        houseStats[alias] = nil
                    end
                end
            end
        end
    end

    -- Add all players with stats to the sortedPlayers array
    for player, winnings in pairs(stats) do
        if winnings ~= nil then
            tinsert(sortedPlayers, player)
        end
    end

    -- Sort the sortedPlayers array by their winnings
    -- BUG: When using SendChatMessage on the guild channel, the messages lose their order. This appears to be an issue with the Blizzard API
    -- To work around this, we would have to confirm each stat has been sent before sending the next one. Seems like a lot of work.
    table.sort(sortedPlayers, function(a, b)
        return stats[a] > stats[b]
    end)

    -- Post the stats to the chat channel
    if (sessionFlag) then
        SendChatMessage("-- WoWGoldGambler Session Stats --", self.db.global.game.chatChannel)
        SendChatMessage("The house has taken " .. self:formatInt(houseTotal) .. " gold!", self.db.global.game.chatChannel)
    else
        SendChatMessage("-- WoWGoldGambler All Time Stats --", self.db.global.game.chatChannel)
        SendChatMessage("The house has taken " .. self:formatInt(self.db.global.stats.house) .. " gold!", self.db.global.game.chatChannel)
    end

    for i = 1, #sortedPlayers do
        local amount = stats[sortedPlayers[i]]
        local wonOrLost = " has won "

        if (amount < 0) then
            wonOrLost = " has lost "
            amount = amount * -1
        end

        if (houseStats[sortedPlayers[i]] ~= nil) then
            SendChatMessage(i .. ". " .. sortedPlayers[i] .. wonOrLost .. self:formatInt(amount) .. " gold and owes the guild bank " .. houseStats[sortedPlayers[i]] .. " gold!", self.db.global.game.chatChannel)
        else
            SendChatMessage(i .. ". " .. sortedPlayers[i] .. wonOrLost .. self:formatInt(amount) .. " gold!", self.db.global.game.chatChannel)
        end
    end
end