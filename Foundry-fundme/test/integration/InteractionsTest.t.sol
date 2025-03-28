// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test, console } from 'forge-std/Test.sol';
import "forge-std/Vm.sol";
import {FundMe} from "../../src/FundMe.sol";
import { DeployFundMe } from '../../script/DeployFundMe.s.sol';
import { FundFundMe, WithdrawFundMe } from "../../script/Interactions.s.sol";

contract InteractionsTest is Test{
    FundMe fundMe;
    address USER = makeAddr('user');
    uint256 constant SEND_AMOUNT = 1 ether;
    uint256 constant LOW_AMOUNT = 0.0001 ether;
    uint256 constant START_BALANCE = 30 ether;
    uint256 constant GAS_PRICE = 1;

    function setUp() external {
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, SEND_AMOUNT + 0.1 ether);
    }

    function testUserCanFundInteractions() public {
        FundFundMe fundFundMe = new FundFundMe();
        vm.prank(USER);
        vm.deal(USER, SEND_AMOUNT);
        fundFundMe.fundFundMe(address(fundMe));

        WithdrawFundMe withdrawFundMe = new WithdrawFundMe();
        withdrawFundMe.withdrawFundMe(address(fundMe));

        assert(address(fundMe).balance == 0);

    }

}