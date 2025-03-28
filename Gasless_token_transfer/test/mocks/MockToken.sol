// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract MockToken is ERC20 {
    uint256 constant INITIAL_SUPPLY = 1000 * 10 ** 18;
    uint8 constant DECIMALS = 18;

    constructor() ERC20("MockToken", "MTK", DECIMALS){
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    function mint(address to, uint256 value) public {
        _mint(to, value);
    }

    function burn(address from, uint256 value) public {
        _burn(from, value);
    }
}