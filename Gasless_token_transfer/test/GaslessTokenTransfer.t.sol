// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployMockToken} from "script/DeployMockToken.s.sol";
import {DeployGaslessTokenTransfer} from "script/DeployGaslessTokenTranfer.s.sol";
import {GaslessTokenTransfer} from "src/GaslessTokenTransfer.sol";
import {MockToken} from "./mocks/MockToken.sol";
import {IERC20Permit} from "src/interfaces/IERC20Permit.sol";

contract GaslessTokenTransferTest is Test {
    GaslessTokenTransfer gaslessTokenTransfer;
    MockToken mockToken;

    // USERS PKS
    uint256 constant SENDER_PRIVATE_KEY = 123;
    uint256 constant RECIEVER_PRIVATE_KEY = 1234;

    // USERS
    address SENDER;
    address RECEIVER;

    // FEES
    uint256 constant AMOUNT = 1000;
    uint256 constant FEE = 10;

    function setUp() external {
        SENDER = vm.addr(SENDER_PRIVATE_KEY);
        RECEIVER = vm.addr(RECIEVER_PRIVATE_KEY);

        DeployMockToken deployMockToken = new DeployMockToken();
        DeployGaslessTokenTransfer deployGaslessTokenTransfer = new DeployGaslessTokenTransfer();

        gaslessTokenTransfer = deployGaslessTokenTransfer.run();
        mockToken = deployMockToken.run();

        //Mint token to the SENDER
        mockToken.mint(SENDER, AMOUNT + FEE);
    }

    function testGaslessTokenTransferContractIsValid() public view {
        assert(address(gaslessTokenTransfer) != address(0));
    }

    function testMockTokenContractIsValid() public view {
        assert(address(mockToken) != address(0));
    }
    /*//////////////////////////////////////////////////////////////
                         GASLESS TOKEN TRANSFER
    //////////////////////////////////////////////////////////////*/

    /**
     * keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
     */

    function _getPermitHash(address owner, address spender, uint256 value, uint256 nonce, uint256 deadline) private view returns(bytes32) {
        bytes32 permitHash = keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        mockToken.DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonce,
                                deadline
                            )
                        )
                    )
                );
            return permitHash;
    }

    function testValidSignature() public view {
        //Arrange
        uint256 deadline = block.timestamp + 60;

        bytes32 permitHash = _getPermitHash(
            SENDER,
            address(gaslessTokenTransfer),
            AMOUNT + FEE,
            mockToken.nonces(SENDER),
            deadline
        );

        //Act / Assert
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SENDER_PRIVATE_KEY, permitHash);
        assertEq(SENDER, ecrecover(permitHash, v, r, s));
    }

    function testTransactionSendsOnValidSignature() public {
         //Arrange
        uint256 deadline = block.timestamp + 60;

        bytes32 permitHash = _getPermitHash(
            SENDER,
            address(gaslessTokenTransfer),
            AMOUNT + FEE,
            mockToken.nonces(SENDER),
            deadline
        );

        //Act 
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SENDER_PRIVATE_KEY, permitHash);
        gaslessTokenTransfer.send(
            address(mockToken),
            SENDER,
            RECEIVER,
            AMOUNT,
            FEE,
            deadline,
            v,
            r,
            s
        );
        
        //Assert
        assertEq(mockToken.balanceOf(SENDER), 0, "Sender Balance");
        assertEq(mockToken.balanceOf(RECEIVER), AMOUNT, "Receiver Balance");
        assertEq(mockToken.balanceOf(address(this)), FEE, "Contract Fee");
    }

}