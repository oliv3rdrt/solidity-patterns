// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// Self-delegatecall multicall. The caller batches calls to *this* contract's
/// own functions in a single tx. Cheaper than N separate txs (one signature,
/// one base-fee, one calldata header), and atomic - any failure rolls back all.
///
/// Used as a base by Uniswap V3 PositionManager, Yearn V3, and a long list of
/// DeFi protocols. Not to be confused with the read-only "Multicall3" aggregator
/// at multicall3.eth which is a separate contract that batches *other* contracts'
/// view calls.
abstract contract Multicall {
    error CallFailed(uint256 index, bytes returndata);

    function multicall(bytes[] calldata data) external returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i; i < data.length; ) {
            (bool ok, bytes memory ret) = address(this).delegatecall(data[i]);
            if (!ok) revert CallFailed(i, ret);
            results[i] = ret;
            unchecked { ++i; }
        }
    }
}

/// Concrete example: a tiny counter that mixes Multicall in.
contract MulticallCounter is Multicall {
    uint256 public value;

    function increment() external returns (uint256) {
        value += 1;
        return value;
    }

    function add(uint256 x) external returns (uint256) {
        value += x;
        return value;
    }

    function reset() external {
        value = 0;
    }
}
