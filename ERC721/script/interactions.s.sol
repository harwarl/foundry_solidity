// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { Script } from "forge-std/Script.sol";
import { DevOpsTools} from 'lib/foundry-devops/src/DevOpsTools.sol';
import { BasicNFT } from "../src/BasicNFT.sol";

contract MintBasicNft is Script {
    string public constant PUG_URI = "https://ipfs.io/ipfs/QmSsYRx3LpDAb1GZQm7zZ1AuHZjfbPkD6J7s9r41xu1mf8?filename=pug.png";

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("BasicNFT", block.chainid);
        mintNftOnContract(mostRecentlyDeployed);
    }

    function mintNftOnContract(address basicNFTAddress) public {
        vm.startBroadcast();
        BasicNFT(basicNFTAddress).mintNFT(PUG_URI);
        vm.stopBroadcast();
    }
}