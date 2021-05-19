pragma solidity >=0.7.0 <0.9.0;
import "./storagePool.sol";

contract StorageContract {
    address public generatorAddress;
    address public minter;
    uint public gbCoinCirculationSupply;
    uint public createdTime;
    
    mapping (uint => address) public poolToOwner;
    mapping (address => uint) public gbBalances;
    mapping (address => uint) public usdtBalances;
    
    StoragePool[] public storagePools;
    
    event SentGb(address from, address to, uint amount);
    event SentUsdt(address from, address to, uint amount);
    
    
    modifier onlyMinter {
        require(msg.sender == minter);
        _;
    }
    modifier amountGreaterThan(uint amount) {
        require(amount < 1e60);
        _;
    }
    
    constructor() {
        minter = msg.sender;
        createdTime = block.timestamp;
        gbCoinCirculationSupply = 0;
        uint nonce = 1;
        generatorAddress = address(uint160(uint(keccak256(abi.encodePacked(nonce, blockhash(block.number))))));
    }
    
    function mintGb(address receiver, uint amount) public amountGreaterThan(amount) {
        require(msg.sender == minter);
        require(amount < 1e60);
        gbBalances[receiver] += amount;
        gbCoinCirculationSupply += amount;
    }
    
    function sendGb(address receiver, uint amount) public {
        require(amount <= gbBalances[msg.sender], "Insufficient Gigabytes balance.");
        gbBalances[msg.sender] -= amount;
        gbBalances[receiver] += amount;
        emit SentGb(msg.sender, receiver, amount);
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
    

    function generateStorageContract(uint gbCoinAmount, uint contractExpirationTime) public returns (StoragePool){
        require(gbCoinAmount <= gbBalances[msg.sender], "Insufficient Gigabytes available");
        require(gbCoinAmount > 0, "Positive number of Gigabytes required");
        require(contractExpirationTime>block.timestamp, "Time must be in the future");
        StoragePool lendContract = new StoragePool(gbCoinAmount, contractExpirationTime);
        storagePools.push(lendContract);
        uint id = storagePools.length - 1;
        poolToOwner[id] = msg.sender;
        return lendContract;
    }
    
    function borrowStorageFromPool(uint poolId, uint amount, uint loanTime) public {
        require(isPoolAvailable(poolId), "Storage Pool unavailable");
        require(storagePools[poolId]._getAvailableGb() >= amount, "Insufficient Gigabytes available in Storage Pool");
        require(storagePools[poolId]._loanTimeAvailable(loanTime), "There is not enought time available for your loan");
        storagePools[poolId]._createStorageLoan(amount, loanTime);
        sendGb(storagePools[poolId]._getPoolAddress(), amount);
        sendUsdt(storagePools[poolId]._getPoolAddress(), amount * storagePools[poolId]._getFee());
        emit SentGb(msg.sender, storagePools[poolId]._getPoolAddress(), amount);
        emit SentUsdt(msg.sender, storagePools[poolId]._getPoolAddress(), amount * storagePools[poolId]._getFee());
    }
    
    function isPoolAvailable(uint poolId) public view returns (bool){
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
        require(gbBalances[msg.sender] >= amount, "Insufficient Gigabytes available");
        require(storagePools[poolId].owner() == msg.sender, "Only the owner of the Storage Pool can extend the storage space.");
        storagePools[poolId]._expandStorage(amount);
    }
    
    function addGbToStorageLoan(uint poolId, uint amount) public {
        require(isPoolAvailable(poolId), "Storage pool unavailable");
        require(gbBalances[msg.sender] >= amount, "Insufficient Gigabytes available");
        require(usdtBalances[msg.sender] >= amount * storagePools[poolId]._getFee(), "Insufficient usdt available");
        storagePools[poolId]._increaseLoan(amount);
        sendUsdt(storagePools[poolId]._getPoolAddress(), amount * storagePools[poolId]._getFee());
        emit SentUsdt(msg.sender, storagePools[poolId]._getPoolAddress(), amount * storagePools[poolId]._getFee());
    }
    function extendStorageLoanTime(uint poolId, uint time) public view {
        require(isPoolAvailable(poolId), "Storage pool unavailable");
        storagePools[poolId]._extendLoan(time);
    }
}