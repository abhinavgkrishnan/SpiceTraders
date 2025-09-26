// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Market.sol";
import "../src/Player.sol";
import "../src/Tokens.sol";
import "../src/World.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

contract MarketTest is Test {
    Market public market;
    Player public player;
    Tokens public tokens;
    World public world;
    PoolManager public poolManager;

    address public owner = address(0x1);
    address public user = address(0x3);

    function setUp() public {
        vm.startPrank(owner);
        world = new World(owner);
        tokens = new Tokens(owner, "https://api.test.game/tokens/{id}.json");
        poolManager = new PoolManager(owner);
        player = new Player(owner, address(world), address(0), address(0)); // Ships and Credits contracts not needed for this test
        market = new Market(owner, address(player), address(tokens), address(poolManager));
        vm.stopPrank();
    }

    function test_SetPlanetMarket() public {
        vm.startPrank(owner);
        PoolId poolId = PoolId.wrap(bytes32(uint256(1)));
        market.setPlanetMarket(1, poolId);
        assertEq(PoolId.unwrap(market.planetMarkets(1)), PoolId.unwrap(poolId));
        vm.stopPrank();
    }

    // Note: A full trade execution test would require a more complex setup
    // with a deployed Uniswap V4 pool, which is beyond the scope of this basic test.
}