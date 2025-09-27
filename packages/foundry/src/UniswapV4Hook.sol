// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseHook} from "v4-periphery/utils/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Mining.sol";
import "./Player.sol";

contract UniswapV4Hook is BaseHook {
    address public owner;
    Mining public miningContract;
    Player public playerContract;

    // Map pool keys to planet IDs for location validation
    mapping(bytes32 => uint256) public poolToPlanet;

    constructor(IPoolManager _poolManager, address _miningContract, address _playerContract) BaseHook(_poolManager) {
        owner = msg.sender;
        miningContract = Mining(_miningContract);
        playerContract = Player(_playerContract);
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // Set which planet a pool belongs to for location validation
    function setPoolPlanet(PoolKey memory key, uint256 planetId) external {
        require(msg.sender == owner, "Not owner");
        bytes32 poolHash = keccak256(abi.encode(key));
        poolToPlanet[poolHash] = planetId;
    }

    function _beforeSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata,
        bytes calldata
    ) internal view override returns (bytes4, BeforeSwapDelta, uint24) {
        // Check if this pool requires location validation
        bytes32 poolHash = keccak256(abi.encode(key));
        uint256 requiredPlanet = poolToPlanet[poolHash];

        if (requiredPlanet > 0) {
            // Validate player is on the correct planet
            uint256 playerLocation = playerContract.getPlayerLocation(sender);
            require(playerLocation == requiredPlanet, "Player not on required planet for this market");
        }

        // Hook validation passed - allow the swap
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }
}