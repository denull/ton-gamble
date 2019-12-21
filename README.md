# Description

This is a smart-contract for TON blockchain implementing a platform for different gambling activities (such as lotteries or card games). It was made by Denis Olshin as part of Telegram contest announced on 09/24/2019 (https://t.me/contest/102).

Instructions below assume that you are using TON's lite-client with FunC and Fift binaries available at PATH, and that you're familiar with those tools.

For details about building lite-client, please refer to https://github.com/ton-blockchain/ton/tree/master/lite-client-docs. For basic info about running Fift scripts and uploading messages to TON, please refer to https://github.com/ton-blockchain/ton/blob/master/doc/LiteClient-HOWTO.

# What's included

This directory contains following files:

* `common-utils.fif`
   A Fift library with some helper functions, that could be useful for creating any kind of smart contract. You don't need to run this file.
* `gamble-utils.fif`
   Similarly to `common-utils.fif`, this is a library file. However, it contains only functions specific to this particular game contract implementation. Each other Fift script here includes it. You don't need to run this file either.
* `code.fc`
   Code of this smart contract, written in FunC. Note that it does not include get-methods (except for `seqno` method).
* `getters.fc`
   Get-methods of this smart contract. They are stored separately so you can upload your wallet code without them (it will still be functional, but will take less space).
* `code.fif`
   Compiled version of `code.fc`. Below you'll find instructions how to recompile it yourself.
* `code-getters.fif`
   Compiled version of `code.fc` + `getters.fc`.
* `init.fif`, `new-game.fif`, `join-game.fif`, `make-move.fif`, `update-game.fif`, `withdraw.fif` and `show-state.fif`
   Fift scripts for creating new contract, creating new games, placing bids and so on. Below you'll find detailed explanations about all of them.
* `test-init.fif`
   Fift script that simulates the initialisation of a contract locally, without actually uploading it to blockchain.
* `test-external.fif`
   Fift script that simulates sending an external message to a contract locally. Loads the original contract state and returns the modified one.
* `test-internal.fif`
   Fift script that simulates sending an internal message to a contract locally. Loads the original contract state and returns the modified one.
* `test-method.fif`
   Fift script that simulates executing a get-method of a smart contract for a given state. It includes `code-getters.fif`, so it can call get-methods even if the contract was uploaded without them.
* `tests`
   Directory containing some shell scripts for testing purposes. Note that you'll probably need to fix paths in them before using.

If you wish to make modifications to the contract's code, it's better to test it using `test-...` scripts without actually uploading it to the blockchain. The same can be done in case something goes wrong (see "Troubleshooting" section below).

# (Re)building the contract code

As was mentioned above, the smart contract code is located in `code.fc` and its getters are in `getters.fc`. These files are written in FunC language, so after you make any changes to them, you need to run FunC transpiler before you can upload the updated code.

Run these commands (`<path-to-source>` here is the root directory with the TON source code):

```
func -o"code-getters.fif" -P <path-to-source>/crypto/smartcont/stdlib.fc code.fc getters.fc
func -o"code.fif" -P <path-to-source>/crypto/smartcont/stdlib.fc code.fc
```

This should rebuild files `code-getters.fif` (full version of the contract) and `code.fif` (stripped-down version, without getters).

# How to use

The idea behind this smart contract is to implement a framework for different gambling activities, such as lotteries, slot machines, card and board games. Two initial examples are provided for now: a simple lottery and a Blackjack card game.

At any time the owner of the smart contract can start a new game of any supported type. After that, everyone is free to join that game by sending **an internal message** to the contract (use `join-game.fif` to generate bodies of such messages). The Gram value attached to such message becomes his stake at the game.

A lottery is the simplest case of a game. It does not require further actions from the participant or the owner (except for initiating a game). When a new game of lottery is created, the owner sets up its start/end time, min/max number of tickets sold, price of a ticket, initial prize fund, amounts of prizes and their counts/probabilities (see the `new-game.fif` script for details).

As soon as max number of tickets is sold (or at the specified end time), the prizes are distributed among participants automatically by the contract. In case there's not enough tickets sold (less than specified min number), the game is cancelled and all stakes are returned.

Other games, like a Blackjack, usually require the participant to make moves after joining the game. To do that, one generates external messages with `make-move.fif` script, signing them with a key he provided when joined the game.

In future, there planned more sophisticated games, allowing multiple participants to interact with each other (not just with the dealer). This poses some difficult problems to solve, so such games are not yet implemented. In particular, there's two requirements:
1. There should be some random, but unknown to players (until the end of the game) state. As the state of the smart contract itself is stored in the blockchain and available for everybody, it's not suitable for this purpose.
2. Players need to be able to frequently make moves during the game. Making those moves by sending messages to the contract can slow down the game, so it would be preferable to do off-chain.

To solve those problems, the owner should keep the game state externally, and update it in response to players' moves. After the game ends, the owner submits all that data to the contract for validation. Only if it's correct (does not violate game rules and contains valid players' signatures), the winner receives the prize money.

The initial state (i.e. "shuffled card deck") in such game should be chosen randomly, however some measures need to be taken to prevent altering it during the game. For that reason, some random seed is chosen at the moment of game creation (even before players join) and its hash is stored as part of the game record. When game starts, this seed is additionally hashed with the list of participants, and is used to initialise PRNG. After the game end, the owner submits the seed, so it can be validated by everyone.

It should be noted that this mechanism is not preventing the owner from cheating by joining the game as another participant. Knowing the secret random seed would allow to effectively peek into other players' hands, so there should be present some level of trust to the owner.

## Initialising a new contract
`./init.fif <workchain-id> [<filename-base>] [-C <code-fif>]`

This script is used to generate an initialisation message for your contract. It will provide you with a non-bounceable address to send some initial funds to, and after that you can upload to contract's code (using `sendfile` in your TON client).

## Starting a new game
`./new-game.fif <contract> <seqno> <game-id> <game-type> [<options>] [-O <output-boc>]`

Starts a new game with provided identifier, type and additional options.

For now, two types of games are supported:
* `0`: A lottery/slot-machine,
* `64`: Blackjack.

Additional options are:
* `-f <game-flags>` Game-specific flags,
  For Blackjack, flag 1 indicates that the 'hit on soft 17' rule should be active,
* `-s <start-time>` Unixtime when the game starts,
* `-e <end-time>` Unixtime when the game ends,
* `-n <min-tickets>` Minimum amount of tickets required for this game to be conducted,
* `-x <max-tickets>` Amount of tickets, that triggers the game,
* `-t <ticket-price>` Price of a single ticket in Grams,
* `-i <initial-fund>` Initial size of a prize fund (will be increased by the total cost of all tickets sold),
* `-c <repeat-count>` Number of times this game should be automatically repeated,
* `-d <repeat-delay>` Delay in seconds between game repeats,
* `-p <prize-id> <fixed-amount> <prize-fund-percent>`
  Defines a prize with a fixed value in Grams plus a some percentage of the prize fund.
* `-l <prize-id> <fixed-amount> <prize-fund-percent> <per-prize-probability> <ticket-count> <per-ticket-probability>`
  Defines a prize in a lottery (see -p option above) with the probability of giving out this prize at all, number of tickets that can possibly receive, and probability to receive it for each ticket.

Option `-l` can be used multiple times to define multiple prizes. For Blackjack, a `-p` option should used exactly twice: to define prizes for a win (`prize_id=1`) and for a tie (`prize_id=2`). Prize for a tie is usually equal to 100% of the "ticket price" (player's bid).

For Blackjack (and other games with arbitrary bids), `<min-tickets>`, `<max-tickets>` fields should not be used. `<ticket-price>` is used as a minimum size of a bid.

For example:
`./new-game.fif lottery-game 1 0 -e 1577825999 -n 100 -x 1000 -i 500 -t 1 -p 1 500 0 1 1 100 -p 2 0 0.5 100 100 100 -p 3 2 0 100 50 60`
Create a lottery that ends on December 31st of 2019, with a minimum of 100 and a maximum of 1000 participants. One ticket has a price of 1 Gram. The initial size of a prize fund is 500 Grams, this is a Jackpot, which will be given with a 1% probabiltity. Additionally, there's 100 prizes with each one equal to 0.5% of the total prize fund (i.e. 50% in total), and 50 prizes 2 Grams each (100 Grams total), but each of these 50 prizes has only 60% probability (so in reality there will be less than 50 prizes).

`./new-game.fif blackjack-game 2 64 -t 10 -p 1 2 200 -p 2 0 100`
Create a game of Blackjack, with a minimum bid equal to 10 Grams, and a prize equal to 2 Grams + double your bid. There's no time restriction (you can play at any time, until the owner cancels this game).

## Canceling/deleting a game
`./cancel-game.fif <contract> <seqno> <game-id> [-O <output-boc>]`

The owner can cancel a game at any moment. All currently bought tickets/bids will be returned to players.

Also this method should be used to delete old archived games. A game becomes archived after its completion. It's not removed automatically to allow players to check their final states/prizes.

## Joining a game
`./join-game.fif <game-id> [<key-name> <ticket-count>] [-O <output-boc>]`

Prepare an internal message body to participate in a game with the specified identifier. You can also provide the number of tickets you wish to buy (for lottery-style games only; games with arbitrary bids should always accept a single ticket).

After running this script, you'll have two files: a private key (in `<key-name>.pk`) to later sign your moves, and a internal message's body in `<output-boc>.boc`. That body you need to send in a internal message from your wallet, with the required amount of Grams attached to it.

After that you'll become a participant of that game.

## Making a move
`./make-move.fif <contract-addr> <key-name> <seqno> <game-id> <action> [-O <output-boc>]`

Make a move in a game that you're participating in. You need to provide a game contract address and also a `<key-name>`, pointing to a file, generated with `join-game.fif`.

For lotteries, there's only one possible action: `0`, to "ping" a lottery. This will trigger a raffle if a lottery is ended.

For Blackjack, you have two usual options: to stand (action = `0`) or to hit (action = `1`). After that the dealer's turn will be computed automatically. To inspect your current cards in hand, export the current contract's state (via `getaccountdata` command in liteclient) and then use the `show-state.fif` script (see below). It will display your cards (and show their numeric value). The same can be done to check your last game outcome (including the final hands).

## Updating game state
`./update-game.fif <contract> <seqno> <game-id> <state-boc> [-O <output-boc>]`

This script will later be used to synchronise the off-chain state with the on-chain one. It's required when an off-chain game ends, or when any participant of a game forces such update (by committing a move to the contract).

As now there's no games with the support of off-chain interaction, this is not supported yet.

## Withdrawing funds from the contract
`./withdraw.fif <contract> <dest-addr> <seqno> <amount> [-O <output-boc>]`

At any moment, the owner of the contract can withdraw any amount of Grams stored in it, if the remaining balance of enough to pay back all current bids.

## Upgrading contract's code
`./upgrade-code.fif <contract> <seqno> [-C <code-fif>] [-O <output-boc>]`

Use this request to update your contract's code. By default it uses code from `code-getters.fif`, but you can pass any file via `-C` option.

## Inspecting cotract's state
`./show-state.fif <data-boc>`

This script will help you to examine the current state of the contract. First, you need to download its state using the `saveaccountdata <filename> <addr>` command in the shell of your client. After that you can pass the generated boc-file to this script.

It should output detailed info about cotract's params, list of active games, information about each player and per-player results in a previous game. Alternatively, you can use get-methods to inspect those values (see the next section).

# Get methods

In case you've used the default (non-stripped down) version of the contract, it will include some get-methods. You can run them in the TON client using the `runmethod` command. Note that they return raw data, so you may prefer using `show-state.fif` instead (see "Inspecting contract's state" section). 

List of available methods:
* `seqno`
   Returns the current stored value of seqno for this wallet. This method is available in the stripped-down version too.
* `owner_pubkey`
   Returns the public key of this contract's owner.
* `reserved_amount`
   Returns the amount of nanograms that are currently reserved (i.e. cannot be withdrawn).
* `games`
   Returns the list of currently active games.
* `prizes(game_id)`
   Returns the list of prizes in a game.
* `participants(game_id)`
   Returns the list of players in a game.

# Troubleshooting

After the request is uploaded to TON, there's no practical way to check what's happening with it (until it will be accepted). So if something goes wrong and your message is not accepted by the contract, you can only guess why.

Fortunately, there's couple of scripts that will help in this situation. First, you need to perform `saveaccountdata <filename> <addr>` command in the TON client shell. This will produce a boc-file containing current state of your contract.

Now you can inspect it using `show-state.fif`. Alternatively, you can manually call get-methods of the contract using `test-method.fif` (it should produce the same info, but in raw format).

But most importantly, you can run `test-external.fif` or `test-internal.fif` with a message file (that you were trying to upload) to simulate the execution of the smart contract, and check the TVM output. In addition to builtin errors, there are some error codes that could be thrown:

* Error **33**. *Invalid outer seqno*.
   The current stored seqno is different from the one in the incoming message.
* Error **34**. *Invalid signature*.
   The signature of this message is invalid.
* Error **35**. *Message is expired*.
   The message has a valid_until field set and it's in the past. Note that the provided Fift scripts do not set this field (you can set the expiration time for an order, but not for a message containing it).
* Error **36**. *Game not found*.
   The game with that identifier is not found (cancelled, completed, or never existed).
* Error **37**. *Invalid game type*.
   This game has an invalid type.
* Error **38**. *Game is not yet ended*.
   You can't trigger a lottery raffle before it ended.
* Error **40**. *Participant not found*.
   The public key you've provided is not among registered participants of this game.
* Error **41**. *Wrong workchain id*.
   The workchain does not match.
* Error **43**. *This amount is too large to withdraw*.
   By withdrawing the provided amount of Grams, the remaining balance will be less than the currently reserved amount.
* Error **44**. *Duplicate game id*.
   Game with this id already exists.
* Error **46**. *Game is not yet started*.
   You can't participate before the game is started.
* Error **47**. *Game is already ended*.
   You can't participate after the game end.
* Error **48**. *Ticket count must be non-negative*.
   The amount of tickets you're trying to buy is less or equal to zero.
* Error **49**. *Not enough money to buy specified number of tickets*.
   The attached value in Grams should be at least equal to the specified ticket price multiplied by number of tickets.
* Error **52**. *A bid is already placed*.
   This game does not allow adding money to your initial bid.
* Error **53**. *Game is archived*.
   This game is already finished and now archived, nobody can join it.

# Fift words conventions

Fift language is quite flexible, but it can be difficult to read. There's two main reasons for that: stack juggling and no strict conventions for word names. To make the code more readable, some custom conventions were introduced within this repository:

`kebab-case-words()` are helper functions (defined in `common-utils.fif`). Note that the name includes the parentheses at the end. (The only exceptions are `maybe,` and `maybe@+`)

`CamelCaseWords` are constants, defined using a `=:` word.

Those styles are chosen to stand out from the builtin words and from each other as much as possible.
