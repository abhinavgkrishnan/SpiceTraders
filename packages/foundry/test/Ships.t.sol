// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Ships.sol";
import "../src/Credits.sol";

contract ShipsTest is Test {
    Ships public ships;
    Credits public credits;
    address public owner = address(0x1);
    address public minter = address(0x2);
    address public user = address(0x3);

    function setUp() public {
        vm.startPrank(owner);
        credits = new Credits(owner);
        ships = new Ships(owner, "https://api.test.game/ships/", address(credits));
        ships.setAuthorizedMinter(minter, true);
        vm.stopPrank();
    }

    function test_MintShip() public {
        vm.startPrank(minter);
        uint256 tokenId = ships.mintShip(user, "Test Ship", 0);
        assertEq(ships.ownerOf(tokenId), user);
        Ships.ShipAttributes memory ship = ships.getShipAttributes(tokenId);
        assertEq(ship.shipClass, 0);
        assertEq(ship.speed, 100); // Atreides Scout: 1.0x speed
        assertEq(ship.spiceCapacity, 3000); // Atreides Scout capacity
        assertEq(ship.currentSpice, 3000); // Starts with full tank
        vm.stopPrank();
    }

    function test_Fail_UnauthorizedMint() public {
        vm.startPrank(user);
        vm.expectRevert("Not authorized to mint");
        ships.mintShip(user, "Test Ship", 0);
        vm.stopPrank();
    }

    function test_UpdateSpice() public {
        vm.startPrank(owner);
        ships.setAuthorizedManager(minter, true);
        vm.stopPrank();

        vm.startPrank(minter);
        uint256 tokenId = ships.mintShip(user, "Test Ship", 0);
        ships.updateSpice(tokenId, 100);
        assertEq(ships.getShipAttributes(tokenId).currentSpice, 100);
        vm.stopPrank();
    }

    function test_Fail_UnauthorizedUpdateSpice() public {
        vm.startPrank(minter);
        uint256 tokenId = ships.mintShip(user, "Test Ship", 0);
        vm.stopPrank();

        vm.startPrank(user);
        vm.expectRevert("Not authorized to manage");
        ships.updateSpice(tokenId, 100);
        vm.stopPrank();
    }

    function test_Transfer() public {
        vm.startPrank(minter);
        uint256 tokenId = ships.mintShip(user, "Test Ship", 0);
        vm.stopPrank();

        vm.startPrank(user);
        ships.transferFrom(user, owner, tokenId);
        assertEq(ships.ownerOf(tokenId), owner);
        vm.stopPrank();
    }
}