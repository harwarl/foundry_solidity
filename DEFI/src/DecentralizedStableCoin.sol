// SPDX-License-Identifier: MIT
// Layout of contract:
// version
// imports 
// errors 
// interfaces, libraries, contracts
// type declarations
// State variables
// Events
// Modifiers
// Functions 

// Layout of Functions:
// constructor 
// receive function(if exists)
// fallback function if exists 
// external
// public 
// internal
// private
// view and pure functions 
pragma solidity ^0.8.19;

/**
 * @title Decentralized Stable Coin
 * @author Oduwale Awwal
 * Collateral: Exogenous (ETH & BTC)
 * Minting: Algorithmic
 * Relative Stability: Pegged to USD
 * 
 * This is the contract meant to be governed by DSCEngine. This contract is just the ERC20 Implementation of our stablecoin system
 */
contract DecentralizedStableCoin {
    constructor(){
        
    }
}