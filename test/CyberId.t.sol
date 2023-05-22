// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/core/CyberId.sol";
import { MockUsdOracle } from "./utils/MockUsdOracle.sol";

contract CyberIdTest is Test {
    CyberId public cid;

    function setUp() public {
        MockUsdOracle usdOracle = new MockUsdOracle();
        cid = new CyberId("CYBER ID", "CYBERID", address(usdOracle));
        // set timestamp to 2023-05-22T17:25:30
        vm.warp(1684747530);
    }

    /* solhint-disable func-name-mixedcase */
    function test_NameNotRegistered_CheckNameAvailable_Available() public {
        assertTrue(cid.available(unicode"alice"));
        assertTrue(cid.available(unicode"bob"));
        assertTrue(cid.available(unicode"bobb"));
        assertTrue(cid.available(unicode"三个字"));
        assertTrue(cid.available(unicode"四个字儿"));
        assertTrue(cid.available(unicode"😋😋😋"));
        assertTrue(cid.available(unicode"😋😋😋😋"));
        assertTrue(cid.available(unicode"    "));
    }

    function test_NameNotRegistered_CheckNameAvailable_NotAvailable() public {
        assertFalse(cid.available(unicode""));
        assertFalse(cid.available(unicode"bo"));
        assertFalse(cid.available(unicode"二字"));
        assertFalse(cid.available(unicode"😋😋"));
        assertFalse(cid.available("zerowidthcharacter\u200b"));
        assertFalse(cid.available("zerowidthcharacter\u200c"));
        assertFalse(cid.available("zerowidthcharacter\u200d"));
        assertFalse(cid.available("zerowidthcharacter\ufeff"));
    }

    function test_GenerateCommit() public {
        // bytes32 secret = keccak256(abi.encodePacked(block.timestamp));
        bytes32 secret = 0x0eefdc6e193f9cbd5f64811cd42779ce2e472065df02ecb9db84d8b7e11951ca;
        bytes32 commit = cid.generateCommit(
            "peng",
            address(0x2E0446079705B6Bacc4730fB3EDA5DA68aE5Fe4D),
            1,
            secret
        );
        assertEq(
            commit,
            0x9b44b3ebcc79404316643e49626f639f1de1178bf750030351426610ffa990d1
        );
    }

    function test_TrustedOnly_Commit_RegistrationNotStarted() public {
        vm.expectRevert("REGISTRATION_NOT_STARTED");
        cid.commit(
            0x9b44b3ebcc79404316643e49626f639f1de1178bf750030351426610ffa990d1
        );
    }

    /* solhint-disable func-name-mixedcase */
}
