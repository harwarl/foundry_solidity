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
 * @title DSCEngine
 * @author Oduwale Awwal
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg.
 * This stable coin has the properties
 * - Exogenous Collateral
 * - Dollar Pegged
 * - Algorithmically stable
 * 
 * It is similar to DAI if DAI had no governance , no fees, and wa only backed by WETH and WBTC
 * 
 * our DSC system should always be "overcollateralized". At no point, should the value of all collateral <= the value of all DSC
 * @notice This contract is the core of the DSC System. It handles all the logic for minting and redeeming DSC, as well as depositing and withdrawing collateral
 * @notice This contract is Very loosely based on the MakerDAO DSS (DAI) system
 */
contract DSCEngine {
    function depositCollateralAndMintDSC() external {}
    function redeemCollateralForDSC() external {}
    function burnDSC() external {}
}