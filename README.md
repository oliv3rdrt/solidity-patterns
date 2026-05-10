# solidity-patterns

Solidity patterns explored with Foundry tests: storage layout, gas optimization, transient storage, and assembly tricks.

## Stack

- Solidity 0.8.24
- Foundry (forge, cast, anvil)
- EVM Cancun

## Prerequisites

| Tool | Install |
|------|---------|
| Foundry | `curl -L https://foundry.paradigm.xyz \| bash` then `foundryup` |
| Git | any |

## Quick start

```bash
forge install foundry-rs/forge-std --no-git
forge build
forge test -vv
```

Expected: 5 tests passing across two test files.

## What's in here

| Topic | Contract | Test |
|-------|----------|------|
| State variable packing into 32-byte slots | `contracts/StorageLayout.sol` | (notes only) |
| Custom errors, packed structs, `unchecked`, `calldata` | `contracts/GasOptimized.sol` | `test/GasOptimized.t.sol` |
| Transient storage reentrancy guard (EIP-1153) | `contracts/TransientStorage.sol` | `test/TransientStorage.t.sol` |

Plus `notes/language-notes.md` with longer-form notes on ABI encoding, function selectors, and natspec.

## Why these specifically

These three areas are where reading official docs leaves the biggest gaps. Storage docs do not show what packing looks like in practice. Gas docs do not put pattern costs side-by-side. EIP-1153 docs are mostly the spec without a worked example.
