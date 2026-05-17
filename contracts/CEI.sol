// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// Two vaults that demonstrate the Checks-Effects-Interactions pattern
/// without any reentrancy guard. Same scenario, different ordering -
/// BadOrder is drainable, GoodOrder is not.

contract BadOrder {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    /// Interactions BEFORE Effects - classic reentrancy bug.
    /// `unchecked` is used to mimic pre-0.8 behavior - in 0.8+ the natural
    /// underflow on the second nested decrement would revert and *accidentally*
    /// save us, which would obscure the actual CEI lesson. The takeaway: CEI
    /// matters whenever you're doing unchecked math or non-subtraction state
    /// updates, not only on pre-0.8 contracts.
    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "insufficient");
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "transfer failed");
        unchecked {
            balances[msg.sender] -= amount; // too late
        }
    }
}

contract GoodOrder {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    /// Checks -> Effects -> Interactions
    function withdraw(uint256 amount) external {
        // Checks
        require(balances[msg.sender] >= amount, "insufficient");
        // Effects
        balances[msg.sender] -= amount;
        // Interactions
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "transfer failed");
    }
}
