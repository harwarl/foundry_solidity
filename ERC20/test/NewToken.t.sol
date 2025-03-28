// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test, console } from 'forge-std/Test.sol';
import {DeployNewToken} from "script/DeployNewToken.s.sol";
import {NewToken} from "src/NewToken.sol";

contract NewTokenTest is Test {
    DeployNewToken public deployNewToken;
    NewToken public newToken;

    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    uint256 public constant STARTING_BALANCE = 100 ether;
    uint256 public constant INITIAL_ALLOWANCE = 1000;
    uint256 public constant TRANSFER_AMOUNT = 500;

    function setUp() public {
         deployNewToken = new DeployNewToken();
         newToken = deployNewToken.run();

         vm.prank(msg.sender);
         newToken.transfer(bob, STARTING_BALANCE);
    }

    function testBobBalance() public view {
        assertEq(STARTING_BALANCE, newToken.balanceOf(bob));
    }

    function testAllowances() public {
        // bob approves alice to spend tokens on her behalf
        vm.prank(bob);
        newToken.approve(alice, INITIAL_ALLOWANCE);

        vm.prank(alice);
        newToken.transferFrom(bob, alice, TRANSFER_AMOUNT);

        // assertEq(newToken.allowance(bob, alice), INITIAL_ALLOWANCE);
        assertEq(newToken.balanceOf(alice), TRANSFER_AMOUNT);
        assertEq(newToken.balanceOf(bob), STARTING_BALANCE - TRANSFER_AMOUNT);
    }
}