// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Tokens.sol";

contract TokensTest is Test {
    Tokens public tokens;
    address public owner = address(0x1);
    address public minter = address(0x2);
    address public user = address(0x3);

    function setUp() public {
        vm.startPrank(owner);
        tokens = new Tokens(owner, "https://api.test.game/tokens/{id}.json");
        tokens.setAuthorizedMinter(minter, true);
        vm.stopPrank();
    }

    function test_Mint() public {
        vm.startPrank(minter);
        tokens.mint(user, 0, 100, "");
        assertEq(tokens.balanceOf(user, 0), 100);
        vm.stopPrank();
    }

    function test_Fail_UnauthorizedMint() public {
        vm.startPrank(user);
        vm.expectRevert("Not authorized to mint");
        tokens.mint(user, 0, 100, "");
        vm.stopPrank();
    }

    function test_Burn() public {
        vm.startPrank(minter);
        tokens.mint(user, 0, 100, "");
        vm.stopPrank();

        vm.startPrank(user);
        tokens.burn(user, 0, 50);
        assertEq(tokens.balanceOf(user, 0), 50);
        vm.stopPrank();
    }

    function test_Transfer() public {
        vm.startPrank(minter);
        tokens.mint(user, 0, 100, "");
        vm.stopPrank();

        vm.startPrank(user);
        tokens.safeTransferFrom(user, owner, 0, 50, "");
        assertEq(tokens.balanceOf(user, 0), 50);
        assertEq(tokens.balanceOf(owner, 0), 50);
        vm.stopPrank();
    }
}