// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";

import { ITransientApproval } from "contracts/ITransientApproval.sol";

/**
 * @title Token with transient approvals
 * @notice Contract that implements transient approvals for ERC20 tokens.
 */
contract TransientToken is ERC20, ITransientApproval {
    bytes32 private constant _TRANSIENT_ALLOWANCES_SLOT = keccak256("_transientAllowances");

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    /**
     * @dev See {ITransientApproval-approveTransiently}.
     * Transient allowances are not persisted between transactions.
     *
     * NOTE: If `value` is the maximum `uint256`, the transient allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     */
    function approveTransiently(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();

        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }

        _setTransientAllowance(owner, spender, value);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     * Transient allowances are added to the permanent allowances.
     * This value changes when {approve}, {approveTransiently} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        uint256 transientAllowance = _getTransientAllowance(owner, spender);
        if (transientAllowance == type(uint256).max) {
            return transientAllowance;
        }
        (bool success, uint256 allowed) = Math.tryAdd(transientAllowance, super.allowance(owner, spender));
        return success ? allowed : type(uint256).max;
    }

    /// @dev The permanent allowance can only be spent after the temporary allowance has been exhausted.
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual override {
        uint256 transientAllowance = _getTransientAllowance(owner, spender);
        if (transientAllowance != type(uint256).max) {
            uint256 available = value <= transientAllowance ? value : transientAllowance;
            _setTransientAllowance(owner, spender, transientAllowance - available);
            value -= available;
            if (value > 0) {
                super._spendAllowance(owner, spender, value);
            }
        }
    }

    function _setTransientAllowance(address owner, address spender, uint256 value) internal {
        bytes32 slot = _getTransientSlot(owner, spender);
        assembly {
            tstore(slot, value)
        }
    }

    function _getTransientAllowance(address owner, address spender) internal view returns (uint256 allowed) {
        bytes32 slot = _getTransientSlot(owner, spender);
        assembly {
            allowed := tload(slot)
        }
    }

    function _getTransientSlot(address owner, address spender) internal pure returns (bytes32) {
        return keccak256(abi.encode(spender, keccak256(abi.encode(owner, _TRANSIENT_ALLOWANCES_SLOT))));
    }
}
