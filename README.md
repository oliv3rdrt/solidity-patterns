```
   ____    _ _    _ _ _         
  / ___|__| (_)__| (_) |_ _  _  
  \___ \/ _` | / _` | |  _| || | 
  |___/\__,_|_\__,_|_|\__|\_, |  
                          |__/   

  Storage layout · Gas · EVM internals
```

[![Foundry](https://img.shields.io/badge/Foundry-1.x-orange.svg)](https://book.getfoundry.sh)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-blue.svg)](https://docs.soliditylang.org/)
[![EVM](https://img.shields.io/badge/EVM-Cancun-purple.svg)](https://eips.ethereum.org/EIPS/eip-7569)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A working notebook for the parts of Solidity that the docs gloss over: how
storage actually packs into 32-byte slots, why `unchecked` and `calldata`
matter for gas, what the `mcopy` and `tstore` opcodes mean, and which assembly
patterns earn their place in production code.

Each contract is paired with Foundry tests so the claims here are reproducible.

---

## Table of Contents

- [Topics covered](#topics-covered)
- [Prerequisites](#prerequisites)
- [Quick start](#quick-start)
- [Project structure](#project-structure)
- [Storage layout](#storage-layout)
- [Gas optimization](#gas-optimization)
- [Transient storage (EIP-1153)](#transient-storage-eip-1153)
- [Assembly patterns](#assembly-patterns)
- [Solidity 0.8.x feature timeline](#solidity-08x-feature-timeline)
- [Tests](#tests)
- [Further reading](#further-reading)

---

## Topics covered

| Topic                          | File                            | Test                          |
|--------------------------------|----------------------------------|-------------------------------|
| State variable packing         | `contracts/StorageLayout.sol`    |                               |
| Custom errors, packed structs, `unchecked`, `calldata` | `contracts/GasOptimized.sol`     | `test/GasOptimized.t.sol`     |
| Transient storage reentrancy guard | `contracts/TransientStorage.sol` | `test/TransientStorage.t.sol` |

Plus longer-form notes in `notes/language-notes.md` covering ABI encoding,
function selectors, and natspec.

## Prerequisites

| Tool   | Install                                                  |
|--------|----------------------------------------------------------|
| Foundry| `curl -L https://foundry.paradigm.xyz \| bash` then `foundryup` |
| Git    | any                                                      |

## Quick start

```bash
git clone https://github.com/DRT23-mod/solidity-fundamentals.git
cd solidity-fundamentals
forge install foundry-rs/forge-std --no-git
forge build
forge test -vv
```

Expected output:

```
Ran 3 tests for test/GasOptimized.t.sol:GasOptimizedTest
  [PASS] testFuzz_EfficientSumBalances(uint96,uint96)
  [PASS] test_BatchTransfer()
  [PASS] test_BatchTransfer_RevertOnInsufficientBalance()

Ran 2 tests for test/TransientStorage.t.sol:TransientStorageTest
  [PASS] test_DepositAndWithdraw()
  [PASS] test_ReentrancyBlocked()

5 tests passed, 0 failed
```

## Project structure

```
solidity-fundamentals/
├── contracts/
│   ├── StorageLayout.sol     # state-var packing into 32-byte slots
│   ├── GasOptimized.sol      # custom errors, calldata, unchecked, packed structs
│   └── TransientStorage.sol  # EIP-1153 nonReentrant guard
├── test/
│   ├── GasOptimized.t.sol    # vm.store cheatcode for slot-level seeding
│   └── TransientStorage.t.sol# reentrancy attacker contract included
├── notes/
│   └── language-notes.md     # ABI encoding, selectors, natspec
├── foundry.toml              # solc 0.8.24, evm cancun, fuzz 500
└── README.md
```

## Storage layout

Solidity packs state variables into 32-byte slots **left to right** in
declaration order. A new slot starts whenever the next variable does not fit
in the remaining bytes of the current slot.

```
Slot 0:  ┌─────────────────────────────────────────────────────────┐
         │  addr (20 B)  │ active (1 B) │  unused 11 B            │
         └─────────────────────────────────────────────────────────┘
Slot 1:  ┌─────────────────────────────────────────────────────────┐
         │  value (uint96 = 12 B)       │  unused 20 B            │
         └─────────────────────────────────────────────────────────┘
Slot 2:  ┌─────────────────────────────────────────────────────────┐
         │  largeValue (uint256 = 32 B, fills the slot)            │
         └─────────────────────────────────────────────────────────┘
```

Even though `address (20) + bool (1) + uint96 (12) = 33 bytes`, the compiler
does not split a variable across slots, so `value` spills into slot 1.

To pack tightly, declare in size-descending order **and** make sure each group
fits in 32 bytes:

```solidity
struct PackedUser {
    address wallet;  // 20 B  ┐
    uint96  balance; // 12 B  │ slot N
    //                32 B   ┘
    uint128 score;   // 16 B  ┐
    uint128 rank;    // 16 B  │ slot N+1
    //                32 B   ┘
}
```

Mappings and dynamic arrays each occupy one slot for their *header*. The
elements live at hashed offsets:

- `mapping(K => V)`: `value` at `keccak256(abi.encode(key, slot))`
- `T[]`: `length` at slot `s`, elements at `keccak256(s) + index * size`

You can read any slot from a test:

```solidity
function getSlot(uint256 slot) external view returns (bytes32 v) {
    assembly { v := sload(slot) }
}
```

## Gas optimization

The optimisations that consistently pay off:

| Technique                         | Saving (typical)        | When                                   |
|-----------------------------------|-------------------------|----------------------------------------|
| Custom errors over `require` strings | ~50 gas per revert + smaller bytecode | Always |
| `calldata` instead of `memory` for read-only array params | 600+ gas per param | Always |
| `unchecked` on loop counters      | ~30 gas per iteration   | Loops where overflow is impossible     |
| Cache `SLOAD` in a local          | 97 gas per re-read      | Multiple reads of the same storage var |
| Pack structs into 32-byte slots   | 20,000 gas per slot saved on first write | Mappings of structs |
| Replace storage flag with transient (`tstore`) | ~22,800 gas per call | Reentrancy guards, one-time flags |

`GasOptimized.sol` shows the canonical patterns:

```solidity
// 1. Custom errors (cheaper to deploy AND to revert with)
error InsufficientBalance(uint256 available, uint256 required);

// 2. calldata params for read-only arrays (no copy to memory)
function batchTransfer(address[] calldata recipients, uint256[] calldata amounts)
    external
{
    for (uint256 i; i < recipients.length; ) {
        uint256 bal = balances[msg.sender];                  // SLOAD once
        if (bal < amounts[i]) revert InsufficientBalance(bal, amounts[i]);
        unchecked {                                          // safe: bal >= amounts[i]
            balances[msg.sender] -= amounts[i];
            balances[recipients[i]] += amounts[i];
            ++i;                                             // counter cannot overflow
        }
    }
}
```

Verify gas savings yourself:

```bash
forge snapshot                  # writes .gas-snapshot
# edit a contract, then:
forge snapshot --diff           # diffs against the saved snapshot
```

## Transient storage (EIP-1153)

Transient storage is a per-transaction key-value store, cleared automatically
when the transaction ends. Two opcodes: `TSTORE` and `TLOAD`. Available since
the **Cancun** hard fork (March 2024).

The classic `nonReentrant` guard does two SSTOREs (set-clear) per call:

```
Storage-based guard:
  set lock      ─►  SSTORE 0->1   ~22,800 gas (cold) or 2,900 gas (warm)
  function body
  clear lock    ─►  SSTORE 1->0   ~2,800 gas (refund applies)
                                  ─────────────
                                  ~5,000 gas extra per call (warm path)
```

```
Transient-storage guard:
  set lock      ─►  TSTORE        ~100 gas
  function body
  clear lock    ─►  TSTORE        ~100 gas
                                  ─────
                                  ~200 gas extra per call
```

`TransientStorage.sol`:

```solidity
contract TransientReentrancyGuard {
    uint256 private constant LOCK_SLOT = uint256(keccak256("reentrancy.lock")) - 1;

    modifier nonReentrant() {
        uint256 slot = LOCK_SLOT;                  // assembly cannot read constants
        assembly {
            if tload(slot) { revert(0, 0) }
            tstore(slot, 1)
        }
        _;
        assembly { tstore(slot, 0) }
    }
    /* deposit / withdraw with the modifier... */
}
```

The test suite includes a full reentrancy attacker contract that proves the
guard blocks recursive `withdraw()`.

## Assembly patterns

Inline assembly earns its place when the cost is real. Two patterns from this
repo:

```solidity
// Read an arbitrary storage slot (useful for proxy debugging)
function getSlot(uint256 slot) external view returns (bytes32 v) {
    assembly { v := sload(slot) }
}
```

```solidity
// Transient lock check (the alternative is a storage SSTORE pair)
assembly {
    if tload(slot) { revert(0, 0) }
    tstore(slot, 1)
}
```

Things assembly is **not** for: micro-optimising things the optimiser already
handles, or "saving 20 gas" at the cost of audit-readability.

## Solidity 0.8.x feature timeline

| Version | Feature                                                       |
|---------|---------------------------------------------------------------|
| 0.8.0   | Built-in overflow / underflow checks (revert on overflow)     |
| 0.8.4   | Custom errors                                                  |
| 0.8.13  | `using for` global functions                                  |
| 0.8.18  | `assembly { ... }` allowed inside `unchecked`                 |
| 0.8.19  | User-defined value types more flexible                         |
| 0.8.22  | `unchecked` block default in `for` loop counters (proposal)   |
| 0.8.24  | `mcopy` opcode (Cancun), transient storage `tstore` / `tload` |
| 0.8.25  | More precise `unused-variable` warnings                       |
| 0.8.26  | Default to `paris` EVM if not set; performance fixes          |

## Tests

```bash
forge test                              # all
forge test --match-contract GasOptimizedTest
forge test --match-test test_Reentrancy --vvvv
forge test --gas-report                 # per-function gas table
```

Tests use `vm.store` to seed mapping slots directly, avoiding setup-call gas
that would distort the measurements:

```solidity
function _setBalance(address user, uint256 amount) internal {
    bytes32 slot = keccak256(abi.encode(user, uint256(1))); // mapping slot 1
    vm.store(address(opt), slot, bytes32(amount));
}
```

## Further reading

- [Solidity language docs](https://docs.soliditylang.org)
- [EVM Codes](https://www.evm.codes/) - opcode-by-opcode reference with gas
- [EIP-1153: Transient storage opcodes](https://eips.ethereum.org/EIPS/eip-1153)
- [EIP-5656: MCOPY opcode](https://eips.ethereum.org/EIPS/eip-5656)
- [Solidity gas optimization tips, OpenZeppelin](https://blog.openzeppelin.com/gas-optimization-in-solidity)
- [Foundry Book](https://book.getfoundry.sh)

## License

MIT
