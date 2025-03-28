// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {GaslessTokenTransfer} from 'src/GaslessTokenTransfer.sol';

contract DeployGaslessTokenTransfer is Script {
    GaslessTokenTransfer gaslessTokenTransfer;
    function run() external returns (GaslessTokenTransfer) {
        vm.startBroadcast();
        gaslessTokenTransfer = new GaslessTokenTransfer();
        vm.stopBroadcast();
        return gaslessTokenTransfer;
    }
}