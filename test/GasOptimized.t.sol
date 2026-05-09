// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GasOptimized} from "../contracts/GasOptimized.sol";

contract GasOptimizedTest is Test {
    GasOptimized public opt;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        opt = new GasOptimized();
        // Seed balances directly via storage slot — gas-free setup
        deal(address(opt), 0);
    }

    function _setBalance(address user, uint256 amount) internal {
        // Use Foundry's store cheatcode to seed mapping slot
        bytes32 slot = keccak256(abi.encode(user, uint256(1))); // balances mapping is slot 1
        vm.store(address(opt), slot, bytes32(amount));
    }

    function test_BatchTransfer() public {
        _setBalance(alice, 100 ether);

        address[] memory recipients = new address[](3);
        uint256[] memory amounts = new uint256[](3);
        recipients[0] = makeAddr("r1");
        recipients[1] = makeAddr("r2");
        recipients[2] = makeAddr("r3");
        amounts[0] = 10 ether;
        amounts[1] = 20 ether;
        amounts[2] = 30 ether;

        vm.prank(alice);
        opt.batchTransfer(recipients, amounts);

        assertEq(opt.balances(alice), 40 ether);
        assertEq(opt.balances(recipients[0]), 10 ether);
        assertEq(opt.balances(recipients[1]), 20 ether);
        assertEq(opt.balances(recipients[2]), 30 ether);
    }

    function test_BatchTransfer_RevertOnInsufficientBalance() public {
        _setBalance(alice, 5 ether);

        address[] memory recipients = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        recipients[0] = bob;
        amounts[0] = 10 ether;

        vm.expectRevert(
            abi.encodeWithSelector(GasOptimized.InsufficientBalance.selector, 5 ether, 10 ether)
        );
        vm.prank(alice);
        opt.batchTransfer(recipients, amounts);
    }

    function testFuzz_EfficientSumBalances(uint96 a, uint96 b) public {
        _setBalance(alice, a);
        _setBalance(bob, b);

        address[] memory users = new address[](2);
        users[0] = alice;
        users[1] = bob;

        uint256 sum = opt.efficientSumBalances(users);
        assertEq(sum, uint256(a) + uint256(b));
    }
}
