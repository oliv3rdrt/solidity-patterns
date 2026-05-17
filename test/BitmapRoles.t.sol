// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BitmapRoles} from "../contracts/BitmapRoles.sol";

contract BitmapRolesTest is Test {
    BitmapRoles public r;
    address admin;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    // Some readable role IDs for tests
    uint8 constant ROLE_MINTER = 0;
    uint8 constant ROLE_PAUSER = 1;
    uint8 constant ROLE_TREASURY = 2;
    uint8 constant ROLE_ORACLE = 255; // edge - highest bit

    function setUp() public {
        admin = address(this);
        r = new BitmapRoles();
    }

    function test_GrantAndCheck() public {
        r.grant(alice, ROLE_MINTER);
        assertTrue(r.hasRole(alice, ROLE_MINTER));
        assertFalse(r.hasRole(alice, ROLE_PAUSER));
    }

    function test_RevokeClearsBit() public {
        r.grant(alice, ROLE_MINTER);
        r.grant(alice, ROLE_PAUSER);
        r.revoke(alice, ROLE_MINTER);

        assertFalse(r.hasRole(alice, ROLE_MINTER));
        assertTrue(r.hasRole(alice, ROLE_PAUSER));
    }

    function test_HighestBitRole() public {
        r.grant(alice, ROLE_ORACLE);
        assertTrue(r.hasRole(alice, ROLE_ORACLE));
        // No bleed into adjacent bits
        assertFalse(r.hasRole(alice, 254));
        assertFalse(r.hasRole(alice, 0));
    }

    function test_HasAllRoles() public {
        r.grant(alice, ROLE_MINTER);
        r.grant(alice, ROLE_PAUSER);

        uint256 minterAndPauser = (1 << ROLE_MINTER) | (1 << ROLE_PAUSER);
        assertTrue(r.hasAllRoles(alice, minterAndPauser));

        uint256 allThree = minterAndPauser | (1 << ROLE_TREASURY);
        assertFalse(r.hasAllRoles(alice, allThree));
    }

    function test_HasAnyRole() public {
        r.grant(alice, ROLE_TREASURY);

        uint256 ops = (1 << ROLE_MINTER) | (1 << ROLE_TREASURY);
        assertTrue(r.hasAnyRole(alice, ops));

        uint256 unrelated = (1 << ROLE_PAUSER) | (1 << ROLE_ORACLE);
        assertFalse(r.hasAnyRole(alice, unrelated));
    }

    function test_Grant_OnlyAdmin() public {
        vm.expectRevert(BitmapRoles.NotAdmin.selector);
        vm.prank(bob);
        r.grant(alice, ROLE_MINTER);
    }

    function test_Revoke_OnlyAdmin() public {
        r.grant(alice, ROLE_MINTER);
        vm.expectRevert(BitmapRoles.NotAdmin.selector);
        vm.prank(bob);
        r.revoke(alice, ROLE_MINTER);
    }

    function testFuzz_GrantAndRevokeIsIdempotent(uint8 roleId) public {
        // Granting twice is a no-op; revoking twice is a no-op
        r.grant(alice, roleId);
        r.grant(alice, roleId);
        assertTrue(r.hasRole(alice, roleId));

        r.revoke(alice, roleId);
        r.revoke(alice, roleId);
        assertFalse(r.hasRole(alice, roleId));
    }

    function testFuzz_IndependenceAcrossUsers(uint8 roleId, address other) public {
        vm.assume(other != alice);
        r.grant(alice, roleId);
        assertTrue(r.hasRole(alice, roleId));
        assertFalse(r.hasRole(other, roleId));
    }
}
