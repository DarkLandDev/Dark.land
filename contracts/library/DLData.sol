// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

library DLData{
    struct Player {
        address addr;   // player address
        bytes32 name;   // player name
        uint256 flag;   // flag
        uint8 level;    //0 - tribe;1 - knight;2 - lord;3-king;
        uint8 race;     //0 - Ocro;1 - Human;2-Elve ；3-Mage
        uint[] badgs;
    }
    
    struct Round {
        uint256 number;
        uint256 strT;   // time round started
        uint256 endT;    // time ends/ended
        bool started;
        bool ended;     // ended?
        uint256 ht;     // total ht in
        uint256 collectPot;
    }
    
    event onBattle
    (
        uint256 curRoundNumber,
        uint256 indexed playerID,
        address playerAddress,
        bytes32 playerName,
        bool repel,
        bool winner,
        bool over,
        uint256 total,
        uint256 htIn
    );
    
    event onRegisterName
    (
        uint256 indexed playerID,
        address playerAddress,
        bytes32 playerName
    );
    
    event onWithdraw
    (
        uint256 indexed playerID,
        address playerAddress,
        bytes32 playerName,
        uint256 htOut,
        uint256 timeStamp
    );
}