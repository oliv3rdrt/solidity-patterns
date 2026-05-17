// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MerkleAirdrop, MerkleProof} from "../contracts/MerkleAirdrop.sol";

contract MerkleAirdropTest is Test {
    MerkleAirdrop public airdrop;

    address alice = makeAddr("alice");
    address bob   = makeAddr("bob");
    address carol = makeAddr("carol");
    address dave  = makeAddr("dave");

    uint256 constant ALICE_AMT = 1 ether;
    uint256 constant BOB_AMT   = 2 ether;
    uint256 constant CAROL_AMT = 3 ether;
    uint256 constant DAVE_AMT  = 4 ether;

    bytes32 root;
    bytes32 leafA;
    bytes32 leafB;
    bytes32 leafC;
    bytes32 leafD;
    bytes32 node01;
    bytes32 node23;

    function setUp() public {
        leafA = keccak256(abi.encodePacked(alice, ALICE_AMT));
        leafB = keccak256(abi.encodePacked(bob,   BOB_AMT));
        leafC = keccak256(abi.encodePacked(carol, CAROL_AMT));
        leafD = keccak256(abi.encodePacked(dave,  DAVE_AMT));

        node01 = _hashPair(leafA, leafB);
        node23 = _hashPair(leafC, leafD);
        root   = _hashPair(node01, node23);

        airdrop = new MerkleAirdrop(root);
        vm.deal(address(airdrop), 10 ether);
    }

    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    function _proofForA() internal view returns (bytes32[] memory p) {
        p = new bytes32[](2);
        p[0] = leafB;
        p[1] = node23;
    }

    function _proofForC() internal view returns (bytes32[] memory p) {
        p = new bytes32[](2);
        p[0] = leafD;
        p[1] = node01;
    }

    function test_ValidClaim_Succeeds() public {
        airdrop.claim(alice, ALICE_AMT, _proofForA());
        assertEq(alice.balance, ALICE_AMT);
        assertTrue(airdrop.claimed(alice));
    }

    function test_DoubleClaim_Reverts() public {
        airdrop.claim(alice, ALICE_AMT, _proofForA());
        vm.expectRevert(MerkleAirdrop.AlreadyClaimed.selector);
        airdrop.claim(alice, ALICE_AMT, _proofForA());
    }

    function test_WrongAmount_Reverts() public {
        vm.expectRevert(MerkleAirdrop.InvalidProof.selector);
        airdrop.claim(alice, ALICE_AMT + 1, _proofForA());
    }

    function test_WrongAccount_Reverts() public {
        // Bob trying to use Alice's proof
        vm.expectRevert(MerkleAirdrop.InvalidProof.selector);
        airdrop.claim(bob, ALICE_AMT, _proofForA());
    }

    function test_TamperedProof_Reverts() public {
        bytes32[] memory p = _proofForA();
        p[1] = bytes32(uint256(p[1]) ^ 1); // flip one bit
        vm.expectRevert(MerkleAirdrop.InvalidProof.selector);
        airdrop.claim(alice, ALICE_AMT, p);
    }

    function test_MultipleClaimsByDifferentAccounts() public {
        airdrop.claim(alice, ALICE_AMT, _proofForA());
        airdrop.claim(carol, CAROL_AMT, _proofForC());
        assertEq(alice.balance, ALICE_AMT);
        assertEq(carol.balance, CAROL_AMT);
    }

    function test_Library_RejectsEmptyProofUnlessLeafIsRoot() public {
        bytes32[] memory empty = new bytes32[](0);
        // Empty proof verifies only when leaf == root - tested directly on the library
        assertTrue(MerkleProof.verify(empty, root, root));
        assertFalse(MerkleProof.verify(empty, root, leafA));
    }
}
