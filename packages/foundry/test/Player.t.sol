// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Player.sol";
import "../src/World.sol";
import "../src/Ships.sol";
import "../src/Credits.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PlayerTest is Test {
    Player public player;
    World public world;
    Ships public ships;
    Credits public credits;
    address public owner = address(0x1);
    address public user = address(0x3);

    function setUp() public {
        vm.startPrank(owner);
        world = new World(owner);
        ships = new Ships(owner, "https://api.test.game/ships/");
        credits = new Credits(owner);
        player = new Player(owner, address(world), address(ships), address(credits));
        ships.setAuthorizedMinter(owner, true);
        ships.setAuthorizedMinter(address(player), true);
        credits.setAuthorizedMinter(address(player), true);
        vm.stopPrank();
    }

    function test_RegisterPlayer() public {
        vm.startPrank(owner);
        uint256 shipId = ships.mintStarterShip(user, "Starter Ship");
        player.registerPlayer(user, 1, shipId);
        assertTrue(player.isPlayerRegistered(user));
        assertEq(player.getPlayerLocation(user), 1);
        vm.stopPrank();
    }

    function test_Fail_UnauthorizedRegister() public {
        vm.startPrank(owner);
        uint256 shipId = ships.mintStarterShip(user, "Starter Ship");
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert();
        player.registerPlayer(user, 1, shipId);
        vm.stopPrank();
    }

    function test_StartAndCompleteTravel() public {
        vm.startPrank(owner);
        uint256 shipId = ships.mintShip(user, "Test Ship", 2); // Harkonnen Harvester with 800 spice capacity
        ships.setAuthorizedManager(address(player), true);
        player.registerPlayer(user, 1, shipId);
        vm.stopPrank();

        vm.startPrank(owner);
        ships.updateSpice(shipId, 800); // Set to max capacity for Harkonnen Harvester
        vm.stopPrank();

        vm.startPrank(user);
        player.startTravel(2);
        assertTrue(player.isPlayerTraveling(user));

        // Roll blocks forward to complete travel
        vm.roll(block.number + world.getTravelCost(1, 2).timeCost);

        player.completeTravel();
        assertEq(player.getPlayerLocation(user), 2);
        vm.stopPrank();
    }

    function test_OnboardNewPlayer() public {
        vm.startPrank(user);
        player.onboardNewPlayer(user, "My First Ship");

        assertTrue(player.isPlayerRegistered(user));
        assertEq(player.getPlayerLocation(user), 1); // Should be on Caladan
        assertEq(credits.balanceOf(user), 1500 * 10**18); // Should have 1500 Solaris

        uint256 shipId = player.getPlayerActiveShip(user);
        Ships.ShipAttributes memory ship = ships.getShipAttributes(shipId);
        assertEq(ship.shipClass, 0); // Atreides Scout
        assertEq(ship.currentSpice, 300); // Full spice tank
        vm.stopPrank();
    }
}