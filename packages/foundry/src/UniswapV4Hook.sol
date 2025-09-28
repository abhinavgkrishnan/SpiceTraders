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

// Interface for Market contract planet requirements
interface IMarketRegistry {
    function getPoolPlanetRequirement(PoolKey calldata key) external view returns (uint256);
}

contract UniswapV4Hook is BaseHook {
    address public owner;
    Mining public miningContract;
    Player public playerContract;
    IMarketRegistry public marketRegistry;

    constructor(IPoolManager _poolManager, address _miningContract, address _playerContract, address _marketRegistry) BaseHook(_poolManager) {
        owner = msg.sender;
        miningContract = Mining(_miningContract);
        playerContract = Player(_playerContract);
        marketRegistry = IMarketRegistry(_marketRegistry);
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

    function _beforeSwap(
        address /* sender */,
        PoolKey calldata key,
        SwapParams calldata,
        bytes calldata hookData
    ) internal view override returns (bytes4, BeforeSwapDelta, uint24) {
        // Query the market registry for planet requirements
        uint256 requiredPlanet = marketRegistry.getPoolPlanetRequirement(key);

        if (requiredPlanet > 0 && hookData.length >= 32) {
            // Decode the actual user address from hookData (passed by Market contract)
            address actualUser = abi.decode(hookData, (address));

            // Skip validation for address(0) - used by quoters
            if (actualUser != address(0)) {
                // Validate player is registered and on the correct planet
                require(playerContract.isPlayerRegistered(actualUser), "Player not registered");
                uint256 playerLocation = playerContract.getPlayerLocation(actualUser);
                require(playerLocation == requiredPlanet, "Player not on required planet for this market");
            }
        }

        // Hook validation passed - allow the swap
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }
}