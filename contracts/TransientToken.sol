// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";

import { IERC7674 } from "contracts/IERC7674.sol";

/**
 * @title Token with temporary approvals
 * @notice Contract that implements temporary approvals for ERC20 tokens.
 */
contract TransientToken is ERC20, IERC7674 {
    bytes32 private constant _TEMPORARY_ALLOWANCES_SLOT = keccak256("_temporaryAllowances");

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    /**
     * @dev See {ITemporaryApproval-temporaryApprove}.
     * Temporary allowances are not persisted between transactions.
     *
     * NOTE: If `value` is the maximum `uint256`, the temporary allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     */
    function temporaryApprove(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();

        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }

        _setTemporaryAllowance(owner, spender, value);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     * Temporary allowances are added to the permanent allowances.
     * This value changes when {IERC20-approve}, {IERC7674-temporaryApprove} or {IERC20-transferFrom} are called.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        uint256 temporaryAllowance = _getTemporaryAllowance(owner, spender);
        if (temporaryAllowance == type(uint256).max) {
            return temporaryAllowance;
        }
        (bool success, uint256 amount) = Math.tryAdd(temporaryAllowance, super.allowance(owner, spender));
        return success ? amount : type(uint256).max;
    }

    /// @dev The permanent allowance can only be spent after the temporary allowance has been exhausted.
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual override {
        uint256 temporaryAllowance = _getTemporaryAllowance(owner, spender);
        if (temporaryAllowance != type(uint256).max) {
            uint256 available = Math.min(value, temporaryAllowance);
            _setTemporaryAllowance(owner, spender, temporaryAllowance - available);
            value -= available;
            if (value > 0) {
                super._spendAllowance(owner, spender, value);
            }
        }
    }

    function _setTemporaryAllowance(address owner, address spender, uint256 value) internal {
        bytes32 slot = _getTransientSlot(owner, spender);
        assembly {
            tstore(slot, value)
        }
    }

    function _getTemporaryAllowance(address owner, address spender) internal view returns (uint256 allowed) {
        bytes32 slot = _getTransientSlot(owner, spender);
        assembly {
            allowed := tload(slot)
        }
    }

    function _getTransientSlot(address owner, address spender) internal pure returns (bytes32) {
        return keccak256(abi.encode(spender, keccak256(abi.encode(owner, _TEMPORARY_ALLOWANCES_SLOT))));
    }
}
