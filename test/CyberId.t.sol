// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/core/CyberId.sol";
import { MockUsdOracle } from "./utils/MockUsdOracle.sol";

/**
 * @dev All test names follow the pattern of "test_[GIVEN]_[WHEN]_[THEN]"
 */
contract CyberIdTest is Test {
    CyberId public cid;
    address public aliceAddress =
        address(0x2E0446079705B6Bacc4730fB3EDA5DA68aE5Fe4D);
    bytes32 public commitment =
        0xeef54eed8da56e808443372ffeab4d7b46043e6db8aa8b3cd9de5f5340ec1f2b;
    bytes32 public secret =
        0x0eefdc6e193f9cbd5f64811cd42779ce2e472065df02ecb9db84d8b7e11951ca;
    // 2023-05-22T17:25:30
    uint256 public startTs = 1684747530;
    uint256 public startBalance = 100 ether;

    event Register(
        string cid,
        address indexed to,
        uint256 expiry,
        uint256 cost
    );
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    function setUp() public {
        vm.startPrank(aliceAddress);
        MockUsdOracle usdOracle = new MockUsdOracle();
        cid = new CyberId("CYBER ID", "CYBERID", address(usdOracle));
        // set timestamp to startTs
        vm.warp(startTs);
        vm.deal(aliceAddress, startBalance);
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
        bytes32 commit = cid.generateCommit("alice", aliceAddress, 1, secret);
        assertEq(commit, commitment);
    }

    function test_TrustedOnly_Commit_RegistrationNotStarted() public {
        vm.expectRevert("REGISTRATION_NOT_STARTED");
        cid.commit(commitment);
    }

    function test_DisableTrustedOnly_Commit_CommitSuccess() public {
        cid.disableTrustedOnly();
        cid.commit(commitment);
        assertEq(cid.timestampOf(commitment), startTs);
    }

    function test_Committed_CommitWithin10mins_RevertCommitReplay() public {
        cid.disableTrustedOnly();
        cid.commit(commitment);
        vm.warp(startTs + 10 minutes);
        vm.expectRevert("COMMIT_REPLAY");
        cid.commit(commitment);
    }

    function test_Committed_CommitAfter10mins_CommitSuccess() public {
        cid.disableTrustedOnly();
        cid.commit(commitment);
        vm.warp(startTs + 10 minutes + 1 seconds);
        cid.commit(commitment);
    }

    function test_NotCommitted_Register_RevertNotCommitted() public {
        vm.expectRevert("NOT_COMMITTED");
        cid.register("alice", aliceAddress, 1, secret, 1);
    }

    function test_CommitExpired_Register_RevertNotCommitted() public {
        cid.disableTrustedOnly();
        cid.commit(commitment);
        vm.warp(startTs + 10 minutes + 1 seconds);
        vm.expectRevert("NOT_COMMITTED");
        cid.register("alice", aliceAddress, 1, secret, 1);
    }

    function test_Committed_RegisterWithin60Seconds_RevertTooQuick() public {
        cid.disableTrustedOnly();
        cid.commit(commitment);
        vm.warp(startTs + 60 seconds);
        vm.expectRevert("REGISTER_TOO_QUICK");
        cid.register("alice", aliceAddress, 1, secret, 1);
    }

    function test_Committed_WrongDurationRegister_RevertWrongDuration() public {
        cid.disableTrustedOnly();
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        vm.expectRevert("MIN_DURATION_ONE_YEAR");
        cid.register("alice", aliceAddress, 1, secret, 0);
    }

    function test_Registered_RegisterAgain_RevertNotCommitted() public {
        cid.disableTrustedOnly();
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);
        vm.expectRevert("NOT_COMMITTED");
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);
    }

    function test_Committed_RegisterWithInsufficientFunds_RevertInsufficientFunds()
        public
    {
        cid.disableTrustedOnly();
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        uint256 cost = cid.getPriceWeiAt("alice", 1, 1);
        vm.expectRevert("INSUFFICIENT_FUNDS");
        cid.register{ value: cost - 1 wei }(
            "alice",
            aliceAddress,
            1,
            secret,
            1
        );
    }

    function test_NameRegisteredByOthers_Register_RevertInvalidName() public {
        cid.disableTrustedOnly();
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);

        cid.commit(commitment);
        vm.warp(startTs + 61 seconds * 2);
        vm.expectRevert("INVALID_NAME");
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);
    }

    function test_NameExpired_Register_RevertTokenExists() public {
        cid.disableTrustedOnly();
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);

        vm.warp(startTs + 61 seconds + 365 days + 30 days);
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds + 365 days + 30 days + 61 seconds);
        vm.expectRevert("ERC721: token already minted");
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);
    }

    function test_Committed_Register_Success() public {
        cid.disableTrustedOnly();
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        uint256 cost = cid.getPriceWeiAt("alice", 1, 1);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), aliceAddress, cid.getTokenId("alice"));
        vm.expectEmit(true, true, true, true);
        emit Register(
            "alice",
            aliceAddress,
            startTs + 61 seconds + 365 days,
            cost
        );
        cid.register{ value: cost * 1 wei }(
            "alice",
            aliceAddress,
            1,
            secret,
            1
        );
        assertEq(aliceAddress.balance, startBalance - cost);
        assertEq(address(cid).balance, cost);
    }

    function test_Committed_RegisterWithOverPay_Refund() public {
        cid.disableTrustedOnly();
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        uint256 cost = cid.getPriceWeiAt("alice", 1, 1);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), aliceAddress, cid.getTokenId("alice"));
        vm.expectEmit(true, true, true, true);
        emit Register(
            "alice",
            aliceAddress,
            startTs + 61 seconds + 365 days,
            cost
        );
        cid.register{ value: startBalance }(
            "alice",
            aliceAddress,
            1,
            secret,
            1
        );
        assertEq(aliceAddress.balance, startBalance - cost);
        assertEq(address(cid).balance, cost);
    }

    function test_TrustedOnly_TrustedRegisterZeroYear_RevertWrongYear() public {
        vm.expectRevert("MIN_DURATION_ONE_YEAR");
        cid.trustedRegister("alice", aliceAddress, 0);
    }

    function test_DisableTrustedOnly_TrustedRegister_RevertRegistrationStarted()
        public
    {
        cid.disableTrustedOnly();
        vm.expectRevert("REGISTRATION_STARTED");
        cid.trustedRegister("alice", aliceAddress, 0);
    }

    function test_TrustedOnly_TrustedRegister_Success() public {
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), aliceAddress, cid.getTokenId("alice"));
        vm.expectEmit(true, true, true, true);
        emit Register("alice", aliceAddress, startTs + 365 days, 0);
        cid.trustedRegister("alice", aliceAddress, 1);
    }

    /* solhint-disable func-name-mixedcase */
}
