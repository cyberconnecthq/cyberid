// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import "forge-std/Test.sol";
import "../src/core/MocaId.sol";
import { ERC1967Proxy } from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @dev All test names follow the pattern of "test_[GIVEN]_[WHEN]_[THEN]"
 */
contract MocaIdTest is Test {
    MocaId public mid;
    address public aliceAddress =
        address(0x2E0446079705B6Bacc4730fB3EDA5DA68aE5Fe4D);
    address public bobAddress =
        address(0x5617FEC489c0295C565626e45ed77F2265c283C6);
    // 2023-05-22T17:25:30
    uint256 public startTs = 1684747530;
    uint256 public startBalance = 2000 ether;

    event Register(string mocaId, address indexed to, uint256 expiry);
    event Renew(string mocaId, uint256 expiry);

    function setUp() public {
        vm.startPrank(aliceAddress);
        MocaId midImpl = new MocaId();
        ERC1967Proxy proxy = new ERC1967Proxy(address(midImpl), "");
        mid = MocaId(address(proxy));
        mid.initialize("MOCA ID", "MOCAID");
        // set timestamp to startTs
        vm.warp(startTs);
        vm.deal(aliceAddress, startBalance);
    }

    /* solhint-disable func-name-mixedcase */
    function test_NameNotRegistered_CheckNameAvailable_Available() public {
        assertTrue(mid.available(unicode"alice"));
        assertTrue(mid.available(unicode"bob"));
        assertTrue(mid.available(unicode"bobb"));
        assertTrue(mid.available(unicode"三个字"));
        assertTrue(mid.available(unicode"四个字儿"));
        assertTrue(mid.available(unicode"😋😋😋"));
        assertTrue(mid.available(unicode"😋😋😋😋"));
        assertTrue(mid.available(unicode"    "));
    }

    function test_NameNotRegistered_CheckNameAvailable_NotAvailable() public {
        assertFalse(mid.available(unicode""));
        assertFalse(mid.available(unicode"bo"));
        assertFalse(mid.available(unicode"二字"));
        assertFalse(mid.available(unicode"😋😋"));
        assertFalse(mid.available("zerowidthcharacter\u200a\u200b"));
        assertFalse(mid.available("zerowidthcharacter\u200a\u200c"));
        assertFalse(mid.available("zerowidthcharacter\u200a\u200d"));
        assertFalse(mid.available("zerowidthcharacter\ufefe\ufeff"));
    }

    /* solhint-disable func-name-mixedcase */
}
