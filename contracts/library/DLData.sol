// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

library DLData{
    struct Player {
        address addr;   // player address
        bytes32 name;   // player name
        uint256 flag;   // flag
        uint8 level;    //0 - tribe;1 - knight;2 - lord;3-king;
        uint8 race;     //0 - Ocro;1 - Human;2-Elve ；3-Mage
        uint[] badges;
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
    
}