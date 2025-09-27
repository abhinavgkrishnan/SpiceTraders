// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Credits is ERC20, ERC20Burnable, ERC20Pausable, Ownable {
    mapping(address => bool) public authorizedMinters;

    uint256 public constant STARTER_AMOUNT = 1500 * 10**18; // 1500 Solaris for new players
    uint256 public constant MAX_SUPPLY = 2_000_000_000 * 10**18; // 2 billion Solaris max

    event AuthorizedMinterSet(address indexed minter, bool authorized);

    modifier onlyAuthorizedMinter() {
        require(authorizedMinters[msg.sender] || msg.sender == owner(), "Not authorized to mint");
        _;
    }

    constructor(address initialOwner)
        ERC20("Imperial Solaris", "SOLARIS")
        Ownable(initialOwner)
    {
        authorizedMinters[initialOwner] = true;
        _mint(initialOwner, 100_000_000 * 10**18); // Initial supply: 100M Solaris
    }

    function setAuthorizedMinter(address minter, bool authorized) external onlyOwner {
        authorizedMinters[minter] = authorized;
        emit AuthorizedMinterSet(minter, authorized);
    }

    function mint(address to, uint256 amount) external onlyAuthorizedMinter {
        require(totalSupply() + amount <= MAX_SUPPLY, "Would exceed max supply");
        _mint(to, amount);
    }

    function mintStarterAmount(address to) external onlyAuthorizedMinter {
        require(totalSupply() + STARTER_AMOUNT <= MAX_SUPPLY, "Would exceed max supply");
        _mint(to, STARTER_AMOUNT);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable)
    {
        super._update(from, to, value);
    }
}