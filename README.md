# WoWGoldGambler

WoWGoldGambler is a World of Warcraft addon (inspired by the [Cross Gambling](https://www.curseforge.com/wow/addons/cross-gambling) addon) which allows you to gamble in-game currency with your party, raid or guild members via a variety of game modes.

## How To Play

To start a game session, the Dealer (ie. the owner of the addon) must first bring up the WoWGoldGambler UI using the **/wgg show** command, or by clicking the WoWGoldGambler minimap icon. To hide the UI, the Dealer can use the **/wgg hide** command, or simply click the minimap icon once more.

Before starting a game, the Dealer should configure the game options to their liking (game options are described in the 'Game Options' section below). Once configured, the Dealer should simply click the 'Start Game' button to start a new game.

Once a game session is started, WoWGoldGambler will notify players of the Game Mode, Wager and House Cut amount selected by the Dealer. Players can register to play by typing '1' into the appropriate chat channel (Party, Raid, or Guild - whichever WoWGoldGambler is active in). If a player has already registered for the game and wishes to unregister, they can do so by typing '-1' in chat.

The Dealer can start the rolling phase of the game as soon as they feel enough players have registered by clicking the 'Start Rolls' button. They can optionally click the 'Last Call' button prior to rolling to notify players that registration is about to close.

Once the rolling phase is started, WoWGoldGambler will close registration and notify all players of the amount they have to /roll. All registered players must /roll the appropriate amount (varying depending on the selected Wager and Game Mode) for the game to resolve.

After all players have rolled, WoWGoldGambler will determine the winner(s), loser(s) and how much gold is owed using the rules defined for the selected Game Mode (rules for each Game Mode are described in the 'Game Modes' section below). If a tie occurs, a series of tie-breaker rounds will be performed using the same rules until one winner and one loser remain.

WoWGoldGambler will then notify players of the results and close the game session. The loser must trade the amount of gold owed to the winner - the Dealer can ban players from future rounds if they refuse to pay their losses!

### Game Options

The owner of the addon has a number of options they should configure before starting a game session. Once a game session is started, all game options will be locked and cannot be changed until the round is completed.

##### Wager Amount

The Wager Amount can be set using the 'Wager Amount' textbox in WoWGoldGambler UI. This amount will determine how much players stand to lose when playing. In some game modes the loser will lose the entire wager amount, meanwhile in others the loser will lose a variable amount up to the wager amount. Players will never lose more than the wager amount.

##### Game Mode

To change the Game Mode, the Dealer must first click the 'Options' button in the bottom right of the WoWGoldGambler UI. This will reveal additional options to the Dealer. They can select their desired Game Mode using the '<' and '>' buttons to cycle through options in the 'Game Mode' textbox.

##### Chat Channel

WoWGoldGambler can be played in either Party, Guild or Raid chat. When using Guild chat, it should be noted that the Blizzard API for Guild chat does not guarantee message order (this can affect WoWGoldGambler output).

To change the Chat Channel, the Dealer must first click the 'Options' button in the bottom right of the WoWGoldGambler UI. This will reveal additional options to the Dealer. They can select the Chat Channel they wish to play in using the '<' and '>' buttons to cycle through options in the 'Chat Channel' textbox.

##### House Cut

WoWGoldGambler can be configured to pay out a given percentage of winnings to the 'house' (ie. the guild bank). This can be a useful way of injecting gold into the guild bank at the end of a long, repair-heavy raid night!

To set a House Cut, the Dealer must first click the 'Options' button in the bottom right of the WoWGoldGambler UI. This will reveal additional options to the Dealer. They can then enter an amount between 0 and 100 into the 'House Cut' textbox.

## Game Modes

There are currently six supported Game Modes for WoWGoldGambler. More Game Modes will likely be added in the future (I am open to suggestions!).

### Classic

This Game Mode should be familiar to anyone who has gambled with the [Cross Gambling](https://www.curseforge.com/wow/addons/cross-gambling) addon before. When the rolling phase of a game session begins, all players must /roll the wager amount.

**Winner**: The player who rolled the highest

**Loser**: The player who rolled the lowest

**Payment Amount**: The difference between the winning and losing rolls

### Coinflip

Coinflip is a tournament-style Game Mode resolved through multiple tie-breaker rounds. When the rolling phase of the game session begins, all players must /roll 2. Players who rolled a 2 will be entered into a Winner's Bracket and players who rolled a 1 will be entered into a Loser's Bracket.

Players in the Winner's Bracket will then /roll 2 again. Players who again roll a 2 get to stay in the Winner's Bracket, meanwhile players who roll a 1 are disqualified. If all players roll a 1, they all stay in the Winner's Bracket. Tie-breaker rolls are continued until only one winner remains.

Once a winner is determined, players in the Loser's Bracket will also have to /roll 2. Players who roll a 1 stay in the Loser's Bracket, meanwhile players who roll a 2 are removed from it. If all players roll a 2, they all stay in the Loser's Bracket. Tie-breaker rolls are continued until only one loser remains.

**Winner**: The player who rolled the most 2's

**Loser**: The player who rolled the most 1's

**Payment Amount**: The wager amount

### Roulette

The Roulette Game Mode is a low-odds, high-payout game mode. It can also have low barrier to entry (ie. a low wager can be set, while still paying out well).

During the registration phase of a Roulette game players enter by typing any number between 1 and 36 (inclusive) in the appropriate chat channel. The number they enter becomes their 'roll' (ie. They are betting on that number).

When the rolling phase of the game session begins, WoWGoldGambler will automatically perform a /roll 36. The results are then immediately calculated (players do not have to /roll).

There are no tie-breaker rounds in Roulette. In the case of a tie, all winners will split the winnings.

If no player guessed the Dealer roll correctly, the round is a draw (nobody wins or loses).

**Winner**: The player(s) whose entry number was rolled by the Dealer

**Loser**: **ALL** players whose entry number was not rolled by the Dealer

**Payment Amount**: The wager amount

### Price Is Right

The Price Is Right Game Mode adds an interesting layer of strategy to the game and can make high rolls costly!

When the rolling phase of the game session begins, WoWGoldGambler will automatically perform a /roll for the wager amount. The result of this roll will determine the 'price'.

All players can then /roll any amount they want with the goal of rolling as close to the 'price' as possible, without going over.

**Winner**: The player whose roll was closest to the Dealer's roll while not being larger than the Dealer's roll

**Loser**: The player whose roll was furthest from the Dealer's roll (in either direction - under or over)

**Payment Amount**: The difference between the loser's roll and the Dealer's roll

### Poker

This game mode changes up the way rolls are scored by introducing a Poker theme.

When the rolling phase of a game session begins, all players must /roll 11111-99999. As rolls come in, WoWGoldGambler will translate your 5-digit roll into a 5-card poker hand, with each digit representing a 'card' ranking from 0-9 with no suits.

All five 'cards' are used when comparing hands (ie. A pair of 8's with kickers 7, 6 and 5 beats a pair of 8's with kickers 7, 6 and 4).

**Winner**: The player who rolled the best poker hand

**Loser**: The player who rolled the worst poker hand

**Payment Amount**: The wager amount

### Chicken

Chicken is a game mode that adds a layer of strategy to the game similar to that of a game of Blackjack.

When the rolling phase of a game session begins, WoWGoldGambler will determine a Bust Amount and a Roll Amount. The Bust Amount will always be equal to the Wager amount, meanwhile the Roll Amount will be a randomly selected amount between 50% and 120% of the Wager amount.

All players can then /roll the Roll Amount as many times as they like. Each of their results will be added together to determine their Roll Total. If a player's Roll Total exceeds the Bust Amount, they will automatically lose!

When a player is happy with their Roll Total, they can enter '-1' into the appropriate chat cannel to lock in their roll. They will not be eligible for more rolls.

Once all players have either Busted or locked in their rolls, WoWGoldGambler will calculate the results.

There are no tie-breaker rounds in Chicken. In the case of a low-end tie, all losers must pay the winner the amount owed. In the case of a high-end tie, all winners will split the winnings.

**Winner**: The player(s) with the highest roll total which does not exceed the bust amount.

**Loser**: **ALL** player(s) who's roll total exceeds the bust amount. If no player's roll total exceeds the bust amount, then the player(s) with the lowest roll total.

**Payment Amount**: If at least one player's roll total exceeds the bust amount, the full wager amount is owed. If no player's roll total exceeds the bust amount, the difference between the losing and winning roll totals is owed.

### 1v1 Death Roll

Death Roll is played head-to-head between two players. During registration, only two players will be allowed to join.

When the rolling phase of a game session begins, WoWGoldGambler will automatically perform a roll (/roll 2) to determine which of the two players will go first.

The current player must then perform a /roll for the wager amount. If a 1 is rolled, they lose. Otherwise, the other player must perform a /roll for the result of the previous roll (ie. if a 12 was rolled, the next player will /roll 12). This continues until one of the players roll a 1.

**Winner**: The player who did NOT roll a 1

**Loser**: The player who rolled a 1

**Payment Amount**: The wager amount

## Other Features

### Stat Tracking

WoWGoldGambler keeps track of winnings and losses from all game sessions to see who the real winners and losers are. All-time stats can be posted to the chat channel using the **/wgg allstats** command, and session stats (winnings/losses since the Dealer last logged in) can be shared with the **/wgg stats** command. The amount of gold taken by the house (via configuring a House Cut amount) is also tracked alongside player stats. House cut stats will be tracked on a per-player basis in the session stats so players can easily see how much in total they owe the guild bank at the end of a session.

The Dealer can also record a list of aliases for players who participate on multiple characters using the **/wgg joinstats [main] [alt]** command. When this is done, stats for [alt] will be reported together under the name of [main]. A [main] can have multiple aliases, so players can play on any number of alts and have all of their stats tracked together. The Dealer can view a list of all configured aliases using the **/wgg listaliases** command.

If a player wishes to unmerge the stats of one of their characters, the alias can be removed with the **/wgg unjoinstats [player]** command.

Stats can also be manually adjusted by using the **/wgg updatestat [player] [amount]** command. This command simply adds the given [amount] to the given [player]'s stats. A negative number should be used to subtract from a player's stats.

This allows the Dealer to make corrections to the stats in cases where the addon fails, or external factors affect the outcome (ie. a verbal agreement). This also allows you to transfer stats from some other location (ie. a ledger or another gambling addon) into WoWGoldGambler to easily pick up where you left off.

Lastly, the Dealer can remove a player entirely from the stats by using the **/wgg deletestat [player]** command. Alternatively, if the Dealer wishes to delete all stats, **/wgg resetstats** can be used. **These commands should not be used lightly, as the stats will be permanently deleted!**

### Dealer Features

Alongside the Game Options and Controls, the WoWGoldGambler UI also has a number of features which make it easier for the Dealer to play.

To automatically join a game session, the Dealer can click the 'Join Game' button to automatically post a '1' in the appropriate chat channel. After joining, the 'Join Game' button will become a 'Leave Game' button, which can now be clicked to automatically unregister from the game by posting a '-1' to the chat.

When playing the Roulette game mode, WoWGoldGambler will always register with the number 36 by default. This default can be changed to a number of your choice (between 1 and 36) using the **/wgg setroulettenumber [number]** command.

WoWGoldGambler can also automatically perform rolls for the Dealer when they click the 'Roll For Me' button. The roll performed will always be appropriate for the selected Game Mode (ie. the wager amount for the Classic game mode, or 2 for the Coinflip game mode).

### Player Banning

If a player refuses to pay their losses, or if they engage in griefing behaviour (ie. registering for a game and never rolling), the Dealer can ban them from playing using the **/wgg ban [player]** command. This will prevent the given player from being able to register for future games. To undo the ban, the Dealer can use the **/wgg unban [player]** command. The Dealer can view a list of all banned players using the **/wgg listbans** command.

### Realm Filtering

Since players cannot trade gold between realms, WoWGoldGambler will disallow players from other realms (ie. not the Dealer's realm) from registering for games. This prevents scenarios where a losing player can't physically trade their owed amount to a winning player.

However, there can be situations where the Dealer may want to allow players from other realms to participate in games. For example: players from connected realms, or players who have an alt on the Dealer's realm and can still pay their losses at a later time. The Dealer can turn off Realm Filtering using the **/wgg realmfilter** command if such a scenario were to arise.

To turn the Realm Filter back on, the Dealer should simply use the **/wgg realmfilter** command once again to toggle it back on.
