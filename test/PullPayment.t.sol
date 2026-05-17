// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PullPayment, Splitter} from "../contracts/PullPayment.sol";

/// Refuses ETH - represents a "griefing" recipient that would break push-payouts.
contract RevertingReceiver {
    receive() external payable {
        revert("nope");
    }
}

contract PullPaymentTest is Test {
    Splitter public splitter;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        splitter = new Splitter();
    }

    function test_DistributeThenWithdraw() public {
        address[] memory recipients = new address[](2);
        recipients[0] = alice;
        recipients[1] = bob;

        splitter.distribute{value: 2 ether}(recipients);

        assertEq(splitter.pendingWithdrawals(alice), 1 ether);
        assertEq(splitter.pendingWithdrawals(bob), 1 ether);

        vm.prank(alice);
        splitter.withdrawPayments();
        assertEq(alice.balance, 1 ether);
        assertEq(splitter.pendingWithdrawals(alice), 0);
    }

    function test_FailureIsIsolatedPerRecipient() public {
        RevertingReceiver griefer = new RevertingReceiver();

        address[] memory recipients = new address[](3);
        recipients[0] = alice;
        recipients[1] = address(griefer);
        recipients[2] = bob;

        // Distribution succeeds even though griefer refuses ETH - only the
        // *claim* would fail, and griefer never claims.
        splitter.distribute{value: 3 ether}(recipients);

        vm.prank(alice);
        splitter.withdrawPayments();
        assertEq(alice.balance, 1 ether);

        vm.prank(bob);
        splitter.withdrawPayments();
        assertEq(bob.balance, 1 ether);

        // Griefer's share is just stranded - it doesn't block anyone else
        assertEq(splitter.pendingWithdrawals(address(griefer)), 1 ether);
        assertEq(address(griefer).balance, 0);
    }

    function test_GrieferCannotClaim() public {
        RevertingReceiver griefer = new RevertingReceiver();
        address[] memory r = new address[](1);
        r[0] = address(griefer);
        splitter.distribute{value: 1 ether}(r);

        vm.expectRevert(PullPayment.TransferFailed.selector);
        vm.prank(address(griefer));
        splitter.withdrawPayments();

        // Crucially, balance is still credited - revert reverted the zero-out
        // too. Recipient can switch wallets and try again if their contract
        // is upgraded, etc.
        assertEq(splitter.pendingWithdrawals(address(griefer)), 1 ether);
    }

    function test_Withdraw_RevertOnNothing() public {
        vm.expectRevert(PullPayment.NothingToWithdraw.selector);
        vm.prank(alice);
        splitter.withdrawPayments();
    }

    function test_DoubleWithdraw_SecondReverts() public {
        address[] memory r = new address[](1);
        r[0] = alice;
        splitter.distribute{value: 1 ether}(r);

        vm.prank(alice);
        splitter.withdrawPayments();

        vm.expectRevert(PullPayment.NothingToWithdraw.selector);
        vm.prank(alice);
        splitter.withdrawPayments();
    }
}
