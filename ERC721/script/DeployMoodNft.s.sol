// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import {MoodNFT} from "../src/MoodNFT.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";

contract DeployMoodNFT is Script {
    function run() external returns (MoodNFT) {
        string memory sadSVG = vm.readFile('./img/sad.svg');
        string memory happySVG = vm.readFile("./img/happy.svg");
        
        vm.startBroadcast();
        MoodNFT moodNFT = new MoodNFT(svgToImageURI(sadSVG), svgToImageURI(happySVG));
        vm.stopBroadcast();

        return moodNFT;
    }

    function svgToImageURI(string memory svg) public pure returns (string memory) {
        // takes in svg and returns data:image/svg+xml;base64
        string memory baseURL = "data:image/svg+xml;base64,";
        string memory svgBase64Encoded = Base64.encode(bytes(string(abi.encodePacked((svg)))));
        return string(abi.encodePacked(baseURL, svgBase64Encoded));
    }
}