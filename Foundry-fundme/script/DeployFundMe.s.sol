// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {FundMe} from '../src/FundMe.sol';
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract DeployFundMe is Script{
    FundMe fundMe;
    function run() external returns (FundMe) {
        //Before Broadcast => Not a "real" tx
        HelperConfig helperConfig = new HelperConfig();
        address ethUsdPriceFeed = helperConfig.activeNetworkConfig();

        //After Broadcast => Real tx!
        vm.startBroadcast();
        fundMe = new FundMe(ethUsdPriceFeed);
        
        vm.stopBroadcast();
        return fundMe;
    }
}