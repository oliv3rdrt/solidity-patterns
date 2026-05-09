# Solidity Language Notes

Personal notes from reading the Solidity docs and changelog deeply.

## ABI Encoding gotchas

`abi.encodePacked` does not pad values - can lead to hash collisions:
```solidity
// DANGEROUS: abi.encodePacked("AB", "CD") == abi.encodePacked("A", "BCD")
keccak256(abi.encodePacked(a, b)) // use abi.encode for untrusted inputs
```

## Function selectors

Selector = first 4 bytes of keccak256 of the function signature:
```solidity
bytes4 sel = bytes4(keccak256("transfer(address,uint256)"));
// → 0xa9059cbb
```

Selector collisions are theoretically exploitable in proxy fallback routing - always check.

## Natspec for custom errors

```solidity
/// @notice Thrown when caller lacks the required role
/// @param caller The address that attempted the call
/// @param role The required role hash
error MissingRole(address caller, bytes32 role);
```

## Upcoming in Solidity (tracking changelog)

- **`using` for user-defined value types** - cleaner UDVT syntax
- **Qualified access for events/errors** - `ContractName.EventName`
- **`mcopy` opcode support** - more efficient memory copy in Cancun

## Assembly patterns I've actually used

```solidity
// Efficient address-to-bytes20 for SSTORE2
assembly {
    mstore(0, addr)
    hash := keccak256(12, 20)
}

// Reading arbitrary storage slot (for proxy storage inspection)
assembly {
    val := sload(slot)
}
```
