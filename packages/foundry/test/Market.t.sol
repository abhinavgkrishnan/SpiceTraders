// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Market.sol";
import "../src/Player.sol";
import "../src/Tokens.sol";
import "../src/Credits.sol";
import "../src/World.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

contract MarketTest is Test {
    Market public market;
    Player public player;
    Tokens public tokens;
    Credits public credits;
    World public world;
    PoolManager public poolManager;

    address public owner = address(0x1);
    address public user = address(0x3);

    function setUp() public {
        vm.startPrank(owner);
        world = new World(owner);
        tokens = new Tokens(owner, "https://api.test.game/tokens/{id}.json");
        credits = new Credits(owner);
        poolManager = new PoolManager(owner);
        player = new Player(owner, address(world), address(0), address(credits));
        market = new Market(owner, address(player), address(tokens), address(credits), address(poolManager));
        vm.stopPrank();
    }

    function test_GetPlanetRequirement() public {
        // Test that planet requirement is 0 for uninitialized pools
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(1)),
            fee: 500,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });

        uint256 requirement = market.getPoolPlanetRequirement(key);
        assertEq(requirement, 0);
    }

}