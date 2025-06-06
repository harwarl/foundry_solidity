// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20Permit} from "./interfaces/IERC20Permit.sol";

contract GaslessTokenTransfer  {
    function send(
        address token,
        address sender,
        address receiver,
        uint256 amount,
        uint256 fee,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        //Permit - sender approves this contract to spend amount + fee
        IERC20Permit(token).permit(
            sender, address(this), amount + fee, deadline, v, r, s
        );
        // Send amount to receiver
        IERC20Permit(token).transferFrom(sender, receiver, amount);
        // Send the fee to the msg.sender
        IERC20Permit(token).transferFrom(sender, msg.sender, fee);
    }
}