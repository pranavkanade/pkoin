# Notes

## Minting tokens

* This means the we need to add/remove some amount of tokens from or to the total pool of the Coins/Tokens.
* This can be done by making the transaction to the owner account itself. This transaction will just be represented by event call and not the actual functional call.
* These newly added tokens will be transfered to some other user from the owner of the token contract.

```solidity
    function mintToken(address target, uint256 mintedAmount) onlyOwner {
        balanceOf[target] += mintedAmount;
        totalSupply += mintedAmount;
        Transfer(0, owner, mintedAmount);
        Transfer(owner, target, mintedAmount);
    }
```

* As there is modifier `onlyOwner` is associated with this function means that only owner of the contract token will be able to invoke this function.

## Freezing of Assets

* Can be done as follows : 

```solidity
    mapping (address => bool) public frozenAccount;
    event FrozenFunds(address target, bool frozen);

    function freezeAccount(address target, bool freeze) onlyOwner {
        frozenAccount[target] = freeze;
        FrozenFunds(target, freeze);
    }
```

* In addition to above code we need to make change in the transfer function itself as adding only above piece of code has no practicle effect on things.

```solidity
    function transfer(address _to, uint256 _value) {
        require(!frozenAccount[msg.sender]);
```

## Automatic selling and buying

[ethereum.org/token]