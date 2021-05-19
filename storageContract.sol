pragma solidity >=0.7.0 <0.9.0;
import "./ownable.sol";



contract StoragePool is Ownable{
    address poolAddress;
    uint lockedGb;
    uint expirationDate; // given in days for example '= 30 days'
    uint lockedUsdt;
    uint availableGb;
    uint fee;
    uint createdPoolDate;
    uint nonce = 1;
    event newStorageLoan(uint loanId, address owner, uint lockedFee, uint borrowedGb, uint expirationDate);
    
    event Sent(address from, address to, uint amount);
    
    struct StorageLoan {
        address owner;
        uint lockedFee;
        uint borrowedGb;
        uint expirationDate;
        uint createdLoanDate;
        
       
    }
    
    StorageLoan[] public storageLoans;
    
    mapping (uint => address) loanToOwner;
    mapping (address => uint) ownerLoanCount;
    
    constructor(uint _lockedGb, uint _expirationDate) public {
        poolAddress = address(uint160(uint(keccak256(abi.encodePacked(nonce, blockhash(block.number))))));
        nonce += 1;
        lockedGb = _lockedGb;
        expirationDate = _expirationDate;
        lockedUsdt = 0;
        availableGb = _lockedGb;
        fee = 1; // fee for 1 GB in Usdt;
        createdPoolDate = block.timestamp; //current time in seconds
    }
    function _getPoolAddress() public view returns(address) {
        return poolAddress;
    }
    
    
    function _getAvailableGb() public view returns(uint) {
        return availableGb;
    }
    
    function _getFee() public view returns(uint) {
        return fee;
    }
    
    function _getExpirationDate() public view returns(uint) {
        return expirationDate;
    }
    function _getStorageLoansSize() public view returns(uint) {
        return storageLoans.length;
    }
    function _getStorageLoan(uint _id) public view returns(StorageLoan memory){
        return storageLoans[_id];
    }
    function _getStorageLoan(address _owner) public view returns(StorageLoan memory){
        require(ownerLoanCount[_owner] >= 1, "Owner has no loans.");
        for (uint i = 0; i < storageLoans.length; i++) {
            if(storageLoans[i].owner == _owner){
                return storageLoans[i];
            }
        }
    }
    
    function _setExpirationDate(uint _expirationDate) public onlyOwner{
        expirationDate = _expirationDate;
    }
    function _expandStorage(uint _newGb) public onlyOwner{
        require(msg.sender == owner());
        lockedGb = lockedGb + _newGb;
        availableGb = availableGb + _newGb;
    }
    function _decreaseAvailableGb(uint Gb) internal {
        availableGb = availableGb - Gb;
    }
    
    
    function _createStorageLoan(uint _borrowedGb, uint _expirationDate) external {
        require(!_PoolExpired(), "Storage Pool has expired.");
        require(_borrowedGb <= availableGb, "Insufficient Storage Available");
        uint _lockedFee = _borrowedGb * fee;
        storageLoans.push(StorageLoan(msg.sender, _lockedFee, _borrowedGb, _expirationDate, block.timestamp));
        uint id = storageLoans.length - 1; //unchecked
        loanToOwner[id] = msg.sender;
        ownerLoanCount[msg.sender] = ownerLoanCount[msg.sender] + 1; //unchecked
        _decreaseAvailableGb(_borrowedGb);
        emit newStorageLoan(id, msg.sender, _lockedFee, _borrowedGb, _expirationDate);
    }
    
    function _PoolExpired() public view returns(bool) { 
        return (block.timestamp >= (createdPoolDate + expirationDate));
    }
    
    function _loanTimeAvailable(uint time) public view returns(bool) {
        return (time <= (block.timestamp + expirationDate));
    }
     
    function _LoanExpired(uint loanId) public view returns(bool){
        return (block.timestamp >= (storageLoans[loanId].createdLoanDate + storageLoans[loanId].expirationDate));
    }
    
    function _increaseLoan(uint _borrowedGb) view external {
        require(msg.sender == _getStorageLoan(msg.sender).owner, "Only the owner can increase his loan");
        require(lockedGb >= availableGb + _borrowedGb);
        _getStorageLoan(msg.sender).borrowedGb += _borrowedGb;
        _getStorageLoan(msg.sender).lockedFee += _borrowedGb * fee;
    }
    
    function _extendLoan(uint _time) public view {
        require(msg.sender == _getStorageLoan(msg.sender).owner, "Only the owner can extend his loan");
        require(_loanTimeAvailable(_time), "The Storage Pool will expire soon");
        _getStorageLoan(msg.sender).expirationDate += _time;

    }
}