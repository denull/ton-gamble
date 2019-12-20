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

At any time the owner of the smart contract can start a new game of any supported type. After that, everyone is free to join that game.

A lottery is the simplest case of a game. It does not further actions from the owner (except for starting a game). When a new game of lottery is created, the owner sets up its start/end time, min/max number of tickets sold, price of a ticket, initial prize fund, amounts of prizes and their counts/probabilities.

As soon as max number of tickets is sold (or at the specified end time), the prizes are distributed among participants automatically by the contract. In case there's not enough tickets sold (less than specified min number), the game is cancelled and all stakes are returned.

More interactive games, such as Blackjack or Poker, require the owner of the contract to participate in the process more actively. This is because of two reasons:
1. There should be some random, but unknown to players (until the end of the game) state. As the state of the smart contract itself is stored in the blockchain and available for everybody, it's not suitable for this purpose.
2. Players need to frequently make moves during the game. Making those moves by sending messages to the contract can slow down the game, so it would be preferable to do off-chain.

To solve those problems, the owner should keep the game state externally, and update it in response to players' moves. After the game ends, the owner submits all that data to the contract for validation. Only if it's correct (does not violate game rules and contains valid players' signatures), the winner receives the prize money.

The initial state (i.e. "shuffled card deck") in such game should be chosen randomly, however some measures need to be taken to prevent altering it during the game. For that reason, some random seed is chosen at the moment of game creation (even before players join) and its hash is stored as part of the game record. When game starts, this seed is additionally hashed with the list of participants, and is used to initialise PRNG. After the game end, the owner submits the seed, so it can be validated by everyone.

It should be noted that this mechanism is not preventing the owner from cheating by joining the game as another participant. Knowing the secret random seed would allow to effectively peek into other players' hands, so there should be present some level of trust to the owner.

## Initialising a new contract
`./init.fif <workchain-id> [<filename-base>] [-C <code-fif>]`

This script is used to generate an initialisation message for your contract. It will provide you with a non-bounceable address to send some initial funds to, and after that you can upload to contract's code (using `sendfile` in your TON client).

## Starting a new game
`./new-game.fif <contract> <seqno> <game-id> <game-type> [-O <output-boc>]`
(external)

## Canceling a game
`./cancel-game.fif <contract> <seqno> <game-id> [-O <output-boc>]`
(external)

## Joining a game
`./join-game.fif <game-id> [-O <output-boc>]`
(internal)

## Making a move
`./make-move.fif <contract-addr> <seqno> <game-id> [-O <output-boc>]`
(external)

## Updating game state
`./update-game.fif <contract> <seqno> <game-id> <state-boc> [-O <output-boc>]`
(external)

## Withdrawing funds from the contract
`./withdraw.fif <contract> <dest-addr> <seqno> <amount> [-O <output-boc>]`

At any moment, the owner of the contract can withdraw any amount of Grams stored in it, if the remaining balance of enough to pay back all current bids.

## Upgrading contract's code
`./upgrade-code.fif <contract> <seqno> [-C <code-fif>] [-O <output-boc>]`

Use this request to update your contract's code. By default it uses code from `code-getters.fif`, but you can pass any file via `-C` option.

## Inspecting cotract's state
`./show-state.fif <data-boc>`

This script will help to examine the current state of the contract. First, you need to download its state using the `saveaccountdata <filename> <addr>` command in the shell of your client. After that you can pass the generated boc-file to this script.

It should output detailed info about cotract's params, list of active games and bids. Alternatively, you can use get-methods to inspect those values (see the next section).

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
* `players(game_id)`
   Returns the list of players in a game.

# Troubleshooting

After the request is uploaded to TON, there's no practical way to check what's happening with it (until it will be accepted). So if something goes wrong and your message is not accepted by the contract, you can only guess why.

Fortunately, there's couple of scripts that will help in this situation. First, you need to perform `saveaccountdata <filename> <addr>` command in the TON client shell. This will produce a boc-file containing current state of your contract.

Now you can inspect it using `show-state.fif`. Alternatively, you can manually call get-methods of the contract using `test-method.fif` (it should produce the same info, but in raw format).

But most importantly, you can run `test-external.fif` or `test-internal.fif` with a message file (that you were trying to upload) to simulate the execution of the smart contract, and check the TVM output. In addition to builtin errors, there are some error codes that could be thrown:

* Error **33**. *Invalid outer seqno*.
   The current stored seqno is different from the one in the incoming message.

# Fift words conventions

Fift language is quite flexible, but it can be difficult to read. There's two main reasons for that: stack juggling and no strict conventions for word names. To make the code more readable, some custom conventions were introduced within this repository:

`kebab-case-words()` are helper functions (defined in `common-utils.fif`). Note that the name includes the parentheses at the end. (The only exceptions are `maybe,` and `maybe@+`)

`CamelCaseWords` are constants, defined using a `=:` word.

Those styles are chosen to stand out from the builtin words and from each other as much as possible.
