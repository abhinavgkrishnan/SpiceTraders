// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Tokens.sol";

contract ResourceWrapper is ERC20, Ownable {
    Tokens public immutable tokensContract;
    uint256 public immutable resourceId;

    // 1:1 mapping between ERC1155 and ERC20
    mapping(address => uint256) private _deposits;

    event Wrapped(address indexed user, uint256 amount);
    event Unwrapped(address indexed user, uint256 amount);

    constructor(
        address _tokensContract,
        uint256 _resourceId,
        string memory _name,
        string memory _symbol,
        address initialOwner
    ) ERC20(_name, _symbol) Ownable(initialOwner) {
        tokensContract = Tokens(_tokensContract);
        resourceId = _resourceId;
    }

    /**
     * @dev Wrap ERC1155 tokens into ERC20 tokens
     * User must approve this contract to spend their ERC1155 tokens first
     */
    function wrap(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");

        // Transfer ERC1155 tokens from user to this contract
        tokensContract.safeTransferFrom(
            msg.sender,
            address(this),
            resourceId,
            amount,
            ""
        );

        // Mint equivalent ERC20 tokens to user
        _mint(msg.sender, amount);
        _deposits[msg.sender] += amount;

        emit Wrapped(msg.sender, amount);
    }

    /**
     * @dev Unwrap ERC20 tokens back to ERC1155 tokens
     */
    function unwrap(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient wrapped balance");

        // Burn ERC20 tokens
        _burn(msg.sender, amount);
        _deposits[msg.sender] -= amount;

        // Transfer ERC1155 tokens back to user
        tokensContract.safeTransferFrom(
            address(this),
            msg.sender,
            resourceId,
            amount,
            ""
        );

        emit Unwrapped(msg.sender, amount);
    }

    /**
     * @dev Get the amount of ERC1155 tokens deposited by a user
     */
    function depositsOf(address user) external view returns (uint256) {
        return _deposits[user];
    }

    /**
     * @dev Get total ERC1155 tokens held by this contract
     */
    function totalDeposits() external view returns (uint256) {
        return tokensContract.balanceOf(address(this), resourceId);
    }

    /**
     * @dev ERC1155 receiver function
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}