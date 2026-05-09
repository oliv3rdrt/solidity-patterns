# Solidity - Language Deep Dive

Personal exploration of the [Solidity language](https://docs.soliditylang.org) - going beyond tutorials into the language specification, ABI encoding, storage layout, and what's landing in upcoming versions.

## What I explored

- **Storage layout** - how state variables pack into 32-byte slots
- **Memory vs calldata vs storage** - gas implications of each
- **Custom errors** - `error InsufficientBalance(uint256 available, uint256 required)` vs `require` strings
- **Assembly / Yul** - inline assembly for gas-critical paths
- **Transient storage** (`tstore`/`tload`) - EIP-1153, available since Cancun
- **Function selectors** - computing and colliding selectors
- **ABI encoding** - `abi.encode` vs `abi.encodePacked` gotchas
- **Upcoming: Solidity 0.9.x** - tracking unreleased features in the changelog

## Contracts in this repo

| File | Topic |
|---|---|
| `StorageLayout.sol` | How struct packing and dynamic types work in storage |
| `GasOptimized.sol` | Custom errors, calldata over memory, packed structs |
| `TransientStorage.sol` | EIP-1153 tstore/tload for reentrancy guards |
| `FunctionSelector.sol` | Selector computation and proxy dispatch |

## Key takeaways

- Custom errors are ~50% cheaper than `require("string")` for frequent reverts
- `calldata` instead of `memory` for read-only array params is a consistent gas win
- Transient storage (`tstore`) removes the storage write/clear cost of classic reentrancy guards
- Storage packing requires understanding slot boundaries - structs can straddle slots unexpectedly
