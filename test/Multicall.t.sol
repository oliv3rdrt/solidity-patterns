// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Multicall, MulticallCounter} from "../contracts/Multicall.sol";

contract MulticallTest is Test {
    MulticallCounter public c;

    function setUp() public {
        c = new MulticallCounter();
    }

    function test_BatchOfCalls_AppliesAll() public {
        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(MulticallCounter.increment.selector);
        calls[1] = abi.encodeWithSelector(MulticallCounter.add.selector, uint256(5));
        calls[2] = abi.encodeWithSelector(MulticallCounter.increment.selector);

        bytes[] memory results = c.multicall(calls);

        assertEq(c.value(), 7);
        assertEq(abi.decode(results[0], (uint256)), 1);
        assertEq(abi.decode(results[1], (uint256)), 6);
        assertEq(abi.decode(results[2], (uint256)), 7);
    }

    function test_Empty_Succeeds() public {
        bytes[] memory calls = new bytes[](0);
        bytes[] memory results = c.multicall(calls);
        assertEq(results.length, 0);
        assertEq(c.value(), 0);
    }

    function test_FailedCall_RollsBackEverything() public {
        // Seed the counter
        c.add(10);
        assertEq(c.value(), 10);

        // Middle call references an unknown selector - should revert the batch
        bytes[] memory calls = new bytes[](3);
        calls[0] = abi.encodeWithSelector(MulticallCounter.increment.selector);
        calls[1] = abi.encodeWithSelector(bytes4(0xdeadbeef));
        calls[2] = abi.encodeWithSelector(MulticallCounter.increment.selector);

        vm.expectRevert();
        c.multicall(calls);

        // Nothing should have moved
        assertEq(c.value(), 10);
    }

    function test_DelegatecallContextIsCorrect() public {
        // delegatecall keeps msg.sender as the original caller, and operates on
        // *this* contract's storage. Verify by reading the storage value after.
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSelector(MulticallCounter.add.selector, uint256(100));
        calls[1] = abi.encodeWithSelector(MulticallCounter.reset.selector);

        address sender = makeAddr("sender");
        vm.prank(sender);
        c.multicall(calls);

        // reset wiped the storage AND it was c's storage (not some intermediate)
        assertEq(c.value(), 0);
    }

    function testFuzz_BatchSize(uint8 n) public {
        n = uint8(bound(n, 0, 20));
        bytes[] memory calls = new bytes[](n);
        for (uint256 i; i < n; ++i) {
            calls[i] = abi.encodeWithSelector(MulticallCounter.increment.selector);
        }
        c.multicall(calls);
        assertEq(c.value(), n);
    }
}
