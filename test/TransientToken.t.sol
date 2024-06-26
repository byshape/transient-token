// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC20Errors } from "openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol";

import { Test } from "forge-std/Test.sol";

import { ITemporaryApproval } from "contracts/ITemporaryApproval.sol";

import { TransientTokenMock } from "test/mocks/TransientTokenMock.sol";

contract TransientTokenTest is Test {
    address public alice;
    address public bob;
    address public transientToken;

    function setUp() public {
        (alice) = address(bytes20(keccak256(abi.encode("alice"))));
        vm.label(alice, "alice");
        bob = address(bytes20(keccak256(abi.encode("bob"))));
        vm.label(bob, "bob");

        transientToken = address(new TransientTokenMock("TransientToken", "TT", alice, 100 ether));
        vm.label(transientToken, "transientToken");
    }

    function test_ApproveTemporarily() public {
        assertEq(IERC20(transientToken).allowance(alice, address(this)), 0);
        assertEq(IERC20(transientToken).balanceOf(bob), 0);

        uint256 balanceAlice = IERC20(transientToken).balanceOf(alice);

        uint256 amountToApprove = 10 ether;
        uint256 amountToSpend = 5 ether;

        vm.prank(alice);
        ITemporaryApproval(transientToken).temporaryApprove(address(this), amountToApprove);
        IERC20(transientToken).transferFrom(alice, bob, amountToSpend);

        assertEq(IERC20(transientToken).allowance(alice, address(this)), amountToApprove - amountToSpend);
        assertEq(IERC20(transientToken).balanceOf(alice), balanceAlice - amountToSpend);
        assertEq(IERC20(transientToken).balanceOf(bob), amountToSpend);
    }

    function test_SpendPermanentAllowances() public {
        assertEq(IERC20(transientToken).allowance(alice, address(this)), 0);
        assertEq(IERC20(transientToken).balanceOf(bob), 0);

        uint256 balanceAlice = IERC20(transientToken).balanceOf(alice);

        uint256 amountToApprove = 10 ether;
        uint256 amountToSpend = 5 ether;

        vm.prank(alice);
        IERC20(transientToken).approve(address(this), amountToApprove);

        assertEq(IERC20(transientToken).allowance(alice, address(this)), amountToApprove);
        IERC20(transientToken).transferFrom(alice, bob, amountToSpend);

        assertEq(IERC20(transientToken).allowance(alice, address(this)), amountToApprove - amountToSpend);
        assertEq(IERC20(transientToken).balanceOf(alice), balanceAlice - amountToSpend);
        assertEq(IERC20(transientToken).balanceOf(bob), amountToSpend);
    }

    function test_SpendBothAllowances() public {
        assertEq(IERC20(transientToken).allowance(alice, address(this)), 0);
        assertEq(IERC20(transientToken).balanceOf(bob), 0);

        uint256 balanceAlice = IERC20(transientToken).balanceOf(alice);

        uint256 amountToApprove = 10 ether;
        uint256 amountToApproveTemporarily = 5 ether;
        uint256 amountToSpend = 15 ether;

        vm.startPrank(alice);
        IERC20(transientToken).approve(address(this), amountToApprove);
        ITemporaryApproval(transientToken).temporaryApprove(address(this), amountToApproveTemporarily);
        vm.stopPrank();

        assertEq(IERC20(transientToken).allowance(alice, address(this)), amountToApprove + amountToApproveTemporarily);
        IERC20(transientToken).transferFrom(alice, bob, amountToSpend);

        assertEq(IERC20(transientToken).allowance(alice, address(this)), amountToApprove + amountToApproveTemporarily - amountToSpend);
        assertEq(IERC20(transientToken).balanceOf(alice), balanceAlice - amountToSpend);
        assertEq(IERC20(transientToken).balanceOf(bob), amountToSpend);
    }

    function test_DoesNotSpendMoreThanAllowed() public {
        assertEq(IERC20(transientToken).allowance(alice, address(this)), 0);
        assertEq(IERC20(transientToken).balanceOf(bob), 0);

        uint256 balanceAlice = IERC20(transientToken).balanceOf(alice);

        uint256 amountToApprove = 10 ether;
        uint256 amountToApproveTemporarily = 5 ether;
        uint256 amountToSpend = 25 ether;

        vm.startPrank(alice);
        IERC20(transientToken).approve(address(this), amountToApprove);
        ITemporaryApproval(transientToken).temporaryApprove(address(this), amountToApproveTemporarily);
        vm.stopPrank();

        assertEq(IERC20(transientToken).allowance(alice, address(this)), amountToApprove + amountToApproveTemporarily);
        vm.expectRevert(
            abi.encodePacked(
                IERC20Errors.ERC20InsufficientAllowance.selector,
                abi.encode(address(this), amountToApprove, amountToSpend - amountToApproveTemporarily)
            )
        );
        IERC20(transientToken).transferFrom(alice, bob, amountToSpend);

        assertEq(IERC20(transientToken).allowance(alice, address(this)), amountToApprove + amountToApproveTemporarily);
        assertEq(IERC20(transientToken).balanceOf(alice), balanceAlice);
        assertEq(IERC20(transientToken).balanceOf(bob), 0);
    }

    function testDoenNotApproveFromZero() public {
        vm.expectRevert(abi.encodePacked(IERC20Errors.ERC20InvalidApprover.selector, abi.encode(address(0))));
        vm.prank(address(0));
        ITemporaryApproval(transientToken).temporaryApprove(address(0), 10 ether);
    }

    function testDoenNotApproveToZero() public {
        vm.expectRevert(abi.encodePacked(IERC20Errors.ERC20InvalidSpender.selector, abi.encode(address(0))));
        ITemporaryApproval(transientToken).temporaryApprove(address(0), 10 ether);
    }
}
