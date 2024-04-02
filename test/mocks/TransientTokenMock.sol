// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { TransientToken } from "contracts/TransientToken.sol";

contract TransientTokenMock is TransientToken {
    constructor(
        string memory name_,
        string memory symbol_,
        address initialOwner,
        uint256 initialSupply
    ) TransientToken(name_, symbol_) {
        _mint(initialOwner, initialSupply);
    }
}
