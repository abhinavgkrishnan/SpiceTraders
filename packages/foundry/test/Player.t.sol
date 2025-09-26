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

    function test_InstantTravel() public {
        vm.startPrank(owner);
        uint256 shipId = ships.mintShip(user, "Test Ship", 2); // Harkonnen Harvester with 8000 spice capacity, 80 speed
        ships.setAuthorizedManager(address(player), true);
        player.registerPlayer(user, 1, shipId);
        vm.stopPrank();

        vm.startPrank(owner);
        ships.updateSpice(shipId, 5000); // Set to enough spice for travel
        vm.stopPrank();

        // Get initial spice amount and ship attributes
        Ships.ShipAttributes memory shipBefore = ships.getShipAttributes(shipId);
        uint256 initialSpice = shipBefore.currentSpice;

        // Get travel cost
        World.TravelCost memory cost = world.getTravelCost(1, 2);

        // Calculate expected adjusted time cost based on ship speed (80 = 0.8x speed, so longer time)
        uint256 expectedAdjustedTimeCost = (cost.timeCost * 100) / shipBefore.speed;

        vm.startPrank(user);
        player.instantTravel(2);

        // Verify player is in transit (planet 0)
        assertEq(player.getPlayerLocation(user), 0);

        // Verify player is traveling
        assertTrue(player.isPlayerTraveling(user));

        // Verify spice was consumed
        Ships.ShipAttributes memory shipAfter = ships.getShipAttributes(shipId);
        assertEq(shipAfter.currentSpice, initialSpice - cost.spiceCost);

        // Fast forward time to complete travel using adjusted time cost
        vm.warp(block.timestamp + expectedAdjustedTimeCost);

        // Complete travel
        player.completeTravel();

        // Verify player arrived at destination
        assertEq(player.getPlayerLocation(user), 2);

        // Verify player is no longer traveling
        assertFalse(player.isPlayerTraveling(user));

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
        assertEq(ship.currentSpice, 3000); // Full spice tank
        assertEq(ship.speed, 100); // 1.0x speed
        vm.stopPrank();
    }
}