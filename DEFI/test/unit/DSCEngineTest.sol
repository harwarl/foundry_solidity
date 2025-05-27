// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockFailedMintDSC} from "../mocks/MockFailedMintDSC.sol";
import {MockMoreDebtDSC} from "../mocks/MockMoreDebtDSC.sol";
import {MockFailedTransfer} from "../mocks/MockFailedTransfer.sol";
import {MockFakeTransferFrom} from "../mocks/MockFakeTransferFrom.sol";
import {MockFailedMintDSC} from "../mocks/MockFailedMintDSC.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dscEngine;
    HelperConfig config;
    address wethUsdPriceFeed;
    address wbtcUsdPriceFeed;
    address weth;
    address wbtc;

    address public USER = makeAddr("USER");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant AMOUNT_TO_BE_REDEEMED = 3 ether;
    uint256 public constant AMOUNT_DSC_TO_MINT = 5 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dscEngine, config) = deployer.run();
        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    // ------------------------------ Constructor Test ------------------------------
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    // ------------------------------ Event ------------------------------
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    );

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(wethUsdPriceFeed);
        priceFeedAddresses.push(wbtcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    // *------------------------------ Price Tests ------------------------------*
    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = dscEngine.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;
        uint256 expectecWeth = 0.05 ether;
        uint256 actualWeth = dscEngine.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectecWeth, actualWeth);
    }

    // ------------------------------ depositCollateralTests ------------------------------

    function testIfCollateralIsZero() public {
        vm.startPrank(USER);

        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.depositCollateral(weth, 0);

        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock();
        vm.startPrank(USER);

        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
        dscEngine.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralWithoutMintingDSC() public depositCollateral {
       uint256 userBalance = dsc.balanceOf(USER);
       assertEq(userBalance, 0, "User should not have any DSC minted yet");
    }

    modifier depositCollateralAndMintDSC() {
       vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, AMOUNT_DSC_TO_MINT);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositCollateral {
        (uint256 totalDSCMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(USER);
        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = dscEngine.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDSCMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    function testCanDepositCollateralAndMintDSC() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateralAndMintDSC(address(weth), AMOUNT_COLLATERAL, AMOUNT_DSC_TO_MINT);
        vm.stopPrank();

        (uint256 totalDSCMinted,) = dscEngine.getAccountInformation(USER);
        assertEq(totalDSCMinted, AMOUNT_DSC_TO_MINT);
    }

    function testRevertIfAmountCollaterizedIsZero() public {
        vm.prank(USER);
        vm.expectRevert();
        dscEngine.depositCollateralAndMintDSC(address(weth), AMOUNT_COLLATERAL, AMOUNT_DSC_TO_MINT);
    }

    // function testRevertsWithUnapprovedCollateral() public {
    //     ERC20Mock ranToken = new ERC20Mock();
    //     vm.startPrank(USER);
    //     vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__TokenNotAllowed.selector, address(ranToken)));
    //     dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
    //     vm.stopPrank();
    // }

    function testEmitsCollateralDepositedWhenDepositingCollateral() public {
        vm.startPrank(USER);

        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);

        vm.expectEmit(true, true, false, true, address(dscEngine));
        emit CollateralDeposited(USER, address(weth), AMOUNT_COLLATERAL);

        dscEngine.depositCollateralAndMintDSC(address(weth), AMOUNT_COLLATERAL, AMOUNT_DSC_TO_MINT);
        vm.stopPrank();
    }

    // ------------------------------ Redeem Collateral Tests ------------------------------

    // SUCCESS 
    function testEmitCollateralRedeemWhenCollateralIsRedeemed() public depositCollateralAndMintDSC {
        vm.startPrank(USER);
        
        vm.expectEmit(true, true, true, true, address(dscEngine));
        emit CollateralRedeemed(USER, USER, address(weth), AMOUNT_TO_BE_REDEEMED);

        dscEngine.redeemCollateral(address(weth), AMOUNT_TO_BE_REDEEMED);
        vm.stopPrank();
    }

    function testRedeemCollateralUpdatesBalances() public depositCollateralAndMintDSC() {
        uint256 initialEngineBalance = ERC20Mock(weth).balanceOf(address(dscEngine));
        uint256 initialUserBalance = ERC20Mock(weth).balanceOf(USER);

        vm.prank(USER);
        dscEngine.redeemCollateral(address(weth), AMOUNT_TO_BE_REDEEMED);

        uint256 finalEngineBalance = ERC20Mock(weth).balanceOf(address(dscEngine));

        uint256 finalUserBalance = ERC20Mock(weth).balanceOf(USER);
        assertEq(finalEngineBalance, initialEngineBalance - AMOUNT_TO_BE_REDEEMED);
        assertEq(finalUserBalance, initialUserBalance + AMOUNT_TO_BE_REDEEMED);
    }

    // REVERTs
    function testRevertRedeemCollateralWhenCollateralAmountIsZero() public depositCollateral {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.redeemCollateral(address(weth), 0);
        vm.stopPrank();
    }

    function testRevertRedeemCollateralWhenCollateralTokenIsNotRegistered() public {
        vm.startPrank(USER);
        ERC20Mock testToken = new ERC20Mock();
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
        dscEngine.redeemCollateral(address(testToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }


    function testRevertsIfHealthFactorBreaks() public depositCollateralAndMintDSC {
        uint256 excessiveRedeem = AMOUNT_COLLATERAL;
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__BreakdHealthFactor.selector);
        dscEngine.redeemCollateral(address(weth), excessiveRedeem);
        vm.stopPrank();
    }

    // ------------------------------ MintDSC test ------------------------------
    function  testRevertsIfMintFails() public {
        MockFailedMintDSC mockFailedMintDSC = new MockFailedMintDSC();
        tokenAddresses = [weth];
        priceFeedAddresses = [wethUsdPriceFeed];
        address owner = msg.sender;

        vm.prank(owner);
        DSCEngine mockDscEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(mockFailedMintDSC));

        mockFailedMintDSC.transferOwnership(address(mockDscEngine));
        vm.startPrank(USER);

        ERC20Mock(weth).approve(address(mockDscEngine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__MintFailed.selector);
        mockDscEngine.depositCollateralAndMintDSC(address(weth), AMOUNT_COLLATERAL, AMOUNT_DSC_TO_MINT);
        vm.stopPrank();
    }


    function testRevertsIfMintAmountIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.depositCollateralAndMintDSC(address(weth), AMOUNT_COLLATERAL, 0);
        vm.stopPrank();
    }

    function testCanMintDSC() public depositCollateral {
        vm.startPrank(USER);
        dscEngine.mintDSC(AMOUNT_DSC_TO_MINT);
        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, AMOUNT_DSC_TO_MINT);
    }


    // ------------------------------ BURN DSC tests ------------------------------
    function testRevertsIfBurnAmountIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateralAndMintDSC(address(weth), AMOUNT_COLLATERAL, AMOUNT_DSC_TO_MINT);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.burnDSC(0);
        vm.stopPrank();
    }

    function testCanBurnMoreThanUserHas() public {
        vm.prank(USER);
        vm.expectRevert();
        dscEngine.burnDSC( 1 ether); // User has 0 DSC, so this should revert
    }

    function testCanBurnDSC() public depositCollateralAndMintDSC {
        vm.startPrank(USER);
       
       dsc.approve(address(dscEngine), AMOUNT_DSC_TO_MINT);
       
       dscEngine.burnDSC(AMOUNT_DSC_TO_MINT);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, 0);
    }


    // ------------------------------ Redeem Collateral ------------------------------
    function testRevertsIfTransferFails() public {
        // Arrange - Setup
        address owner = msg.sender;
        vm.prank(owner);
        MockFailedTransfer mockDsc = new MockFailedTransfer();
        tokenAddresses = [address(mockDsc)];
        priceFeedAddresses = [wethUsdPriceFeed];
        vm.prank(owner);
        DSCEngine mockDsce = new DSCEngine(tokenAddresses, priceFeedAddresses, address(mockDsc));
        mockDsc.mint(USER, AMOUNT_COLLATERAL);


        vm.prank(owner);
        mockDsc.transferOwnership(address(mockDsce));

        // Arrange User
        vm.startPrank(USER);
        ERC20Mock(address(mockDsc)).approve(address(mockDsce), AMOUNT_COLLATERAL);

        // Act / Assert
        mockDsce.depositCollateral(address(mockDsc), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        mockDsce.redeemCollateral(address(mockDsc), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }


    function testRevertsifAmountIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateralAndMintDSC(address(weth), AMOUNT_COLLATERAL, AMOUNT_DSC_TO_MINT);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.redeemCollateral(address(weth), 0);
        vm.stopPrank();
    }

    function testRevertIfTokenIsNotAllowed() public {
        ERC20Mock ranToken = new ERC20Mock();
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateralAndMintDSC(address(weth), AMOUNT_COLLATERAL, AMOUNT_DSC_TO_MINT);
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
        dscEngine.redeemCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testCanRedeemCollateral() public depositCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        uint256 userBalanceBeforeRedeem = dscEngine.getCollateralBalanceOfUser(USER, address(weth));
        assertEq(userBalanceBeforeRedeem, AMOUNT_COLLATERAL);

        dscEngine.redeemCollateral(address(weth), AMOUNT_COLLATERAL);
        uint256 userBalanceAfterRedeem = dscEngine.getCollateralBalanceOfUser(USER, address(weth));

        assertEq(userBalanceAfterRedeem, 0);
        vm.stopPrank();
    }

    function testEmitCollateralRedeemedWithCorrectArgs() public depositCollateral() {
        vm.expectEmit(true, true, true, true, address(dscEngine));
        emit CollateralRedeemed(address(USER), address(USER), address(weth), AMOUNT_COLLATERAL);
        vm.startPrank(address(USER));
        dscEngine.redeemCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }


    // ------------------------------ Redeem collateral for DSC tests ------------------------------
    function testMustRedeemMoreThanZero() public depositCollateralAndMintDSC() {
        vm.startPrank(USER);
        dsc.approve(address(dscEngine), AMOUNT_DSC_TO_MINT);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.redeemCollateralForDSC(weth, 0, AMOUNT_DSC_TO_MINT);
        vm.stopPrank();
    }

    function testCanRedeemDepositedCollateral() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateralAndMintDSC(weth, AMOUNT_COLLATERAL, AMOUNT_DSC_TO_MINT);
        dsc.approve(address(dscEngine), AMOUNT_DSC_TO_MINT);
        dscEngine.redeemCollateralForDSC(weth, AMOUNT_COLLATERAL, AMOUNT_DSC_TO_MINT);
        vm.stopPrank();

        uint256 USERBalance = dsc.balanceOf(USER);
        assertEq(USERBalance, 0);
    }


    // ------------------------------ Health Factor tests ------------------------------
}
