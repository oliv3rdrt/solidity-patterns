// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// Gas optimization techniques - custom errors, calldata, packed storage
contract GasOptimized {
    // Custom errors are cheaper to deploy and revert with than require strings
    error InsufficientBalance(uint256 available, uint256 required);
    error Unauthorized(address caller);
    error DeadlinePassed(uint256 deadline, uint256 current);

    struct PackedListing {
        address seller;   // 20 bytes
        uint96 price;     // 12 bytes  - shares slot 0 with seller
        uint64 expiry;    // 8 bytes   - slot 1
        uint64 tokenId;   // 8 bytes   - slot 1
        bool active;      // 1 byte    - slot 1
    }

    mapping(uint256 => PackedListing) public listings;
    mapping(address => uint256) public balances;

    // calldata instead of memory for read-only arrays saves a copy
    function batchTransfer(address[] calldata recipients, uint256[] calldata amounts) external {
        require(recipients.length == amounts.length, "Length mismatch");
        for (uint256 i; i < recipients.length; ) {
            uint256 bal = balances[msg.sender];
            if (bal < amounts[i]) revert InsufficientBalance(bal, amounts[i]);
            unchecked {
                balances[msg.sender] -= amounts[i];
                balances[recipients[i]] += amounts[i];
                ++i; // unchecked increment saves ~30 gas per iteration
            }
        }
    }

    // Cache storage reads in locals - SLOAD is 100 gas, MLOAD is 3 gas
    function efficientSumBalances(address[] calldata users) external view returns (uint256 total) {
        for (uint256 i; i < users.length; ) {
            total += balances[users[i]]; // one SLOAD per user
            unchecked { ++i; }
        }
    }
}
