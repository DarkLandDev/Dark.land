// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;


import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./library/Ownable.sol";
import './library/DLData.sol';
import './library/NameFilter.sol';

contract Chapter1 is Ownable{
    using SafeMath for uint256;
    using NameFilter for string;
    
    uint256 roundMax = 20;
    uint256 initHp = 1000;
    uint8 race = 0;
    uint256 registrationFee = 10 ether; // price to register a name
    
    uint256 public curRoundNumber = 0;// current round;
    uint256 public pID = 0;// total number of players;
    
    struct Dragon {
        uint256 number;
        uint256 hp;
        uint256 sleep;
        bool alive;
        uint256 endT;
        bool hide;
    }
    struct LuckBox{
        address winner;
        address repel;
    }
    struct SafeBox{
        address addr;
        uint256 earned;
        uint256 total;
        mapping(uint256 => uint256) records;
    }
    
     struct RoundInfo{
        DLData.Round round;
        uint256 hp;
        uint256 sleep;
        LuckBox box;
    }
    struct playerInfo{
        DLData.Player player;
        uint256 earned;
        uint256 total;
        uint256 collectable;
    }
    struct InvestInfo{
        bool isDelete;
        uint256 pID;
        uint256 invest;
    }
    
    InvestInfo[] allInvest;
    mapping(uint256 => uint256) investOrders;
    
    mapping(address => uint256) public pIDxAddr; // (addr => pID) returns player id by address;
    mapping(uint256 => SafeBox) public safeBoxs;// (pId => SafeBox) returns SafeBox by pID;
    mapping(uint256 => LuckBox) public luckBoxs;// (rounNumber => LuckBox) returns LuckBox;
    mapping(uint256 => DLData.Player) public players;// all players
    
    mapping(uint256 => Dragon) public deadDragon;
    mapping(uint256 => DLData.Round) public pastRound;
    
    DLData.Player[] public dragonSlayers;
    
    Dragon private curDragon;
    DLData.Round private curRound;
    
    modifier isActivated() {
        require(curDragon.alive == true && curRound.started == true, "Please wait for the dragon to be summoned..."); 
        _;
    }
    
    modifier isHuman() {
        address _addr = msg.sender;
        uint256 _codeLength;
        
        assembly {_codeLength := extcodesize(_addr)}
        require(_codeLength == 0, "sorry humans only");
        _;
    }

    //limit 10/20/50/100 ht
    modifier isWithinLimits(uint256 _ht) {
        require(_ht == 10 ether || _ht == 20 ether || _ht == 50 ether || _ht == 100 ether, "Note:Must be 10/20/50/100.");
        _;    
    }
    
    function withdraw()
        isHuman()
        public
    {
        uint _pId = getPID(msg.sender);
        SafeBox storage _box = safeBoxs[_pId];
        require(_box.earned > 0,"ummmm...,Inoperable,the amount is 0.");
        
        uint256 _m = _box.earned;
        
        _box.earned = 0;
        pay(payable(_box.addr), _m);
        
        emit DLData.onWithdraw
        (
            _pId,
            msg.sender,
            players[_pId].name,
            _m,
            block.timestamp
        );
    }
    
    function newDragon(uint256 _r,uint256 _h)
        onlyOwner()
        public
    {
        require(curRoundNumber < roundMax,"Maximum is 20,exceed...");
        
        delete allInvest;
        
        //new Dragon;
        uint256 _now = block.timestamp;
        uint256 _R = curRoundNumber.add(1);
        
        uint256 _hp = randMod(_r).mul(initHp).mul(10 ** 18);
        uint256 _sleep = randMod(_h).mul(60);//s
        curDragon = Dragon(_R,_hp,_sleep,true,_now,false);
        
        //new round;
        curRound.number = _R;
        curRound.strT = _now;
        curRound.started = true;
        
        curRoundNumber++;
    }
    
    function battle()
        isActivated()
        isHuman()
        isWithinLimits(msg.value)
        public
        payable
    {
        uint _pId = getPID(msg.sender);
     
        //1: delete Non-Reward player
        deleteCollectPlayer();
        //1:distribute player deposit
        if(allInvest.length == 0){
            uint256 _pidDev = getPID(owner());
            safeBoxs[_pidDev].addr = owner();
            safeBoxs[_pidDev].earned = safeBoxs[_pidDev].earned.add(msg.value.mul(45).div(100));  
        }else{
            distribute(msg.value.mul(45).div(100));
        }
        
        //2:save player deposit;
        InvestInfo memory _investInfo;
        _investInfo.pID = _pId;
        _investInfo.invest = msg.value;
        
        //3: start reward next round;
        curRound.collectPot = curRound.collectPot.add(msg.value);
        allInvest.push(_investInfo);
        investOrders[_pId] = allInvest.length;
        curRound.ht = curRound.ht.add(msg.value);
        
        safeBoxs[_pId].addr = msg.sender;
        safeBoxs[_pId].total = safeBoxs[_pId].total.add(msg.value);
        safeBoxs[_pId].records[curRoundNumber] = safeBoxs[_pId].records[curRoundNumber].add(msg.value);
        
        // is over?
        bool _o = over();
        
        emit DLData.onBattle
        (
            curRoundNumber,
            _pId,
            msg.sender,
            players[_pId].name,
            luckBoxs[curRoundNumber].repel == msg.sender,
            luckBoxs[curRoundNumber].winner == msg.sender,
            _o,
            safeBoxs[_pId].records[curRoundNumber],
            msg.value
        );
        
    }
    
    function getPID(address _addr)
        private
        returns (uint)
    {
        require(_addr != address(0), "note: the account is the zero address");
        if (pIDxAddr[_addr] == 0){
            pID++;
            pIDxAddr[_addr] = pID;
            uint[] memory _badges;
            players[pID] = DLData.Player(_addr,"unknow",0,0,race,_badges);
            return pID;
        } else {
            return pIDxAddr[_addr];
        }
    }
    
    function registerName(string memory _nameString)
        isHuman()
        public
        payable
    {
       require (msg.value >= registrationFee, "umm.....  you have to pay the name fee");
       
       uint _pId = getPID(msg.sender);
       DLData.Player storage _player = players[_pId];
       require(_player.level > 0,"You need to have a badge");
       
       bytes32 _name = NameFilter.nameFilter(_nameString);
       _player.name = _name;
       
       emit DLData.onRegisterName
       (
           _pId,
           msg.sender,
           _name
        );
    }
    
    function getPlayerInfo()
        isHuman()
        public
        returns(playerInfo memory)
    {
         uint _pId = getPID(msg.sender);
         uint256 _collectable = 0;
         if(investOrders[_pId] > 0 
         && investOrders[_pId] <= allInvest.length 
         && allInvest[(investOrders[_pId]).sub(1)].pID == _pId
         && allInvest.length >= investOrders[_pId]){
            uint256 _deposit = allInvest[investOrders[_pId].sub(1)].invest;
            uint256 _diff = allInvest.length.sub(investOrders[_pId]);
            if(_diff < _deposit){
                _collectable = _deposit.sub(_diff);
            }
         }
         return playerInfo(players[_pId],safeBoxs[_pId].earned,safeBoxs[_pId].total,_collectable);
    }
    
    function getRoundInfo(uint256 _r)
        isHuman
        public
        view
        returns(RoundInfo memory)
    {
        require(_r <= curRoundNumber && 0 < _r,"Only get the previous round..");
        require(_r == curRoundNumber && !curRound.ended,"Please waiting next round...");
       
        return RoundInfo(pastRound[_r],deadDragon[_r].hp,deadDragon[_r].sleep,luckBoxs[_r]);
    }
    
    function endRound()
        private
    {
        curDragon.alive = false;
        curRound.started = false;
        curRound.ended = true;
        curRound.endT = block.timestamp;
        
        deadDragon[curRoundNumber] = curDragon;
        pastRound[curRoundNumber] = curRound;
        
        uint256 _35p = curRound.ht.mul(35).div(100);
        uint256 _10p = curRound.ht.mul(10).div(100);
        
        //reward repel 10%;
        uint256 _pIdxRepel = pIDxAddr[luckBoxs[curRoundNumber].repel];
        safeBoxs[_pIdxRepel].earned = safeBoxs[_pIdxRepel].earned.add(_10p);
        DLData.Player storage _playerxRepel = players[_pIdxRepel];
        _playerxRepel.badgs.push(2);
        
        //reward winner 35%;
        uint256 _pIdxWinner = pIDxAddr[luckBoxs[curRoundNumber].winner];
        safeBoxs[_pIdxWinner].earned = safeBoxs[_pIdxWinner].earned.add(_35p);
        DLData.Player storage _playerxWinner = players[_pIdxWinner];
        _playerxWinner.flag = 1;
        _playerxWinner.badgs.push(1);
        
        //reward dev 10%
        uint256 _pidDev = getPID(owner());
        safeBoxs[_pidDev].earned = safeBoxs[_pidDev].earned.add(_10p);

        dragonSlayers.push(players[_pIdxWinner]);
        delete allInvest;
        
    }
    
    function sleep()
        private
        returns(bool)
    {
        if(curDragon.hide){
            return true;
        }else{
            //sleep
            if(curDragon.hp <= curRound.ht){
                curDragon.endT = block.timestamp;
                curDragon.hide = true;
                
                //luck boy
                luckBoxs[curRoundNumber].repel = msg.sender;
                return curDragon.hide;
            }else{
                return curDragon.hide;
            }
        }
    }
    
    function over()
        private
        returns(bool)
    {
       if(curDragon.alive){
           if(sleep() 
           && curDragon.endT.add(curDragon.sleep) <= block.timestamp){
                //killed
                curDragon.alive = false;
                //luck boy
                luckBoxs[curRoundNumber].winner = msg.sender;
                endRound();
                return true;
           }
       }
       return false;
    }
    
    function distribute(uint256 _v)
        private
        isHuman()
    {
        uint i = allInvest.length;
        for(uint j = 0; j < 100; j++){
           if(i == 0){return;}
           else{i--;}
           if(!allInvest[i].isDelete){
                uint256 _c = _v.mul(allInvest[i].invest).div(curRound.collectPot);
                safeBoxs[allInvest[i].pID].earned = safeBoxs[allInvest[i].pID].earned.add(_c);
            }
        }
    }
    
    function deleteCollectPlayer()
        private
    {
        uint _len = allInvest.length;
        deleteInvest(_len,10);
        deleteInvest(_len,20);
        deleteInvest(_len,50);
        deleteInvest(_len,100);
    }
    
    function deleteInvest(uint _len,uint _level)
        private
    {
        if(_len >= (_level + 1)){
            if(allInvest[_len.sub(_level + 1)].invest == _level.mul(10 ** 18)){
                allInvest[_len.sub(_level + 1)].isDelete = true;
                curRound.collectPot = curRound.collectPot.sub(_level.mul(10 ** 18));
            }
        }
    }
    
    function randMod(uint _r) 
        private
        view
        returns(uint)
    {
        return uint(keccak256(abi.encodePacked(
            (block.timestamp).add 
            (block.gaslimit).add
            ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (block.timestamp)).add
            (block.difficulty)))) % _r + 1;
    }
    
    function pay(address payable _account, uint256 _m)
        private
    {

        require(_account != address(0), "note: the account is the zero address");
        require(_m > 0, "note : zero withdraw not allowed");
        _account.transfer(_m);

    }
    
}