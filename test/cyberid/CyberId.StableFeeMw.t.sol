// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import "forge-std/Test.sol";
import "../../src/core/CyberId.sol";
import { MockWallet } from "../utils/MockWallet.sol";
import { MockUsdOracle } from "../utils/MockUsdOracle.sol";
import { DataTypes } from "../../src/libraries/DataTypes.sol";
import { StableFeeMiddleware } from "../../src/middlewares/StableFeeMiddleware.sol";
import { CyberIdTestBase } from "../utils/CyberIdTestBase.sol";

/**
 * @dev All test names follow the pattern of "test_[GIVEN]_[WHEN]_[THEN]"
 */
contract CyberIdStableFeeMwTest is CyberIdTestBase {
    StableFeeMiddleware public stableFeeMw;
    bytes32 public commitmentWithPreData;
    bytes public preData;
    address public mockWalletAddress;
    uint256 public treasurySk = 999;
    address public treasuryAddress = vm.addr(treasurySk);

    function setUp() public override {
        super.setUp();
        MockWallet mockWallet = new MockWallet();
        mockWalletAddress = address(mockWallet);
        vm.deal(mockWalletAddress, startBalance);
        MockUsdOracle oracle = new MockUsdOracle();
        uint256[] memory prices = new uint256[](5);
        prices[2] = 20294266869609;
        prices[3] = 5073566717402;
        prices[4] = 158548959919;
        stableFeeMw = new StableFeeMiddleware(address(oracle), prices);
        cid.setMiddleware(address(stableFeeMw), abi.encode(treasuryAddress));
        preData = abi.encode(uint80(1));
        commitmentWithPreData = cid.generateCommit(
            "alice",
            aliceAddress,
            secret,
            preData
        );
    }

    /* solhint-disable func-name-mixedcase */

    function test_MiddlewareSet_CheckNameAvailable_Available() public {
        assertTrue(cid.available(unicode"alice"));
        assertTrue(cid.available(unicode"bob"));
        assertTrue(cid.available(unicode"bobb"));
        assertTrue(cid.available(unicode"_"));
        assertFalse(cid.available(unicode"三个字"));
        assertFalse(cid.available(unicode"四个字儿"));
        assertFalse(cid.available(unicode"😋😋😋"));
        assertFalse(cid.available(unicode"😋😋😋😋"));
        assertFalse(cid.available(unicode"    "));
        assertFalse(cid.available(unicode""));
        assertFalse(cid.available(unicode"二字"));
        assertFalse(cid.available(unicode"😋😋"));
        assertFalse(cid.available("zerowidthcharacter\u200a\u200b"));
        assertFalse(cid.available("zerowidthcharacter\u200a\u200c"));
        assertFalse(cid.available("zerowidthcharacter\u200a\u200d"));
        assertFalse(cid.available("zerowidthcharacter\ufefe\ufeff"));
        assertFalse(cid.available("123456789112345678921"));
    }

    function test_Committed_RegisterWithInsufficientFunds_RevertInsufficientFunds()
        public
    {
        cid.commit(commitmentWithPreData);
        vm.warp(startTs + 61 seconds);
        uint256 cost = stableFeeMw.getPriceWeiAt("alice", 1, 1);
        vm.expectRevert("INSUFFICIENT_FUNDS");
        cid.register{ value: cost - 1 wei }(
            "alice",
            aliceAddress,
            secret,
            1,
            preData
        );
    }

    function test_Committed_RegisterToWrongWallet_RevertRefundFail() public {
        vm.stopPrank();
        vm.startPrank(mockWalletAddress);
        cid.commit(commitmentWithPreData);
        vm.warp(startTs + 61 seconds);
        uint256 cost = stableFeeMw.getPriceWeiAt("alice", 1, 1);
        vm.expectRevert("REFUND_FAILED");
        cid.register{ value: cost * 1 wei + 1 ether }(
            "alice",
            aliceAddress,
            secret,
            1,
            preData
        );
    }

    function test_Committed_RegisterWithOverPay_Refund() public {
        cid.commit(commitmentWithPreData);
        vm.warp(startTs + 61 seconds);
        uint256 cost = stableFeeMw.getPriceWeiAt("alice", 1, 1);
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
            secret,
            1,
            preData
        );
        assertEq(aliceAddress.balance, startBalance - cost);
        assertEq(address(treasuryAddress).balance, cost);
    }

    function test_NotRegistered_RenewWithInsufficientFunds_RevertInsufficientFunds()
        public
    {
        cid.commit(commitmentWithPreData);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }(
            "alice",
            aliceAddress,
            secret,
            1,
            preData
        );

        vm.warp(startTs + 61 seconds + 365 days + 30 days - 1 seconds);
        uint256 cost = stableFeeMw.getPriceWei("alice", 1);
        vm.expectRevert("INSUFFICIENT_FUNDS");
        cid.renew{ value: cost - 1 wei }("alice", 1, "");
    }

    function test_Registered_WithinGracePeriodRenew_NameRenewed() public {
        cid.commit(commitmentWithPreData);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }(
            "alice",
            aliceAddress,
            secret,
            1,
            preData
        );
        uint256 registerCost = stableFeeMw.getPriceWeiAt("alice", 1, 1);

        uint256 renewCost = stableFeeMw.getPriceWei("alice", 1);
        uint256 newExpiry = startTs + 61 seconds + 365 days + 365 days;
        vm.warp(startTs + 61 seconds + 365 days + 30 days - 1 seconds);
        vm.expectEmit(true, true, true, true);
        emit Renew("alice", newExpiry, renewCost);
        cid.renew{ value: 1 ether }("alice", 1, "");
        assertEq(cid.expiries(cid.getTokenId("alice")), newExpiry);
        assertEq(aliceAddress.balance, startBalance - registerCost - renewCost);
        assertEq(address(treasuryAddress).balance, registerCost + renewCost);
    }

    function test_Registered_RenewWithWrongWallet_RevertRefundFail() public {
        cid.commit(commitmentWithPreData);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }(
            "alice",
            aliceAddress,
            secret,
            1,
            preData
        );

        vm.stopPrank();
        vm.startPrank(mockWalletAddress);
        vm.warp(startTs + 61 seconds + 365 days + 30 days - 1 seconds);
        vm.expectRevert("REFUND_FAILED");
        cid.renew{ value: 1 ether }("alice", 1, "");
    }

    function test_NameAfterGracePeriod_BidWithInsufficientFunds_RevertInsufficientFunds()
        public
    {
        cid.commit(commitmentWithPreData);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }(
            "alice",
            aliceAddress,
            secret,
            1,
            preData
        );

        uint256 baseFee = stableFeeMw.getPriceWei("alice", 1);
        vm.warp(startTs + 61 seconds + 365 days + 30 days);
        // round 0 cost base fee + 1000 eth
        vm.expectRevert("INSUFFICIENT_FUNDS");
        cid.bid{ value: baseFee * 1 wei + 1000 ether - 1 wei }(
            bobAddress,
            "alice",
            ""
        );
    }

    function test_NameAfterGracePeriod_BidAtRound0_Success() public {
        cid.commit(commitmentWithPreData);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }(
            "alice",
            aliceAddress,
            secret,
            1,
            preData
        );
        uint256 registerCost = stableFeeMw.getPriceWeiAt("alice", 1, 1);

        uint256 baseFee = stableFeeMw.getPriceWei("alice", 1);
        uint256 bidFee = baseFee + 1000 ether;
        vm.warp(startTs + 61 seconds + 365 days + 30 days);
        vm.expectEmit(true, true, true, true);
        emit Bid(
            "alice",
            startTs + 61 seconds + 365 days + 30 days + 365 days,
            bidFee
        );
        // round 0 cost base fee + 1000 eth, overpay 1 eth on purpose to test refund
        cid.bid{ value: bidFee + 1 ether }(bobAddress, "alice", "");
        uint256 tokenId = cid.getTokenId("alice");
        assertEq(cid.ownerOf(tokenId), bobAddress);
        assertEq(aliceAddress.balance, startBalance - registerCost - bidFee);
        assertEq(address(treasuryAddress).balance, registerCost + bidFee);
    }

    function test_NameAfterGracePeriod_BidAtRound1_Success() public {
        cid.commit(commitmentWithPreData);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }(
            "alice",
            aliceAddress,
            secret,
            1,
            preData
        );
        uint256 registerCost = stableFeeMw.getPriceWeiAt("alice", 1, 1);

        uint256 baseFee = stableFeeMw.getPriceWei("alice", 1);
        uint256 bidFee = 899995021729403941000 wei + baseFee;
        uint256 bidTs = startTs +
            61 seconds +
            365 days +
            30 days +
            4605 seconds *
            1;
        vm.warp(bidTs);
        vm.expectEmit(true, true, true, true);
        emit Bid("alice", bidTs + 365 days, bidFee);
        // round 1 cost base fee + 900 eth, overpay 1 eth on purpose to test refund
        cid.bid{ value: bidFee + 1 ether }(bobAddress, "alice", "");
        uint256 tokenId = cid.getTokenId("alice");
        assertEq(cid.ownerOf(tokenId), bobAddress);
        assertEq(aliceAddress.balance, startBalance - registerCost - bidFee);
        assertEq(address(treasuryAddress).balance, registerCost + bidFee);
    }

    function test_NameAfterGracePeriod_BidAtRound393_Success() public {
        cid.commit(commitmentWithPreData);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }(
            "alice",
            aliceAddress,
            secret,
            1,
            preData
        );
        uint256 registerCost = stableFeeMw.getPriceWeiAt("alice", 1, 1);

        uint256 baseFee = stableFeeMw.getPriceWei("alice", 1);
        uint256 bidFee = 1000 wei + baseFee;
        uint256 bidTs = startTs +
            61 seconds +
            365 days +
            30 days +
            4605 seconds *
            393;
        vm.warp(bidTs);
        vm.expectEmit(true, true, true, true);
        emit Bid("alice", bidTs + 365 days, bidFee);
        cid.bid{ value: bidFee + 1 ether }(bobAddress, "alice", "");
        uint256 tokenId = cid.getTokenId("alice");
        assertEq(cid.ownerOf(tokenId), bobAddress);
        assertEq(aliceAddress.balance, startBalance - registerCost - bidFee);
        assertEq(address(treasuryAddress).balance, registerCost + bidFee);
    }

    function test_NameAfterGracePeriod_BidAtRound394_Success() public {
        cid.commit(commitmentWithPreData);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }(
            "alice",
            aliceAddress,
            secret,
            1,
            preData
        );
        uint256 registerCost = stableFeeMw.getPriceWeiAt("alice", 1, 1);

        uint256 baseFee = stableFeeMw.getPriceWei("alice", 1);
        uint256 bidFee = baseFee;
        uint256 bidTs = startTs +
            61 seconds +
            365 days +
            30 days +
            4605 seconds *
            394;
        vm.warp(bidTs);
        vm.expectEmit(true, true, true, true);
        emit Bid("alice", bidTs + 365 days, bidFee);
        cid.bid{ value: bidFee + 1 ether }(bobAddress, "alice", "");
        uint256 tokenId = cid.getTokenId("alice");
        assertEq(cid.ownerOf(tokenId), bobAddress);
        assertEq(aliceAddress.balance, startBalance - registerCost - bidFee);
        assertEq(address(treasuryAddress).balance, registerCost + bidFee);
    }

    function test_NameAfterGracePeriod_BidAtRound0WithWrongWallet_RevertRefundFail()
        public
    {
        cid.commit(commitmentWithPreData);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }(
            "alice",
            aliceAddress,
            secret,
            1,
            preData
        );

        vm.stopPrank();
        vm.startPrank(mockWalletAddress);
        uint256 baseFee = stableFeeMw.getPriceWei("alice", 1);
        uint256 bidFee = baseFee + 1000 ether;
        vm.warp(startTs + 61 seconds + 365 days + 30 days);
        vm.expectRevert("REFUND_FAILED");
        cid.bid{ value: bidFee + 1 ether }(bobAddress, "alice", "");
    }

    /* solhint-disable func-name-mixedcase */
}
