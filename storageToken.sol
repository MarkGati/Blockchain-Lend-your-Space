// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

contract StorageToken {

    string public constant name = "GigaByte";
    string public constant symbol = "GB";
    uint8 public constant decimals = 3;
    address public minter;


    event Approval(address indexed _owner, address indexed _spender, uint256 _tokens);
    event Transfer(address indexed _from, address indexed _to, uint256 _tokens);


    mapping(address => uint256) _availableStorage;

    mapping(address => mapping(address => uint256)) _allowed;

    uint256 _totalSupply = 0;

    
    constructor(address _minter) {
        minter = _minter;
    }
    
    function mintGbToken(uint amount) public {
        require(msg.sender == minter, "Only the minter can mint more tokens.");
        _availableStorage[minter] += amount;
        _totalSupply += amount;
    }
    
    function totalSupply() public view returns(uint256) {
        return _totalSupply;
    }

    function balanceOf(address owner) public view returns(uint) {
        return _availableStorage[owner];
    }

    function transfer(address receiver, uint numOfTokens) internal returns(bool) {
        require(numOfTokens <= _availableStorage[msg.sender]);
        _availableStorage[msg.sender] = _availableStorage[msg.sender] - numOfTokens;
        _availableStorage[receiver] = _availableStorage[receiver] + numOfTokens;
        emit Transfer(msg.sender, receiver, numOfTokens);
        return true;
    }

    function approve(address delegate, uint numOfTokens) internal returns(bool) {
        _allowed[msg.sender][delegate] = numOfTokens;
        emit Approval(msg.sender, delegate, numOfTokens);
        return true;
    }

    function allowance(address owner, address delegate) internal view returns(uint) {
        return _allowed[owner][delegate];
    }

    function transferFrom(address owner, address borower, uint numOfTokens) internal returns(bool) {
        require(numOfTokens <= _availableStorage[owner]);
        require(numOfTokens <= _allowed[owner][msg.sender]);

        _availableStorage[owner] = _availableStorage[owner] - numOfTokens;
        _allowed[owner][msg.sender] = _allowed[owner][msg.sender] - numOfTokens;
        _availableStorage[borower] = _availableStorage[borower] + numOfTokens;
        emit Transfer(owner, borower, numOfTokens);
        return true;
    }
}