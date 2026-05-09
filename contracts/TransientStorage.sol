// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// EIP-1153 transient storage - tstore/tload, available since Cancun (March 2024)
/// Transient storage is cleared at the end of each transaction - no cleanup cost.
contract TransientReentrancyGuard {
    // Slot for the transient lock flag
    uint256 private constant LOCK_SLOT = uint256(keccak256("reentrancy.lock")) - 1;

    error Reentrancy();

    modifier nonReentrant() {
        uint256 slot = LOCK_SLOT;
        assembly {
            if tload(slot) { revert(0, 0) }
            tstore(slot, 1)
        }
        _;
        assembly {
            tstore(slot, 0)
        }
    }

    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external nonReentrant {
        require(balances[msg.sender] >= amount, "Insufficient");
        balances[msg.sender] -= amount;
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "Transfer failed");
    }
}

// Classic comparison: the old storage-based guard costs 2 SSTOREs (20k + 2.9k gas)
// The transient version costs 2 TSTOREs (~100 gas each) - ~100x cheaper for the lock
