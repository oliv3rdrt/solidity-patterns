// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {TransientReentrancyGuard} from "../contracts/TransientStorage.sol";

/// Malicious contract that tries to re-enter withdraw
contract ReentrancyAttacker {
    TransientReentrancyGuard public target;
    uint256 public attackCount;

    constructor(TransientReentrancyGuard _target) {
        target = _target;
    }

    function attack() external payable {
        target.deposit{value: msg.value}();
        target.withdraw(msg.value);
    }

    receive() external payable {
        attackCount++;
        if (address(target).balance >= 1 ether && attackCount < 3) {
            target.withdraw(1 ether); // attempt reentry
        }
    }
}

contract TransientStorageTest is Test {
    TransientReentrancyGuard public vault;
    address alice = makeAddr("alice");

    function setUp() public {
        vault = new TransientReentrancyGuard();
        vm.deal(alice, 10 ether);
    }

    function test_DepositAndWithdraw() public {
        vm.prank(alice);
        vault.deposit{value: 2 ether}();
        assertEq(vault.balances(alice), 2 ether);

        vm.prank(alice);
        vault.withdraw(1 ether);
        assertEq(vault.balances(alice), 1 ether);
        assertEq(alice.balance, 9 ether);
    }

    function test_ReentrancyBlocked() public {
        // Seed some ETH in the vault from alice
        vm.prank(alice);
        vault.deposit{value: 5 ether}();

        // Attacker tries to re-enter
        ReentrancyAttacker attacker = new ReentrancyAttacker(vault);
        vm.deal(address(attacker), 2 ether);

        // The reentry attempt should revert (the transient lock is still set)
        vm.expectRevert();
        attacker.attack{value: 1 ether}();

        // Alice's funds should be untouched
        assertEq(vault.balances(alice), 5 ether);
    }
}
