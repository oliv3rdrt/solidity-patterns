// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// Standard sorted-pair Merkle verification + an airdrop that uses it.
/// One on-chain root commits to N off-chain entries; each claimant pays
/// O(log N) verification gas instead of O(N) storage cost.
library MerkleProof {
    /// Verify `proof` connects `leaf` to `root`. Pair-sort matches the
    /// convention used by OpenZeppelin / merkletreejs (`sortPairs: true`).
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        bytes32 computed = leaf;
        for (uint256 i; i < proof.length; ) {
            bytes32 sibling = proof[i];
            computed = computed < sibling
                ? keccak256(abi.encodePacked(computed, sibling))
                : keccak256(abi.encodePacked(sibling, computed));
            unchecked { ++i; }
        }
        return computed == root;
    }
}

contract MerkleAirdrop {
    bytes32 public immutable merkleRoot;
    mapping(address => bool) public claimed;

    event Claimed(address indexed account, uint256 amount);

    error InvalidProof();
    error AlreadyClaimed();
    error TransferFailed();

    constructor(bytes32 root) {
        merkleRoot = root;
    }

    function claim(address account, uint256 amount, bytes32[] calldata proof) external {
        if (claimed[account]) revert AlreadyClaimed();

        // Leaf format: keccak256(abi.encodePacked(account, amount)). Whoever
        // builds the tree off-chain must use the same encoding.
        bytes32 leaf = keccak256(abi.encodePacked(account, amount));
        if (!MerkleProof.verify(proof, merkleRoot, leaf)) revert InvalidProof();

        claimed[account] = true;
        (bool ok,) = account.call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit Claimed(account, amount);
    }

    receive() external payable {}
}
