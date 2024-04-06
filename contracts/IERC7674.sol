// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IERC7674 {
    /**
     * @dev Sets a `value` amount of tokens as the temporary allowance of `spender` over the
     * caller's tokens within a single transaction.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     */
    function temporaryApprove(address spender, uint256 value) external returns (bool);
}
