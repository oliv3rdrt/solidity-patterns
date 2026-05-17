// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// Pack up to 256 boolean role flags per user into a single uint256.
/// vs. mapping(address => mapping(uint256 => bool)): one SLOAD/SSTORE per
/// permission check, vs. one for the entire set. Cuts gas on multi-role
/// systems significantly.
contract BitmapRoles {
    mapping(address => uint256) public roles;
    address public admin;

    event RoleGranted(address indexed account, uint8 indexed roleId);
    event RoleRevoked(address indexed account, uint8 indexed roleId);

    error NotAdmin();
    error MissingRole(uint8 roleId);

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    modifier onlyRole(uint8 roleId) {
        if (!hasRole(msg.sender, roleId)) revert MissingRole(roleId);
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function grant(address account, uint8 roleId) external onlyAdmin {
        // (1 << roleId) is the bit mask for that role; OR sets it.
        roles[account] |= (uint256(1) << roleId);
        emit RoleGranted(account, roleId);
    }

    function revoke(address account, uint8 roleId) external onlyAdmin {
        // AND with the complement of the bit mask clears it.
        roles[account] &= ~(uint256(1) << roleId);
        emit RoleRevoked(account, roleId);
    }

    function hasRole(address account, uint8 roleId) public view returns (bool) {
        return (roles[account] >> roleId) & 1 == 1;
    }

    /// Check that an account has ALL bits in `mask` set in a single SLOAD.
    function hasAllRoles(address account, uint256 mask) external view returns (bool) {
        return (roles[account] & mask) == mask;
    }

    /// Check that an account has at least one of the bits in `mask`.
    function hasAnyRole(address account, uint256 mask) external view returns (bool) {
        return (roles[account] & mask) != 0;
    }
}
