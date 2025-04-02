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

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

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
 * our DSC system should always be "overcollateralized". At no point, should the value of all collateral <= the $ backed value of all DSC
 * @notice This contract is the core of the DSC System. It handles all the logic for minting and redeeming DSC, as well as depositing and withdrawing collateral
 * @notice This contract is Very loosely based on the MakerDAO DSS (DAI) system
 */
contract DSCEngine is ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__TokenNotAllowed();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreakdHealthFactor();
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorOK();
    error DSCEngine__HealthFactorNotImproved();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_BONUS = 10;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    address[] private s_collateralTokens;

    DecentralizedStableCoin private immutable i_dsc;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    );

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__TokenNotAllowed();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddress, address dscAddress) {
        // USD Price Feeds
        if (tokenAddresses.length != priceFeedAddress.length) {
            revert DSCEngine__TokenAddressAndPriceFeedAddressesMustBeSameLength();
        }

        // For Example Price Feeds wil be  ETH/USD, BTC/USD, MKR/USD etc
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddress[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @param tokenCollateralAddress The address of the collateral token being used in the DSC Engine.
     * @param amountCollateral The amount of collateral to deposit into the DSC Engine.
     * @param amountDSCToMint The amount of DSC to mint
     * @notice this function will deposit your collateral and mint DSC in one go
     */
    function depositCollateralAndMintDSC(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDSCToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDSC(amountDSCToMint);
    }

    /**
     * @notice follows CEI (checks Effect Interaction)
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /**
     *
     * @param tokenCollateralAddress The address of the collateral token to redeem.
     * @param amountCollateral The mount of the collateral to get back
     * @param amountDSCToBurn The amount of DSC to burn
     * @notice this functions burns DSC and redeems the collateral
     */
    function redeemCollateralForDSC(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDSCToBurn)
        external
    {
        burnDSC(amountDSCToBurn);
        // Redeem collateral already checks the health factor
        redeemCollateral(tokenCollateralAddress, amountCollateral);
    }

    // In order to redeem collateral:
    // 1. health factor must be over 1 AFTER collateral pulled
    // CEI - Checks Effect Interactions

    /**
     *
     * /**
     * @notice Redeems collateral for a user, ensuring the health factor is maintained.
     * @param tokenCollateralAddress The address of the collateral token to redeem.
     * @param amountCollateral The amount of collateral to redeem.
     */
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    // 1. Check if the collateral value > DSC amount. Price feeds, Values etc
    /**
     * @notice follows CEI
     * @param amountDSCToMint The amount of decentralized stable coin to mint
     * @notice they must have collateral value than the minimum threshold
     */
    function mintDSC(uint256 amountDSCToMint) public moreThanZero(amountDSCToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDSCToMint;
        // if they minted too much ($150 DSC, $100 ETH)
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDSCToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    function burnDSC(uint256 amountDSC) public moreThanZero(amountDSC) {
        _burnDSC(amountDSC, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    // Paying others to remove other peoples positions
    /**
     * @param collateral The erc20 collateral address to liquidate from the user
     * @param user The user who has broken the health factor.
     * @param debtToCover The amount of the DSC you want to burn to imporve the user Healths Factor
     * @notice you can partially liquidate a position
     * @notice you will get a liquidation bonus for taking the users funds
     * @notice This function working assimes the protocol assumes protocol will the 200% overcollateralized in order for this to work
     * @notice A known bug will be if the protocol were 100% or less collateralized, then we wouldn't be able to incentive the liquidators
     * For Example, if the price of the collateral plummetn before anyone could be liquidated
     */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        // Check the health Factor
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOK();
        }

        // burn the DSC debt and take the collateral
        // Bad User: $140 ETH, $100 DSC
        // DebtToCOver = $100
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        // give a 10% bonus
        // ie liquidator gets $110
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
        _redeemCollateral(collateral, totalCollateralToRedeem, user, msg.sender);
        _burnDSC(debtToCover, user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getHealthFactor() external view {}

    /*//////////////////////////////////////////////////////////////
                PRIVATE AND INTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @param tokenCollateralAddress The address of the collateral token to redeem.
     * @param amountCollateral The mount of the collateral to get back
     * @param from The address to be liquidated from
     * @param to The address to be liquidated to
     */
    function _redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral, address from, address to)
        private
    {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);

        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /**
     * @dev Low-Level internal function, do not call unless the function calling it is checking
     * for health Factors being broken
     */
    function _burnDSC(uint256 amountDSCToBurn, address onBehalfOf, address dscFrom) private {
        s_DSCMinted[onBehalfOf] -= amountDSCToBurn;
        bool success = i_dsc.transferFrom(dscFrom, address(this), amountDSCToBurn);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountDSCToBurn);
    }

    /**
     * @param user Address of the User
     * @return totalDSCMinted The total dsc minted for the user
     * @return collateralValueInUsd The total collateral value in USD
     */
    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDSCMinted, uint256 collateralValueInUsd)
    {
        totalDSCMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    /**
     * @param user The address of the user
     * Returns how close to liquidation a user is.
     * if the user goes below 1, they can get liquidated
     */
    function _healthFactor(address user) private view returns (uint256) {
        // Total DSC minted
        // Total collateral value
        (uint256 totalDSCMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDSCMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        // 1. Check Health Factor (collateral value / DSC value) (do they have enough collateral?)
        // 2. Revert if they dont
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreakdHealthFactor();
        }
    }

    /*//////////////////////////////////////////////////////////////
                     PUBLIC EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // (10e18 * 1e18) / (2000e8 * 1e10)
        return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        // loop through each collateral token, get the amount they have deposited, and map it to
        // the price, to get the USD value
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            // Get the price with price feeds
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }

        return totalCollateralValueInUsd;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // if 1 ETH = $1000
        // The returned value from CL will be 1000 * 1e8
        return (uint256(price) * ADDITIONAL_FEED_PRECISION * amount) / PRECISION; //(1000 * 1e8 * 1e10)
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalDSCMinted, uint256 collateralValueInUsd)
    {
        (totalDSCMinted, collateralValueInUsd) = _getAccountInformation(user);
    }
}
