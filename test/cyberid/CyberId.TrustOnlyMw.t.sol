// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import "forge-std/Test.sol";
import "../../src/core/CyberId.sol";
import { DataTypes } from "../../src/libraries/DataTypes.sol";
import { TrustOnlyMiddleware } from "../../src/middlewares/cyberid/TrustOnlyMiddleware.sol";
import { CyberIdTestBase } from "../utils/CyberIdTestBase.sol";

/**
 * @dev All test names follow the pattern of "test_[GIVEN]_[WHEN]_[THEN]"
 */
contract CyberIdStableFeeMwTest is CyberIdTestBase {
    TrustOnlyMiddleware public trustOnlyMw;

    uint256 public trustSk = 999;
    address public trustAddress = vm.addr(trustSk);

    function setUp() public override {
        super.setUp();

        trustOnlyMw = new TrustOnlyMiddleware(address(cid));
        cid.setMiddleware(address(trustOnlyMw), abi.encode(trustAddress));
    }

    /* solhint-disable func-name-mixedcase */

    function test_NameNotRegistered_TrustRegisterName_Success() public {
        vm.stopPrank();
        vm.startPrank(trustAddress);
        cid.register("alice", aliceAddress, secret, "");
    }

    function test_NameNotRegistered_NotTrustRegisterName_RevertNotTrusted()
        public
    {
        vm.expectRevert("NOT_TRUSTED_CALLER");
        cid.register("alice", aliceAddress, secret, "");
    }
    /* solhint-disable func-name-mixedcase */
}
