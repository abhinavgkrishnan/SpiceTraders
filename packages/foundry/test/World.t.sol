// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/World.sol";

contract WorldTest is Test {
    World public world;
    address public owner = address(0x1);

    function setUp() public {
        vm.startPrank(owner);
        world = new World(owner);
        vm.stopPrank();
    }

    function test_CreatePlanet() public {
        vm.startPrank(owner);
        uint256[4] memory concentrations = [uint256(10), 20, 30, 40];
        uint256 planetId = world.createPlanet("Test Planet", 1, 2, 3, concentrations, 100);
        assertEq(world.planetCount(), 6); // 5 default + 1 new
        (, uint256 x, , , , ) = world.planets(planetId);
        assertEq(x, 1);
        vm.stopPrank();
    }

    function test_Fail_UnauthorizedCreatePlanet() public {
        address unauth = address(0x4);
        vm.startPrank(unauth);
        uint256[4] memory concentrations = [uint256(10), 20, 30, 40];
        vm.expectRevert();
        world.createPlanet("Test Planet", 1, 2, 3, concentrations, 100);
        vm.stopPrank();
    }

    function test_UpdatePlanetResources() public {
        vm.startPrank(owner);
        uint256[4] memory concentrations = [uint256(10), 20, 30, 40];
        uint256 planetId = world.createPlanet("Test Planet", 1, 2, 3, concentrations, 100);

        uint256[4] memory newConcentrations = [uint256(50), 60, 70, 80];
        world.updatePlanetResources(planetId, newConcentrations, 120);
        assertEq(world.getPlanetResourceConcentration(planetId, 0), 50);
        assertEq(world.getPlanetBaseMiningDifficulty(planetId), 120);
        vm.stopPrank();
    }
}