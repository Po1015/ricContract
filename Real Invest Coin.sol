// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RealInvestCoin is ERC20, Ownable(msg.sender) {
    uint256 private constant INITIAL_SUPPLY = 5000000 * 10**18; // 50 million tokens with 18 decimals
    bool tradable = false;
    address presale;

    constructor() ERC20("RealInvest Coin", "RIC") {
        _mint(msg.sender, INITIAL_SUPPLY); // Mint initial supply to the deployer
    }

    // Function to mint new tokens, restricted to the owner
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function transfer(address to, uint256 amount) public override returns (bool){
        require(tradable || to == owner() || msg.sender == owner() || to == presale || msg.sender == presale, "Trading not allowed");
        _transfer(msg.sender, to, amount);
        return true;
    }

    function setTradingEnable() public onlyOwner {
        require(!tradable, "Already trading enabled!");
        tradable = true;
    }
    
    function setPresale(address _presale) public onlyOwner {
        require(_presale != address(0), "Presale address should be set non zero address");
        presale = _presale;
    }
}