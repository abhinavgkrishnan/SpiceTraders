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
import {SafeCallback} from "v4-periphery/base/SafeCallback.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Player.sol";
import "./Tokens.sol";

contract Market is Ownable, ReentrancyGuard, SafeCallback {
    using PoolIdLibrary for PoolKey;

    Player public playerContract;
    Tokens public tokensContract;

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
        SafeCallback(IPoolManager(_poolManager))
    {
        playerContract = Player(_playerContract);
        tokensContract = Tokens(_tokensContract);
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
        address fromToken, // ERC20 wrapped token address
        address toToken,   // ERC20 wrapped token address
        uint256 fromAmount,
        uint256 slippageTolerance, // e.g., 50 for 0.5%
        bytes calldata hookData
    ) external nonReentrant atPlanetMarket returns (BalanceDelta delta) {
        uint256 planetId = playerContract.getPlayerLocation(msg.sender);

        // Get the pool key for this planet's market
        PoolKey memory key = getPoolKeyForPlanet(planetId);

        // Verify the tokens match the pool currencies
        require(
            (fromToken == Currency.unwrap(key.currency0) && toToken == Currency.unwrap(key.currency1)) ||
            (fromToken == Currency.unwrap(key.currency1) && toToken == Currency.unwrap(key.currency0)),
            "Tokens don't match pool currencies"
        );

        // Determine swap direction
        bool zeroForOne = fromToken == Currency.unwrap(key.currency0);

        // Transfer tokens from user to this contract for the swap
        IERC20(fromToken).transferFrom(msg.sender, address(this), fromAmount);

        // Approve PoolManager to spend our tokens
        IERC20(fromToken).approve(address(poolManager), fromAmount);

        // Execute the swap via unlock callback
        bytes memory swapHookData = abi.encode(msg.sender); // Pass real user address to hook
        bytes memory unlockData = abi.encode(
            "swap",
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: int256(fromAmount),
                sqrtPriceLimitX96: 0 // No price limit
            }),
            swapHookData,
            msg.sender,
            toToken
        );

        delta = BalanceDelta.wrap(abi.decode(poolManager.unlock(unlockData), (int256)));

        // Validate slippage protection
        _validateSlippage(delta, fromAmount, slippageTolerance);

        emit TradeExecuted(msg.sender, planetId, 0, 1, fromAmount, uint256(uint128(-delta.amount1())));

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

    // Add initial liquidity to planet pools (admin only)
    function addInitialLiquidity(
        uint256 planetId,
        int24 tickLower,
        int24 tickUpper,
        uint256 liquidity
    ) external onlyOwner nonReentrant {
        require(planetId > 0, "Invalid planet ID");
        PoolKey memory key = getPoolKeyForPlanet(planetId);

        bytes memory unlockData = abi.encode(
            "addLiquidity",
            key,
            ModifyLiquidityParams({
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: int256(liquidity),
                salt: bytes32(0)
            })
        );

        poolManager.unlock(unlockData);
    }

    // Get planet requirement for a specific pool (used by hook)
    function getPoolPlanetRequirement(PoolKey calldata key) external view returns (uint256) {
        PoolId poolId = key.toId();

        // Find which planet this pool belongs to
        for (uint256 planetId = 1; planetId <= 5; planetId++) {
            if (PoolId.unwrap(planetMarkets[planetId]) == PoolId.unwrap(poolId)) {
                return planetId;
            }
        }
        return 0; // No planet requirement
    }

    // Implement the unlock callback for Uniswap V4
    function _unlockCallback(bytes calldata data) internal override returns (bytes memory) {
        (string memory operation) = abi.decode(data, (string));

        if (keccak256(abi.encodePacked(operation)) == keccak256(abi.encodePacked("addLiquidity"))) {
            (,PoolKey memory key, ModifyLiquidityParams memory params) = abi.decode(
                data,
                (string, PoolKey, ModifyLiquidityParams)
            );

            // Add liquidity to the pool
            (BalanceDelta delta,) = poolManager.modifyLiquidity(key, params, "");

            // Handle negative deltas (PoolManager is owed tokens)
            if (delta.amount0() < 0) {
                // Transfer tokens from this contract to PoolManager and settle
                IERC20(Currency.unwrap(key.currency0)).transferFrom(
                    address(this),
                    address(poolManager),
                    uint256(uint128(-delta.amount0()))
                );
                poolManager.settle();
            }
            if (delta.amount1() < 0) {
                // Transfer tokens from this contract to PoolManager and settle
                IERC20(Currency.unwrap(key.currency1)).transferFrom(
                    address(this),
                    address(poolManager),
                    uint256(uint128(-delta.amount1()))
                );
                poolManager.settle();
            }

            // Handle positive deltas (PoolManager owes tokens)
            if (delta.amount0() > 0) {
                poolManager.take(key.currency0, address(this), uint256(uint128(delta.amount0())));
            }
            if (delta.amount1() > 0) {
                poolManager.take(key.currency1, address(this), uint256(uint128(delta.amount1())));
            }

            return abi.encode(delta);
        }

        if (keccak256(abi.encodePacked(operation)) == keccak256(abi.encodePacked("swap"))) {
            (,PoolKey memory key, SwapParams memory params, bytes memory swapHookData, address user, address toToken) = abi.decode(
                data,
                (string, PoolKey, SwapParams, bytes, address, address)
            );

            // Execute the swap
            BalanceDelta delta = poolManager.swap(key, params, swapHookData);

            // Handle negative deltas (PoolManager is owed tokens)
            if (delta.amount0() < 0) {
                poolManager.settle();
            }
            if (delta.amount1() < 0) {
                poolManager.settle();
            }

            // Handle positive deltas (PoolManager owes tokens - send to user)
            if (delta.amount0() > 0) {
                poolManager.take(key.currency0, user, uint256(uint128(delta.amount0())));
            }
            if (delta.amount1() > 0) {
                poolManager.take(key.currency1, user, uint256(uint128(delta.amount1())));
            }

            return abi.encode(BalanceDelta.unwrap(delta));
        }

        revert("Unknown operation");
    }
}