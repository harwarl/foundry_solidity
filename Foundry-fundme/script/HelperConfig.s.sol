// SPDX-License-Identifier: MIT

// Deploys mocks when not in a local anvil chain
// keep track of contract address across different chains
// Sepolia ETH/USD
// Mainnet ETH/USD

pragma solidity ^0.8.19;

import { Script} from 'forge-std/Script.sol';
import {MockV3Aggregator}  from '../test/mock/MockV3Aggregator.sol';

contract HelperConfig is Script {
    // If on local anvil, deploy mocks
    // otherwise grab the existing address from the live network

    NetWorkConfig public activeNetworkConfig;
    uint8 public constant DECIMALS =8;
    int256 public constant INITIAL_PRICE = 2000e8;

    struct NetWorkConfig {
        address priceFeed;
    }

    constructor(){
        if(block.chainid == 11155111){
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 1) {
            activeNetworkConfig = getMainnetEthConfig();
        }
        else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetWorkConfig memory) {
        // fetch feed address
        NetWorkConfig memory sepoliaConfig = NetWorkConfig({
            priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306
        });
        return sepoliaConfig;
    }

    function getMainnetEthConfig() public pure returns (NetWorkConfig memory) {
        // fetch feed address
        NetWorkConfig memory mainnetConfig = NetWorkConfig({
            priceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        });
        return mainnetConfig;
    }

    function getOrCreateAnvilEthConfig() public returns (NetWorkConfig memory){
        // fetch feed address
        // Deploy the mocks
        // Return the mock address

        if(activeNetworkConfig.priceFeed != address(0)){
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(DECIMALS, INITIAL_PRICE);
        vm.stopBroadcast();

        NetWorkConfig memory anvilConfig = NetWorkConfig({
            priceFeed: address(mockPriceFeed)
        });

        return anvilConfig;
    }
}