// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// Pull-over-push: instead of *sending* ETH to recipients (push), credit them
/// and let them claim (pull). The push model breaks if any recipient is a
/// contract that reverts, runs out of gas in receive(), or simply can't accept
/// ETH - one griefer can DoS the entire payout. Pull model isolates failures
/// per recipient.

abstract contract PullPayment {
    mapping(address => uint256) public pendingWithdrawals;

    event Credited(address indexed payee, uint256 amount);
    event Withdrawn(address indexed payee, uint256 amount);

    error NothingToWithdraw();
    error TransferFailed();

    /// Internal: credit a payee. Call this from your push-style logic.
    function _asyncTransfer(address payee, uint256 amount) internal {
        pendingWithdrawals[payee] += amount;
        emit Credited(payee, amount);
    }

    /// Public: payee pulls their balance. Isolated - one bad payee can't
    /// block others.
    function withdrawPayments() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        if (amount == 0) revert NothingToWithdraw();
        // Effects before interactions (CEI)
        pendingWithdrawals[msg.sender] = 0;
        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit Withdrawn(msg.sender, amount);
    }
}

/// Concrete example: a tiny lottery-style splitter that demonstrates the
/// failure-isolation property.
contract Splitter is PullPayment {
    /// Credits each recipient an equal share of msg.value. Any dust stays in
    /// the contract (claimable by the first caller via a future deposit, or
    /// just left as fee revenue).
    function distribute(address[] calldata recipients) external payable {
        require(recipients.length > 0, "no recipients");
        uint256 share = msg.value / recipients.length;
        for (uint256 i; i < recipients.length; ) {
            _asyncTransfer(recipients[i], share);
            unchecked { ++i; }
        }
    }

    receive() external payable {}
}
