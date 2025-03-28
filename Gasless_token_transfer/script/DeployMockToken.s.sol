// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {MockToken} from 'test/mocks/MockToken.sol';

contract DeployMockToken is Script {
    MockToken mockToken;

    function run() public returns (MockToken) {
        vm.startBroadcast();
        mockToken = new MockToken();
        vm.stopBroadcast();
        return mockToken;
    }
}