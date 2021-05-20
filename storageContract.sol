// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
import "./storagePool.sol";
import "./storageToken.sol";

contract StorageContract is StorageToken {
    address public generatorAddress;
    uint256 public createdTime;
    
    mapping (uint => address) public poolToOwner;
    mapping (address => uint) public usdtBalances;
    
    StoragePool[] public storagePools;
    
    event SentGb(address from, address to, uint amount);
    event SentUsdt(address from, address to, uint amount);
    
    
    constructor() StorageToken(msg.sender){
        createdTime = block.timestamp;
        uint nonce = 1;
        generatorAddress = address(uint160(uint(keccak256(abi.encodePacked(nonce, blockhash(block.number))))));
    }
    
    function depositUsdt(uint amount) public {
        usdtBalances[msg.sender] += amount;
    }

    
    function sendGb(address receiver, uint amount) public {
        require(amount <= balanceOf(msg.sender), "Insufficient Gigabytes balance.");
        transfer(receiver, amount);
        emit Transfer(msg.sender, receiver, amount);
    }
    
    function sendUsdt(address receiver, uint amount) public {
        require(amount <= usdtBalances[msg.sender], "Insufficient Usdt balance.");
        usdtBalances[msg.sender] -= amount;
        usdtBalances[receiver] += amount;
        emit SentUsdt(msg.sender, receiver, amount);
    }
    function sendUsdtFrom(address sender, address receiver, uint amount) public {
        require(amount <= usdtBalances[sender], "Insufficient Usdt balance.");
        usdtBalances[sender] -= amount;
        usdtBalances[receiver] += amount;
        emit SentUsdt(sender, receiver, amount);
    }
    

    function generateStorageContract(uint gbCoinAmount, uint expirationTimeInDays) public returns (StoragePool){
        expirationTimeInDays = expirationTimeInDays * 1 days;
        require(gbCoinAmount <= balanceOf(msg.sender), "Insufficient Gigabytes available");
        require(gbCoinAmount > 0, "Positive number of Gigabytes required");
        require(expirationTimeInDays + createdTime > block.timestamp, "Time must be in the future");
        StoragePool lendContract = new StoragePool(gbCoinAmount, expirationTimeInDays);
        storagePools.push(lendContract);
        transfer(lendContract._getPoolAddress(), gbCoinAmount);
        emit Transfer(msg.sender, lendContract._getPoolAddress(), gbCoinAmount);
        uint id = storagePools.length - 1;
        poolToOwner[id] = msg.sender;
        return lendContract;
    }
    
    function borrowStorageFromPool(uint poolId, uint amount, uint loanTime) public {
        loanTime = loanTime * 1 days;
        require(isPoolAvailable(poolId), "Storage Pool unavailable");
        require(storagePools[poolId].owner() != msg.sender, "U can't borrow from your own Loan.");
        require(storagePools[poolId]._getAvailableGb() >= amount, "Insufficient Gigabytes available in Storage Pool");
        require(storagePools[poolId]._loanTimeAvailable(loanTime), "There is not enought time available for your loan");
        storagePools[poolId]._createStorageLoan(amount, loanTime);
        transfer(storagePools[poolId]._getPoolAddress(), amount);
        sendUsdt(storagePools[poolId]._getPoolAddress(), amount * storagePools[poolId]._getFee());
        emit Transfer(msg.sender, storagePools[poolId]._getPoolAddress(), amount);
        emit SentUsdt(msg.sender, storagePools[poolId]._getPoolAddress(), amount * storagePools[poolId]._getFee());
    }
    
    function isPoolAvailable(uint poolId) public view returns (bool){
        require(poolId < storagePools.length, "Invalid id.");
        return !storagePools[poolId]._PoolExpired();
    }
    
    function payFeeFromPool(uint poolId) public {
        if (storagePools[poolId]._PoolExpired()) {
            for (uint i = 0; i < storagePools[poolId]._getStorageLoansSize(); i++) {
                sendUsdtFrom(storagePools[poolId]._getPoolAddress(), storagePools[poolId].owner(), storagePools[poolId]._getStorageLoan(i).lockedFee);
                emit SentUsdt(storagePools[poolId]._getPoolAddress(), storagePools[poolId].owner(), storagePools[poolId]._getStorageLoan(i).lockedFee);
            }
        }
    }
    
    function addGbToStoragePool(uint poolId, uint amount) public {
        require(balanceOf(msg.sender) >= amount, "Insufficient Gigabytes available");
        require(storagePools[poolId].isOwner(), "Only the owner of the Storage Pool can extend the storage space.");
        transfer(storagePools[poolId]._getPoolAddress(), amount);
        storagePools[poolId]._expandStorage(amount);
        emit Transfer(msg.sender, storagePools[poolId]._getPoolAddress(), amount);
    }
    
    function addGbToStorageLoan(uint poolId, uint amount) public {
        require(isPoolAvailable(poolId), "Storage pool unavailable");
        require(balanceOf(msg.sender) >= amount, "Insufficient Gigabytes available");
        require(usdtBalances[msg.sender] >= amount * storagePools[poolId]._getFee(), "Insufficient usdt available");
        storagePools[poolId]._increaseLoan(amount);
        sendUsdt(storagePools[poolId]._getPoolAddress(), amount * storagePools[poolId]._getFee());
        emit SentUsdt(msg.sender, storagePools[poolId]._getPoolAddress(), amount * storagePools[poolId]._getFee());
    }
    function extendStorageLoanTime(uint poolId, uint time) public view {
        time = time * 1 days;
        require(isPoolAvailable(poolId), "Storage pool unavailable");
        storagePools[poolId]._extendLoan(time);
    }
}