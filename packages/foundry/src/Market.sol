// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
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
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import "./Player.sol";
import "./Tokens.sol";
import "./Credits.sol";
import "./ResourceWrapper.sol";

/**
 * @title Market
 * @dev Planet-specific trading markets with automatic ERC1155/ERC20 wrapping
 * Architecture: 5 planets × 4 resources = 20 trading pairs (Resource/Credits)
 * Each planet has 4 pools: wMETAL/Credits, wSAPHO/Credits, wWATER/Credits, wSPICE/Credits
 */
contract Market is Ownable, ReentrancyGuard, SafeCallback, IERC1155Receiver {
    using PoolIdLibrary for PoolKey;

    Player public playerContract;
    Tokens public tokensContract;
    Credits public creditsContract;

    // Resource IDs from Tokens.sol
    uint256 public constant METAL = 0;
    uint256 public constant SAPHO_JUICE = 1;
    uint256 public constant WATER = 2;
    uint256 public constant SPICE = 3;

    // Planet IDs (1-5)
    uint256 public constant CALADAN = 1;
    uint256 public constant ARRAKIS = 2;
    uint256 public constant GIEDI_PRIME = 3;
    uint256 public constant IX = 4;
    uint256 public constant KAITAIN = 5;

    struct LiquidityPosition {
        address owner;
        uint256 planetId;
        uint256 resourceId;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 positionId;
        bool isActive;
    }

    struct TradingPair {
        PoolKey poolKey;
        PoolId poolId;
        ResourceWrapper wrappedResource;
        bool isInitialized;
    }

    // Maps planet ID => resource ID => trading pair
    mapping(uint256 => mapping(uint256 => TradingPair)) public planetMarkets;

    // Position management
    mapping(address => LiquidityPosition[]) public userPositions;
    mapping(uint256 => LiquidityPosition) public positions;
    uint256 public nextPositionId = 1;

    // Events
    event MarketInitialized(uint256 indexed planetId, uint256 indexed resourceId, PoolId poolId);
    event TradeExecuted(
        address indexed trader,
        uint256 indexed planetId,
        uint256 resourceId,
        bool resourceToCredits,
        uint256 amountIn,
        uint256 amountOut
    );
    event LiquidityAdded(
        address indexed provider,
        uint256 indexed positionId,
        uint256 planetId,
        uint256 resourceId,
        uint128 liquidity
    );
    event LiquidityRemoved(
        address indexed provider,
        uint256 indexed positionId,
        uint128 liquidity
    );

    modifier atPlanet(uint256 planetId) {
        uint256 playerLocation = playerContract.getPlayerLocation(msg.sender);
        require(playerLocation == planetId, "You are not at this planet");
        _;
    }

    modifier validPlanet(uint256 planetId) {
        require(planetId >= 1 && planetId <= 5, "Invalid planet ID");
        _;
    }

    modifier validResource(uint256 resourceId) {
        require(resourceId <= 3, "Invalid resource ID");
        _;
    }

    constructor(
        address initialOwner,
        address _playerContract,
        address _tokensContract,
        address _creditsContract,
        address _poolManager
    ) Ownable(initialOwner) SafeCallback(IPoolManager(_poolManager)) {
        playerContract = Player(_playerContract);
        tokensContract = Tokens(_tokensContract);
        creditsContract = Credits(_creditsContract);
    }

    /**
     * @dev Initialize a trading pair for a specific planet and resource
     */
    function initializeTradingPair(
        uint256 planetId,
        uint256 resourceId,
        address wrappedResourceAddress,
        uint24 fee,
        int24 tickSpacing,
        address hookContract,
        uint160 sqrtPriceX96
    ) external onlyOwner validPlanet(planetId) validResource(resourceId) {
        require(
            !planetMarkets[planetId][resourceId].isInitialized,
            "Trading pair already initialized"
        );

        ResourceWrapper wrappedResource = ResourceWrapper(wrappedResourceAddress);
        require(wrappedResource.resourceId() == resourceId, "Resource ID mismatch");

        // Ensure currencies are sorted (Credits < WrappedResource typically)
        Currency currency0;
        Currency currency1;

        if (address(creditsContract) < wrappedResourceAddress) {
            currency0 = Currency.wrap(address(creditsContract));
            currency1 = Currency.wrap(wrappedResourceAddress);
        } else {
            currency0 = Currency.wrap(wrappedResourceAddress);
            currency1 = Currency.wrap(address(creditsContract));
        }

        // Create pool key
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(hookContract)
        });

        // Initialize the pool
        poolManager.initialize(poolKey, sqrtPriceX96);

        // Store trading pair
        PoolId poolId = poolKey.toId();
        planetMarkets[planetId][resourceId] = TradingPair({
            poolKey: poolKey,
            poolId: poolId,
            wrappedResource: wrappedResource,
            isInitialized: true
        });

        emit MarketInitialized(planetId, resourceId, poolId);
    }

    /**
     * @dev Add liquidity using wrapped ERC20 tokens (wMETAL + Credits)
     */
    function addLiquidity(
        uint256 planetId,
        uint256 resourceId,
        int24 tickLower,
        int24 tickUpper,
        uint256 wrappedAmount,
        uint256 creditsAmount,
        uint256 /* slippageTolerance */
    ) external nonReentrant validPlanet(planetId) validResource(resourceId) returns (uint256 positionId) {
        TradingPair storage pair = planetMarkets[planetId][resourceId];
        require(pair.isInitialized, "Trading pair not initialized");

        // Transfer wrapped tokens and credits from user
        IERC20(address(pair.wrappedResource)).transferFrom(msg.sender, address(this), wrappedAmount);
        creditsContract.transferFrom(msg.sender, address(this), creditsAmount);

        // Approve PoolManager to spend tokens
        IERC20(address(pair.wrappedResource)).approve(address(poolManager), wrappedAmount);
        creditsContract.approve(address(poolManager), creditsAmount);

        // Add liquidity through unlock callback
        positionId = nextPositionId++;

        bytes memory unlockData = abi.encode(
            "addLiquidity",
            pair.poolKey,
            ModifyLiquidityParams({
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: int256(_calculateLiquidity(wrappedAmount, creditsAmount, tickLower, tickUpper)),
                salt: bytes32(uint256(positionId))
            }),
            msg.sender,
            positionId,
            planetId,
            resourceId
        );

        poolManager.unlock(unlockData);

        emit LiquidityAdded(msg.sender, positionId, planetId, resourceId, uint128(_calculateLiquidity(wrappedAmount, creditsAmount, tickLower, tickUpper)));
    }

    /**
     * @dev Remove liquidity from a position
     */
    function removeLiquidity(
        uint256 positionId,
        uint128 liquidityToRemove
    ) external nonReentrant {
        LiquidityPosition storage position = positions[positionId];
        require(position.owner == msg.sender, "Not position owner");
        require(position.isActive, "Position not active");
        require(position.liquidity >= liquidityToRemove, "Insufficient liquidity");

        TradingPair storage pair = planetMarkets[position.planetId][position.resourceId];

        bytes memory unlockData = abi.encode(
            "removeLiquidity",
            pair.poolKey,
            ModifyLiquidityParams({
                tickLower: position.tickLower,
                tickUpper: position.tickUpper,
                liquidityDelta: -int256(uint256(liquidityToRemove)),
                salt: bytes32(positionId)
            }),
            msg.sender,
            positionId
        );

        poolManager.unlock(unlockData);

        position.liquidity -= liquidityToRemove;
        if (position.liquidity == 0) {
            position.isActive = false;
        }

        emit LiquidityRemoved(msg.sender, positionId, liquidityToRemove);
    }

    /**
     * @dev Execute a trade with automatic wrapping/unwrapping
     * @param planetId Planet to trade on
     * @param resourceId Resource to trade
     * @param resourceToCredits True if trading resource for credits, false for credits to resource
     * @param amountIn Amount of input token
     * @param minAmountOut Minimum amount of output token (slippage protection)
     */
    function executeTrade(
        uint256 planetId,
        uint256 resourceId,
        bool resourceToCredits,
        uint256 amountIn,
        uint256 minAmountOut
    ) external nonReentrant atPlanet(planetId) validPlanet(planetId) validResource(resourceId) returns (uint256 amountOut) {
        TradingPair storage pair = planetMarkets[planetId][resourceId];
        require(pair.isInitialized, "Trading pair not initialized");

        if (resourceToCredits) {
            // Trading resource for credits
            // 1. Transfer ERC1155 from user
            tokensContract.safeTransferFrom(msg.sender, address(this), resourceId, amountIn, "");

            // 2. Wrap to ERC20
            tokensContract.setApprovalForAll(address(pair.wrappedResource), true);
            pair.wrappedResource.wrap(amountIn);

            // 3. Execute swap
            amountOut = _executeSwap(pair, true, amountIn, minAmountOut);

            // 4. Transfer credits to user
            creditsContract.transfer(msg.sender, amountOut);
        } else {
            // Trading credits for resource
            // 1. Transfer credits from user
            creditsContract.transferFrom(msg.sender, address(this), amountIn);

            // 2. Execute swap
            amountOut = _executeSwap(pair, false, amountIn, minAmountOut);

            // 3. Unwrap ERC20 to ERC1155
            pair.wrappedResource.unwrap(amountOut);

            // 4. Transfer ERC1155 to user
            tokensContract.safeTransferFrom(address(this), msg.sender, resourceId, amountOut, "");
        }

        playerContract.updateLastActionTimestamp(msg.sender);

        emit TradeExecuted(msg.sender, planetId, resourceId, resourceToCredits, amountIn, amountOut);
    }

    /**
     * @dev Get a quote for a trade without executing it
     */
    function getQuote(
        uint256 planetId,
        uint256 resourceId,
        bool resourceToCredits,
        uint256 amountIn
    ) external view validPlanet(planetId) validResource(resourceId) returns (uint256 amountOut) {
        TradingPair storage pair = planetMarkets[planetId][resourceId];
        require(pair.isInitialized, "Trading pair not initialized");

        // This would integrate with a quoter contract in production
        // For now, return a placeholder that could be implemented with actual pool state
        return _calculateQuote(pair.poolKey, resourceToCredits, amountIn);
    }

    /**
     * @dev Internal function to execute swaps
     */
    function _executeSwap(
        TradingPair storage pair,
        bool resourceToCredits,
        uint256 amountIn,
        uint256 minAmountOut
    ) internal returns (uint256 amountOut) {
        // Determine swap direction based on currency order and trade direction
        bool zeroForOne;
        address inputToken;
        address outputToken;

        if (resourceToCredits) {
            inputToken = address(pair.wrappedResource);
            outputToken = address(creditsContract);
            zeroForOne = (Currency.unwrap(pair.poolKey.currency0) == inputToken);
        } else {
            inputToken = address(creditsContract);
            outputToken = address(pair.wrappedResource);
            zeroForOne = (Currency.unwrap(pair.poolKey.currency0) == inputToken);
        }

        // Approve pool manager
        IERC20(inputToken).approve(address(poolManager), amountIn);

        bytes memory unlockData = abi.encode(
            "swap",
            pair.poolKey,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: int256(amountIn),
                sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
            }),
            msg.sender,
            outputToken,
            minAmountOut
        );

        bytes memory result = poolManager.unlock(unlockData);
        BalanceDelta delta = BalanceDelta.wrap(abi.decode(result, (int256)));

        // Calculate amount out based on delta
        amountOut = uint256(uint128(-delta.amount1()));
        require(amountOut >= minAmountOut, "Slippage tolerance exceeded");
    }

    /**
     * @dev Calculate liquidity for given amounts (simplified)
     */
    function _calculateLiquidity(
        uint256 amount0,
        uint256 amount1,
        int24 /* tickLower */,
        int24 /* tickUpper */
    ) internal pure returns (uint256) {
        // Simplified liquidity calculation
        // In production, this would use proper Uniswap v4 math
        return (amount0 + amount1) / 2;
    }

    /**
     * @dev Calculate quote for a trade (placeholder)
     */
    function _calculateQuote(
        PoolKey memory /* poolKey */,
        bool /* resourceToCredits */,
        uint256 amountIn
    ) internal pure returns (uint256) {
        // Placeholder quote calculation
        // In production, this would query pool state and calculate exact output
        return (amountIn * 995) / 1000; // 0.5% fee simulation
    }

    /**
     * @dev Get planet requirement for a pool (used by hooks)
     */
    function getPoolPlanetRequirement(PoolKey calldata key) external view returns (uint256) {
        PoolId poolId = key.toId();

        for (uint256 planetId = 1; planetId <= 5; planetId++) {
            for (uint256 resourceId = 0; resourceId <= 3; resourceId++) {
                if (PoolId.unwrap(planetMarkets[planetId][resourceId].poolId) == PoolId.unwrap(poolId)) {
                    return planetId;
                }
            }
        }
        return 0;
    }

    /**
     * @dev Get user's positions
     */
    function getUserPositions(address user) external view returns (LiquidityPosition[] memory) {
        return userPositions[user];
    }

    /**
     * @dev Get trading pair info
     */
    function getTradingPair(uint256 planetId, uint256 resourceId) external view returns (TradingPair memory) {
        return planetMarkets[planetId][resourceId];
    }

    /**
     * @dev Unlock callback for Uniswap V4 operations
     */
    function _unlockCallback(bytes calldata data) internal override returns (bytes memory) {
        string memory operation = abi.decode(data, (string));

        if (keccak256(abi.encodePacked(operation)) == keccak256(abi.encodePacked("addLiquidity"))) {
            (
                ,
                PoolKey memory key,
                ModifyLiquidityParams memory params,
                address owner,
                uint256 positionId,
                uint256 planetId,
                uint256 resourceId
            ) = abi.decode(data, (string, PoolKey, ModifyLiquidityParams, address, uint256, uint256, uint256));

            (BalanceDelta delta,) = poolManager.modifyLiquidity(key, params, "");

            // Handle negative deltas (we owe tokens to pool)
            if (delta.amount0() < 0) {
                // Sync, transfer, then settle
                poolManager.sync(key.currency0);
                IERC20(Currency.unwrap(key.currency0)).transfer(
                    address(poolManager),
                    uint256(uint128(-delta.amount0()))
                );
                poolManager.settle();
            }
            if (delta.amount1() < 0) {
                // Sync, transfer, then settle
                poolManager.sync(key.currency1);
                IERC20(Currency.unwrap(key.currency1)).transfer(
                    address(poolManager),
                    uint256(uint128(-delta.amount1()))
                );
                poolManager.settle();
            }

            // Handle positive deltas (pool owes tokens to us)
            if (delta.amount0() > 0) {
                poolManager.take(key.currency0, address(this), uint256(uint128(delta.amount0())));
            }
            if (delta.amount1() > 0) {
                poolManager.take(key.currency1, address(this), uint256(uint128(delta.amount1())));
            }

            // Store position
            positions[positionId] = LiquidityPosition({
                owner: owner,
                planetId: planetId,
                resourceId: resourceId,
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                liquidity: uint128(uint256(params.liquidityDelta)),
                positionId: positionId,
                isActive: true
            });
            userPositions[owner].push(positions[positionId]);

            return abi.encode(delta);
        }

        if (keccak256(abi.encodePacked(operation)) == keccak256(abi.encodePacked("removeLiquidity"))) {
            (
                ,
                PoolKey memory key,
                ModifyLiquidityParams memory params,
                address owner,
                /* uint256 positionId */
            ) = abi.decode(data, (string, PoolKey, ModifyLiquidityParams, address, uint256));

            (BalanceDelta delta,) = poolManager.modifyLiquidity(key, params, "");

            // Handle positive deltas (pool owes tokens to us)
            if (delta.amount0() > 0) {
                poolManager.take(key.currency0, owner, uint256(uint128(delta.amount0())));
            }
            if (delta.amount1() > 0) {
                poolManager.take(key.currency1, owner, uint256(uint128(delta.amount1())));
            }

            return abi.encode(delta);
        }

        if (keccak256(abi.encodePacked(operation)) == keccak256(abi.encodePacked("swap"))) {
            (
                ,
                PoolKey memory key,
                SwapParams memory params,
                address user,
                /* address outputToken */,
                /* uint256 minAmountOut */
            ) = abi.decode(data, (string, PoolKey, SwapParams, address, address, uint256));

            // Pass user address to hook for location validation
            bytes memory hookData = abi.encode(user);
            BalanceDelta delta = poolManager.swap(key, params, hookData);

            // Handle negative deltas (we owe tokens to pool)
            if (delta.amount0() < 0) {
                // Sync, transfer, then settle
                poolManager.sync(key.currency0);
                IERC20(Currency.unwrap(key.currency0)).transfer(
                    address(poolManager),
                    uint256(uint128(-delta.amount0()))
                );
                poolManager.settle();
            }
            if (delta.amount1() < 0) {
                // Sync, transfer, then settle
                poolManager.sync(key.currency1);
                IERC20(Currency.unwrap(key.currency1)).transfer(
                    address(poolManager),
                    uint256(uint128(-delta.amount1()))
                );
                poolManager.settle();
            }

            // Handle positive deltas (pool owes tokens to us)
            if (delta.amount0() > 0) {
                poolManager.take(key.currency0, address(this), uint256(uint128(delta.amount0())));
            }
            if (delta.amount1() > 0) {
                poolManager.take(key.currency1, address(this), uint256(uint128(delta.amount1())));
            }

            return abi.encode(BalanceDelta.unwrap(delta));
        }

        revert("Unknown operation");
    }

    /**
     * @dev Emergency functions for admin
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }

    function emergencyWithdrawERC1155(uint256 tokenId, uint256 amount) external onlyOwner {
        tokensContract.safeTransferFrom(address(this), owner(), tokenId, amount, "");
    }

    /**
     * @dev ERC1155 receiver
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public pure override returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public pure override returns (bytes4) {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }
}