// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Player.sol";
import "../src/World.sol";
import "../src/Ships.sol";
import "../src/Credits.sol";
import "../src/Tokens.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PlayerTest is Test {
    Player public player;
    World public world;
    Ships public ships;
    Credits public credits;
    Tokens public tokens;
    address public owner = address(0x1);
    address public user = address(0x3);

    function setUp() public {
        vm.startPrank(owner);
        world = new World(owner);
        credits = new Credits(owner);
        tokens = new Tokens(owner, "https://api.test.game/tokens/");
        ships = new Ships(owner, "https://api.test.game/ships/", address(credits));
        player = new Player(owner, address(world), address(ships), address(credits), address(tokens));
        ships.setAuthorizedMinter(owner, true);
        ships.setAuthorizedMinter(address(player), true);
        ships.setAuthorizedManager(address(player), true);
        credits.setAuthorizedMinter(address(player), true);
        tokens.setAuthorizedMinter(owner, true);
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

        // After time passes, location should auto-update (no completeTravel() needed)
        assertEq(player.getPlayerLocation(user), 2);
        assertFalse(player.isPlayerTraveling(user));

        // completeTravel() is optional for cleanup
        player.completeTravel();

        // Verify still at destination after cleanup
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
        assertEq(ship.currentSpice, 2000); // Starter ships come with 2000 spice
        assertEq(ship.speed, 100); // 1.0x speed
        vm.stopPrank();
    }

    function test_RefuelShip() public {
        // Setup: Onboard player with starter ship
        vm.startPrank(user);
        player.onboardNewPlayer(user, "Test Ship");
        uint256 shipId = player.getPlayerActiveShip(user);
        vm.stopPrank();

        // Give player some SPICE tokens (token ID 3)
        vm.startPrank(owner);
        tokens.mint(user, 3, 1000, ""); // Mint 1000 SPICE
        vm.stopPrank();

        // Get initial ship spice
        Ships.ShipAttributes memory shipBefore = ships.getShipAttributes(shipId);
        uint256 initialSpice = shipBefore.currentSpice;
        uint256 initialSpiceTokens = tokens.balanceOf(user, 3);

        // Approve Player contract to burn SPICE tokens
        vm.startPrank(user);
        tokens.setApprovalForAll(address(player), true);

        // Refuel with 500 SPICE
        player.refuelShip(shipId, 500);
        vm.stopPrank();

        // Verify ship spice increased
        Ships.ShipAttributes memory shipAfter = ships.getShipAttributes(shipId);
        assertEq(shipAfter.currentSpice, initialSpice + 500);

        // Verify SPICE tokens were burned
        uint256 finalSpiceTokens = tokens.balanceOf(user, 3);
        assertEq(finalSpiceTokens, initialSpiceTokens - 500);
    }

    function test_RefuelShip_CappedAtMaxCapacity() public {
        // Setup: Onboard player with starter ship
        vm.startPrank(user);
        player.onboardNewPlayer(user, "Test Ship");
        uint256 shipId = player.getPlayerActiveShip(user);
        vm.stopPrank();

        // Give player lots of SPICE tokens
        vm.startPrank(owner);
        tokens.mint(user, 3, 5000, ""); // Mint 5000 SPICE
        vm.stopPrank();

        // Try to refuel beyond max capacity (Atreides Scout has 3000 max)
        Ships.ShipAttributes memory shipBefore = ships.getShipAttributes(shipId);
        uint256 maxCapacity = shipBefore.spiceCapacity;

        vm.startPrank(user);
        tokens.setApprovalForAll(address(player), true);
        player.refuelShip(shipId, 2000); // This should cap at max capacity
        vm.stopPrank();

        // Verify ship is at max capacity
        Ships.ShipAttributes memory shipAfter = ships.getShipAttributes(shipId);
        assertEq(shipAfter.currentSpice, maxCapacity);
    }

    function test_Fail_RefuelShip_InsufficientSpiceTokens() public {
        // Setup: Onboard player with starter ship
        vm.startPrank(user);
        player.onboardNewPlayer(user, "Test Ship");
        uint256 shipId = player.getPlayerActiveShip(user);
        vm.stopPrank();

        // Try to refuel without enough SPICE tokens
        vm.startPrank(user);
        vm.expectRevert("Insufficient SPICE tokens");
        player.refuelShip(shipId, 500);
        vm.stopPrank();
    }

    function test_Fail_RefuelShip_NotShipOwner() public {
        // Setup: Onboard player with starter ship
        vm.startPrank(user);
        player.onboardNewPlayer(user, "Test Ship");
        uint256 shipId = player.getPlayerActiveShip(user);
        vm.stopPrank();

        // Give another user SPICE tokens and register them
        address attacker = address(0x4);
        vm.startPrank(attacker);
        player.onboardNewPlayer(attacker, "Attacker Ship");
        vm.stopPrank();

        vm.startPrank(owner);
        tokens.mint(attacker, 3, 1000, "");
        vm.stopPrank();

        // Try to refuel someone else's ship
        vm.startPrank(attacker);
        tokens.setApprovalForAll(address(player), true);
        vm.expectRevert("Player does not own this ship");
        player.refuelShip(shipId, 500);
        vm.stopPrank();
    }

    function test_Fail_RefuelShip_DuringTravel() public {
        // Setup: Onboard player and start travel
        vm.startPrank(user);
        player.onboardNewPlayer(user, "Test Ship");
        uint256 shipId = player.getPlayerActiveShip(user);
        vm.stopPrank();

        // Give player SPICE tokens
        vm.startPrank(owner);
        tokens.mint(user, 3, 1000, "");
        vm.stopPrank();

        // Start travel
        vm.startPrank(user);
        player.instantTravel(2); // Travel to Arrakis

        // Try to refuel during travel
        vm.expectRevert("Cannot refuel during travel");
        player.refuelShip(shipId, 500);
        vm.stopPrank();
    }

    function test_BuyShip() public {
        // Setup: Onboard player
        vm.startPrank(user);
        player.onboardNewPlayer(user, "First Ship");
        vm.stopPrank();

        // Give player enough credits to buy a Guild Frigate (25,000 Solaris)
        vm.startPrank(owner);
        credits.mint(user, 25000 * 10**18);
        vm.stopPrank();

        // Get initial state
        Player.PlayerState memory stateBefore = player.getPlayerState(user);
        uint256 initialShipCount = stateBefore.shipIds.length;
        uint256 initialCredits = credits.balanceOf(user);

        // Approve credits for purchase
        vm.startPrank(user);
        credits.approve(address(player), 25000 * 10**18);

        // Buy a Guild Frigate (class 1)
        player.buyShip("My Frigate", 1);
        vm.stopPrank();

        // Verify new ship was added to player's fleet
        Player.PlayerState memory stateAfter = player.getPlayerState(user);
        assertEq(stateAfter.shipIds.length, initialShipCount + 1);

        // Verify credits were deducted
        uint256 finalCredits = credits.balanceOf(user);
        assertEq(finalCredits, initialCredits - 25000 * 10**18);

        // Verify ship attributes
        uint256 newShipId = stateAfter.shipIds[stateAfter.shipIds.length - 1];
        Ships.ShipAttributes memory ship = ships.getShipAttributes(newShipId);
        assertEq(ship.shipClass, 1); // Guild Frigate
        assertEq(ship.cargoCapacity, 500);
        assertEq(ship.spiceCapacity, 5000);
        assertEq(ship.speed, 120); // 1.2x speed
        assertEq(ship.currentSpice, 5000); // New ships start with full tank
    }

    function test_AutoCompleteTravelWithoutExplicitCall() public {
        vm.startPrank(owner);
        uint256 shipId = ships.mintShip(user, "Test Ship", 2);
        ships.setAuthorizedManager(address(player), true);
        player.registerPlayer(user, 1, shipId);
        vm.stopPrank();

        vm.startPrank(owner);
        ships.updateSpice(shipId, 5000);
        vm.stopPrank();

        Ships.ShipAttributes memory shipBefore = ships.getShipAttributes(shipId);
        World.TravelCost memory cost = world.getTravelCost(1, 2);
        uint256 expectedAdjustedTimeCost = (cost.timeCost * 100) / shipBefore.speed;

        vm.startPrank(user);
        player.instantTravel(2);

        // During travel: location should be 0, traveling should be true
        assertEq(player.getPlayerLocation(user), 0);
        assertTrue(player.isPlayerTraveling(user));

        // Fast forward time past travel completion
        vm.warp(block.timestamp + expectedAdjustedTimeCost);

        // After time passes: location should auto-update to destination WITHOUT calling completeTravel()
        assertEq(player.getPlayerLocation(user), 2);
        assertFalse(player.isPlayerTraveling(user));

        vm.stopPrank();
    }

    function test_SetActiveShip() public {
        // Setup: Onboard player
        vm.startPrank(user);
        player.onboardNewPlayer(user, "First Ship");
        vm.stopPrank();

        uint256 firstShipId = player.getPlayerActiveShip(user);

        // Give player credits and buy another ship
        vm.startPrank(owner);
        credits.mint(user, 10000 * 10**18);
        vm.stopPrank();

        vm.startPrank(user);
        credits.approve(address(player), 10000 * 10**18);
        player.buyShip("Second Ship", 0);

        Player.PlayerState memory state = player.getPlayerState(user);
        uint256 secondShipId = state.shipIds[state.shipIds.length - 1];

        // Switch to second ship
        player.setActiveShip(secondShipId);

        // Verify active ship changed
        assertEq(player.getPlayerActiveShip(user), secondShipId);

        // Switch back to first ship
        player.setActiveShip(firstShipId);
        assertEq(player.getPlayerActiveShip(user), firstShipId);
        vm.stopPrank();
    }
}