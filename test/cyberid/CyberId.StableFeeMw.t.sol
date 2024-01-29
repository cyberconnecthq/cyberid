// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import "forge-std/Test.sol";
import "../../src/core/CyberId.sol";
import { MockWallet } from "../utils/MockWallet.sol";
import { MockUsdOracle } from "../utils/MockUsdOracle.sol";
import { MockTokenReceiver } from "../utils/MockTokenReceiver.sol";
import { DataTypes } from "../../src/libraries/DataTypes.sol";
import { StableFeeMiddleware } from "../../src/middlewares/cyberid/StableFeeMiddleware.sol";
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
        stableFeeMw = new StableFeeMiddleware(
            address(oracle),
            address(new MockTokenReceiver()),
            address(cid)
        );
        cid.setMiddleware(
            address(stableFeeMw),
            abi.encode(
                false,
                treasuryAddress,
                [
                    uint256(10000 ether),
                    2000 ether,
                    1000 ether,
                    500 ether,
                    100 ether,
                    50 ether,
                    10 ether,
                    5 ether
                ]
            )
        );
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
        assertTrue(cid.available(unicode"1_"));
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
        uint256 cost = stableFeeMw.getPriceWei("alice");
        vm.expectRevert("INSUFFICIENT_FUNDS");
        cid.register{ value: cost - 1 wei }(
            "alice",
            aliceAddress,
            secret,
            preData
        );
    }

    function test_Committed_RegisterToWrongWallet_RevertRefundFail() public {
        vm.stopPrank();
        vm.startPrank(mockWalletAddress);
        cid.commit(commitmentWithPreData);
        vm.warp(startTs + 61 seconds);
        uint256 cost = stableFeeMw.getPriceWei("alice");
        vm.expectRevert("REFUND_FAILED");
        cid.register{ value: cost * 1 wei + 1 ether }(
            "alice",
            aliceAddress,
            secret,
            preData
        );
    }

    function test_Committed_RegisterWithOverPay_Refund() public {
        cid.commit(commitmentWithPreData);
        vm.warp(startTs + 61 seconds);
        uint256 cost = stableFeeMw.getPriceWei("alice");
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), aliceAddress, cid.getTokenId("alice"));
        vm.expectEmit(true, true, true, true);
        emit Register(
            aliceAddress,
            aliceAddress,
            cid.getTokenId("alice"),
            "alice",
            cost
        );
        cid.register{ value: startBalance }(
            "alice",
            aliceAddress,
            secret,
            preData
        );
        assertEq(aliceAddress.balance, startBalance - cost);
        assertEq(address(treasuryAddress).balance, cost);
    }

    /* solhint-disable func-name-mixedcase */
}
