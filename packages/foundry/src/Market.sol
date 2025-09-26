// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import "./Player.sol";
import "./Tokens.sol";

contract Market is Ownable, ReentrancyGuard {
    using PoolIdLibrary for PoolKey;

    Player public playerContract;
    Tokens public tokensContract;
    IPoolManager public poolManager;

    struct Trade {
        address trader;
        uint256 fromTokenId;
        uint256 toTokenId;
        uint256 fromAmount;
        uint256 toAmount;
        uint256 timestamp;
    }

    // Planet-specific markets (Uniswap V4 pools)
    mapping(uint256 => PoolId) public planetMarkets;

    // Store pool configurations for each planet
    mapping(uint256 => PoolKey) public planetPoolKeys;

    event MarketSet(uint256 indexed planetId, PoolId indexed poolId);
    event TradeExecuted(
        address indexed trader,
        uint256 indexed planetId,
        uint256 fromTokenId,
        uint256 toTokenId,
        uint256 fromAmount,
        uint256 toAmount
    );

    modifier atPlanetMarket() {
        uint256 planetId = playerContract.getPlayerLocation(msg.sender);
        require(planetId > 0, "You are not at any planet");
        require(PoolId.unwrap(planetMarkets[planetId]) != bytes32(0), "No market at this planet");
        _;
    }

    constructor(address initialOwner, address _playerContract, address _tokensContract, address _poolManager)
        Ownable(initialOwner)
    {
        playerContract = Player(_playerContract);
        tokensContract = Tokens(_tokensContract);
        poolManager = IPoolManager(_poolManager);
    }

    function setPlanetMarket(uint256 planetId, PoolId poolId) external onlyOwner {
        require(planetId > 0, "Invalid planet ID");
        planetMarkets[planetId] = poolId;
        emit MarketSet(planetId, poolId);
    }

    function createAndInitializePlanetPool(
        uint256 planetId,
        Currency currency0,
        Currency currency1,
        uint24 fee,
        int24 tickSpacing,
        address hookContract,
        uint160 sqrtPriceX96
    ) external onlyOwner returns (PoolKey memory key) {
        require(planetId > 0, "Invalid planet ID");

        // Ensure currencies are sorted
        require(Currency.unwrap(currency0) < Currency.unwrap(currency1), "Currencies not sorted");

        // Create the pool key
        key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(hookContract)
        });

        // Initialize the pool
        poolManager.initialize(key, sqrtPriceX96);

        // Store the pool configuration
        planetPoolKeys[planetId] = key;

        // Calculate and store the pool ID
        PoolId poolId = key.toId();
        planetMarkets[planetId] = poolId;

        emit MarketSet(planetId, poolId);

        return key;
    }

    function getPoolKeyForPlanet(uint256 planetId) public view returns (PoolKey memory) {
        require(planetId > 0, "Invalid planet ID");
        PoolKey memory key = planetPoolKeys[planetId];
        require(Currency.unwrap(key.currency0) != address(0), "Pool not configured for planet");
        return key;
    }

    function executeTrade(
        uint256 fromTokenId,
        uint256 toTokenId,
        uint256 fromAmount,
        uint256 slippageTolerance, // e.g., 50 for 0.5%
        bytes calldata hookData
    ) external nonReentrant atPlanetMarket returns (BalanceDelta delta) {
        uint256 planetId = playerContract.getPlayerLocation(msg.sender);

        // Get the pool key for this planet's market
        PoolKey memory key = getPoolKeyForPlanet(planetId);

        // Approve the PoolManager to spend the trader's tokens
        tokensContract.safeTransferFrom(msg.sender, address(poolManager), fromTokenId, fromAmount, "");

        // Execute the swap
        delta = poolManager.swap(
            key,
            SwapParams({
                zeroForOne: fromTokenId < toTokenId,
                amountSpecified: int256(fromAmount),
                sqrtPriceLimitX96: 0 // No price limit
            }),
            hookData
        );

        // Validate slippage protection
        _validateSlippage(delta, fromAmount, slippageTolerance);

        emit TradeExecuted(msg.sender, planetId, fromTokenId, toTokenId, fromAmount, uint256(uint128(-delta.amount1())));

        playerContract.updateLastActionTimestamp(msg.sender);

        return delta;
    }

    function _validateSlippage(
        BalanceDelta delta,
        uint256 fromAmount,
        uint256 slippageTolerance
    ) internal pure {
        int128 amountOut = delta.amount1();
        uint256 expectedAmountOut = (fromAmount * 995) / 1000; // Example placeholder logic
        uint256 minAmountOut = (expectedAmountOut * (10000 - slippageTolerance)) / 10000;
        require(uint256(uint128(-amountOut)) >= minAmountOut, "Slippage tolerance exceeded");
    }
}