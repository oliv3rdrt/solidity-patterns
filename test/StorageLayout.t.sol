// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StorageLayout} from "../contracts/StorageLayout.sol";

/// Locks the storage layout assumptions documented in StorageLayout.sol so
/// any future change that breaks packing fails loudly.
contract StorageLayoutTest is Test {
    StorageLayout public sl;

    function setUp() public {
        sl = new StorageLayout();
    }

    function test_Slot0_PacksAddrAndActive() public {
        // Slot 0: addr at offset 0 (20 bytes) + active at offset 20 (1 byte).
        // value (uint96 = 12 bytes) doesn't fit in the remaining 11 bytes - spills to slot 1.
        address addr = address(0x1111111111111111111111111111111111111111);
        bytes32 packed = bytes32((uint256(1) << (20 * 8)) | uint256(uint160(addr)));
        vm.store(address(sl), bytes32(uint256(0)), packed);

        assertEq(sl.addr(), addr);
        assertTrue(sl.active());
    }

    function test_Slot1_HoldsValueAlone() public {
        uint96 v = type(uint96).max;
        vm.store(address(sl), bytes32(uint256(1)), bytes32(uint256(v)));
        assertEq(sl.value(), v);
    }

    function test_Slot2_HoldsLargeValue() public {
        uint256 large = type(uint256).max;
        vm.store(address(sl), bytes32(uint256(2)), bytes32(large));
        assertEq(sl.largeValue(), large);
    }

    function test_MappingSlot_BalancesAtSlot3() public {
        // mapping(address => uint256) balances - entry at keccak256(abi.encode(key, 3))
        address user = makeAddr("user");
        uint256 amount = 42 ether;
        bytes32 slot = keccak256(abi.encode(user, uint256(3)));
        vm.store(address(sl), slot, bytes32(amount));
        assertEq(sl.balances(user), amount);
    }

    function test_DynamicArraySlot_ItemsAtSlot4() public {
        // length at slot 4; element i at keccak256(abi.encode(slot)) + i
        uint256 arrSlot = 4;
        vm.store(address(sl), bytes32(arrSlot), bytes32(uint256(3)));
        bytes32 base = keccak256(abi.encode(arrSlot));
        vm.store(address(sl), bytes32(uint256(base) + 0), bytes32(uint256(11)));
        vm.store(address(sl), bytes32(uint256(base) + 1), bytes32(uint256(22)));
        vm.store(address(sl), bytes32(uint256(base) + 2), bytes32(uint256(33)));

        assertEq(sl.items(0), 11);
        assertEq(sl.items(1), 22);
        assertEq(sl.items(2), 33);
    }

    function test_PackedUserStruct_LayoutAcrossSlots5and6() public {
        // Slot 5: wallet (offset 0, 20) + balance (offset 20, 12)
        // Slot 6: score (offset 0, 16) + rank (offset 16, 16)
        address wallet = address(0x2222222222222222222222222222222222222222);
        uint96  balance = 1_000;
        uint128 score   = 5_000;
        uint128 rank    = 7;

        bytes32 slot5 = bytes32((uint256(balance) << (20 * 8)) | uint256(uint160(wallet)));
        bytes32 slot6 = bytes32((uint256(rank) << (16 * 8)) | uint256(score));
        vm.store(address(sl), bytes32(uint256(5)), slot5);
        vm.store(address(sl), bytes32(uint256(6)), slot6);

        (address w, uint96 b, uint128 s, uint128 r) = sl.user();
        assertEq(w, wallet);
        assertEq(b, balance);
        assertEq(s, score);
        assertEq(r, rank);
    }

    function test_GetSlot_ReadsRawStorage() public {
        bytes32 expected = bytes32(uint256(0xDEADBEEF));
        vm.store(address(sl), bytes32(uint256(2)), expected);
        assertEq(sl.getSlot(2), expected);
    }

    function testFuzz_Slot0_AddrAndActive(address addr, bool active) public {
        bytes32 packed = bytes32(
            (uint256(active ? 1 : 0) << (20 * 8)) | uint256(uint160(addr))
        );
        vm.store(address(sl), bytes32(uint256(0)), packed);
        assertEq(sl.addr(), addr);
        assertEq(sl.active(), active);
    }
}
