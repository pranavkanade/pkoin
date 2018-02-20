pragma solidity ^0.4.0;

contract PKoin {
    // This creates an array with all balances
    mapping (address => uint256) public balanceOf;

    // Initializes the contract with initial supply of tokens to 
    // to the creator of the contract
    function PKoin(uint256 initialSupply) internal {
        balanceOf[msg.sender] = initialSupply;
    }

    // Send coins
    function transfer(address _to, uint256 _value) public {
        require(balanceOf[msg.sender] >= _value);
        require(balanceOf[_to] + _value >= balanceOf[_to]);
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
    }
}