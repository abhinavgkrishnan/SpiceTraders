// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Credits.sol";

contract CreditsTest is Test {
    Credits public credits;
    address public owner = address(0x1);
    address public minter = address(0x2);
    address public user = address(0x3);

    function setUp() public {
        vm.startPrank(owner);
        credits = new Credits(owner);
        credits.setAuthorizedMinter(minter, true);
        vm.stopPrank();
    }

    function test_Mint() public {
        vm.startPrank(minter);
        credits.mint(user, 1000);
        assertEq(credits.balanceOf(user), 1000);
        vm.stopPrank();
    }

    function test_Fail_UnauthorizedMint() public {
        vm.startPrank(user);
        vm.expectRevert("Not authorized to mint");
        credits.mint(user, 1000);
        vm.stopPrank();
    }

    function test_Burn() public {
        vm.startPrank(minter);
        credits.mint(user, 1000);
        vm.stopPrank();

        vm.startPrank(user);
        credits.burn(500);
        assertEq(credits.balanceOf(user), 500);
        vm.stopPrank();
    }

    function test_Transfer() public {
        vm.startPrank(minter);
        credits.mint(user, 1000);
        vm.stopPrank();

        vm.startPrank(user);
        credits.transfer(owner, 500);
        assertEq(credits.balanceOf(user), 500);
        assertEq(credits.balanceOf(owner), 100000000 * 10**18 + 500);
        vm.stopPrank();
    }

    function test_Fail_ExceedMaxSupply() public {
        vm.startPrank(minter);
        vm.expectRevert("Would exceed max supply");
        credits.mint(user, 1_000_000_001 * 10**18);
        vm.stopPrank();
    }
}