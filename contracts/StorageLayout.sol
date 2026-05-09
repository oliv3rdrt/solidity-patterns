// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// Studying how Solidity packs state variables into 32-byte storage slots
contract StorageLayout {
    // Slot 0: addr (20 bytes) + active (1 byte) + value (uint96 = 12 bytes) — all fit in slot 0
    address public addr;   // 20 bytes
    bool public active;    // 1 byte
    uint96 public value;   // 12 bytes
    // Total: 33 bytes — DOES NOT fit. value spills to slot 1.

    // Slot 2: full uint256
    uint256 public largeValue;

    // Mappings always get their own slot (the slot stores nothing; entries are at keccak256(key, slot))
    mapping(address => uint256) public balances;

    // Dynamic arrays: slot stores length; elements at keccak256(slot) + index
    uint256[] public items;

    struct PackedUser {
        address wallet;  // 20 bytes
        uint96 balance;  // 12 bytes — fits in slot with wallet
        uint128 score;   // 16 bytes — new slot
        uint128 rank;    // 16 bytes — shares slot with score
    }

    PackedUser public user;

    function getSlot(uint256 slot) external view returns (bytes32 value_) {
        assembly {
            value_ := sload(slot)
        }
    }
}
