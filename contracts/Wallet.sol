// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";

contract Wallet is Ownable {

    struct Token {
        bytes32 ticker;
        address tokenAddress;
    }

    mapping(bytes32 => Token) public tokenMapping; // mapping pointing from token ticker to the actual Token struct object
    bytes32[] public tokenList; // list of all the tickers

    mapping(address => mapping(bytes32 => uint256)) public balances; // mapping pointing from address to the balance of different tokens via ticker
    // we could use string instead of bytes32 type but we can't compare strings in Solidity and do other operations that we can do with bytes32 type

    // we need to check that the token Address of the token ticker to be withdrawn acutally exists.
    // we have to make sure that token address is not a "zero" address (0x0000...). This can happen if ticker is pointing to the uninitialized (0x0000...) address in Token struct.
    modifier tokenExist(bytes32 ticker){
        require(tokenMapping[ticker].tokenAddress != address(0), "Token does not exist"); 
        _;                      
                             
    } 

    function addToken(bytes32 ticker, address tokenAddress) onlyOwner external {
        tokenMapping[ticker] = Token(ticker, tokenAddress); // adds a new Token struct to the tokenMapping
        tokenList.push(ticker);                             // adds a new Token ticker to the tokenList of all tickers
    }

    // in order to interact with the contract we need to know what the contract interface looks like and where that contract is i.e. contract's address
    // in this case we will be interacting with ERC20 contract through openZeppelin
    function deposit(uint amount, bytes32 ticker) tokenExist(ticker) external {
        IERC20(tokenMapping[ticker].tokenAddress).transferFrom(msg.sender, address(this), amount); // we ask ERC20 contract to transfer from msg.sender to us (i.e. this Wallet contract)
        balances[msg.sender][ticker] += amount;
    }

    function depositEth() payable external {
        balances[msg.sender][bytes32("ETH")] += msg.value;
    }
    
    //(this is external function and msg.sender is the actual owner and caller of the withdraw function). This contract is just holding tokens for the owner 
    function withdraw(uint amount, bytes32 ticker) tokenExist(ticker) external {
        require(balances[msg.sender][ticker] >= amount, "Balance not sufficient");  // we need to check that msg.sender has enough balance for withdrawal
        balances[msg.sender][ticker] -= amount;                                     // we need to adjust the balance before the transfer
        IERC20(tokenMapping[ticker].tokenAddress).transfer(msg.sender, amount);     // transfer from this (Wallet) contract to the msg.sender
        
    }

    function withdrawEth(uint amount) external {
        require(balances[msg.sender][bytes32("ETH")] >= amount,'Insufficient balance'); 
        balances[msg.sender][bytes32("ETH")] -= amount;
        msg.sender.call{value:amount};
    }

}