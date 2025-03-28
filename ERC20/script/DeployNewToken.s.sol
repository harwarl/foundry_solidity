// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import { NewToken} from "src/NewToken.sol";

contract DeployNewToken is Script {

    uint256 public constant INITIAL_SUPPLY = 1000 ether;

    function run() external returns (NewToken){
        vm.startBroadcast();
        NewToken newToken = new NewToken(INITIAL_SUPPLY);
        vm.stopBroadcast();
        return newToken;
    }
}