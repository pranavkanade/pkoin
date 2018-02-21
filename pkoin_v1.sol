pragma solidity ^0.4.16;

interface tokenRecipient {
    function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) public;
}

contract TokenERC20 {
    // public variable of token 
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    // 18 decimas is the strongly suggested default, avoid changing it
    uint256 public totalSupply;

    // This creates an array with all balance
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    // This generates a public event on the blockchain that will notify clients
    // This is to notify anyone who is listening to find out if the transfer took place.
    // Events are special, empty function that you call to help clients like Ethereum Wallet keep 
    // track of activities happening in the contract. Events should start with a capital letter.
    // Add this line to begining of the contract to declate the event;
    // Inside the transfer function this function will be called as follows :
    // Transfer(msg.sender, _to, _value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    // This notifies clients about the amount burnt
    event Burn(address indexed from, uint256 value);

    // Constructor Function
    // Initializes contract with initial supply tokens to the creator of the contract

    function TokenERC20(
        uint256 initialSupply,
        string tokenName,
        string tokenSymbol
    ) public
    {
        totalSupply = initialSupply * 10 ** uint256(decimals);  // Update total supply with the decimal amount in wei format
        balanceOf[msg.sender] = totalSupply;                    // Give the creator all the initial tokens
        name = tokenName;                                       // Set the name for display purposes
        symbol = tokenSymbol;                                   // Set the symbol for display purposes
    }

    // Internal transfer, only can be called by this contract
    function _transfer(address _from, address _to, uint _value) internal {
        require(_to != 0x0);    // Prevent transfer to 0x0 address. use burnt() instead 
        require(balanceOf[_from] >= _value);    // Check if the sender has enough
        require(balanceOf[_to] + _value > balanceOf[_to]);      // Check the overflows
        uint previousBalances = balanceOf[_from] + balanceOf[_to];     // Save this for assertiong in the future

        // Substract the value to be sent from _from
        balanceOf[_from] -= _value;

        // Add the same to the recipient
        balanceOf[_to] += _value;

        Transfer(_from, _to, _value);
        // asserts are used to use static analysis to find bugs in your code. They should never fail
        assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
    }

    // Transfer Tokens
    // @param _to : The address of the recipient
    // @param _value : The amount to send
    function transfer(address _to, uint256 _value) public {
        _transfer(msg.sender, _to, _value);     // call the internal function that will be geric for every use
    }


    // Transfer tokens from other address
    // Desc : Send `_value` tokens to `_to` on behalf of `_from`
    // @param _from : The address of the sender
    // @param _to : The address of the recipient
    // @param _value : The amount to send
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_value <= allowance[_from][msg.sender]);        // Check allowance
        allowance[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        return true;
    }


    // Set allowance for other address
    // Allows `_sender` to spend no more than `_value` tokens on your behalf
    // @param _spender : The address authorized to spend
    // @param _value : The max amount they can spend
    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        return true;
    }

    // Set allowances for other address and notify
    // Allows `_spender` to spend no more than `_value` tokens on your behalf,
    // and then ping the contract about it
    // @param _spender : The address authorized to spend 
    // @param _value : The max amount they can spend
    // @param _extraData : some extra information to send to the approved contract
    function approveAndCall(address _spender, uint256 _value, bytes _extraData)
    public
    returns (bool success) {
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, this, _extraData);
            return true;
        }
    }


    // Destroy tokens
    // Remove `_value` tokens from the system irreversibly
    // @param _value : the amount of money to burn
    function burn(uint256 _value)
    public
    returns (bool success) {
        require(balanceOf[msg.sender] >= _value);       // check if the sender has enough
        balanceOf[msg.sender] -= _value;
        totalSupply -= _value;
        Burn(msg.sender, _value);
        return true;
    }

    // Destroy token from other account
    // Remove `_value` tokens from the system irreversibly on behalf of `_from`.
    // @param _from : The address of the sender
    // @param _value : The amount of money to burn
    function burnFrom(address _from, uint256 _value)
    public
    returns (bool success) {
        require(balanceOf[_from] >= _value);
        require(_value <= allowance[_from][msg.sender]);    // sender is operating on behalf of the `_from` user
        balanceOf[_from] -= _value;
        allowance[_from][msg.sender] -= _value;
        totalSupply -= _value;
        Burn(_from, _value);
        return true;
    }
}