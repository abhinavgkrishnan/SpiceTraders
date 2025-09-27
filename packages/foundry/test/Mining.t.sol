// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Mining.sol";
import "../src/Tokens.sol";
import "../src/Player.sol";
import "../src/World.sol";
import "../src/Ships.sol";
import "../src/Credits.sol";

contract MiningTest is Test {
    Mining public mining;
    Tokens public tokens;
    Player public player;
    World public world;
    Ships public ships;
    Credits public credits;
    address public owner = address(0x1);
    address public user = address(0x3);

    function setUp() public {
        vm.startPrank(owner);
        tokens = new Tokens(owner, "https://api.test.game/tokens/{id}.json");
        world = new World(owner);
        credits = new Credits(owner);
        ships = new Ships(owner, "https://api.test.game/ships/", address(credits));
        ships.setAuthorizedMinter(owner, true);
        player = new Player(owner, address(world), address(ships), address(credits), address(tokens));
        mining = new Mining(owner, address(tokens), address(player), address(world), address(ships), 0x41c9e39574F40Ad34c79f1C99B66A45eFB830d4c);
        tokens.setAuthorizedMinter(address(mining), true);
        uint256 shipId = ships.mintStarterShip(user, "Test Ship");
        player.registerPlayer(user, 1, shipId);
        vm.stopPrank();
    }

    function test_Mine() public {
        vm.warp(block.timestamp + 10 minutes); // Set timestamp to avoid cooldown issues
        vm.deal(user, 1 ether); // Give user some ETH for Pyth fees
        vm.startPrank(user);
        mining.mine{value: 0.001 ether}(); // Send some ETH for Pyth fee
        assertTrue(tokens.balanceOf(user, 0) > 0 || tokens.balanceOf(user, 1) > 0 || tokens.balanceOf(user, 2) > 0 || tokens.balanceOf(user, 3) > 0);
        vm.stopPrank();
    }

    function test_Fail_MiningCooldown() public {
        vm.warp(block.timestamp + 10 minutes); // Set timestamp to avoid initial cooldown issues
        vm.deal(user, 1 ether); // Give user some ETH for Pyth fees
        vm.startPrank(user);
        mining.mine{value: 0.001 ether}();
        vm.expectRevert("Mining cooldown active");
        mining.mine{value: 0.001 ether}();
        vm.stopPrank();
    }

    function test_Mine_AfterCooldown() public {
        vm.warp(block.timestamp + 10 minutes); // Set timestamp to avoid initial cooldown issues
        vm.deal(user, 1 ether); // Give user some ETH for Pyth fees
        vm.startPrank(user);
        mining.mine{value: 0.001 ether}();
        vm.warp(block.timestamp + mining.MINING_COOLDOWN() + 1);
        mining.mine{value: 0.001 ether}();
        vm.stopPrank();
    }
}