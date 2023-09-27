// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import "forge-std/Test.sol";
import "../../src/core/CyberId.sol";
import { MockUsdOracle } from "../utils/MockUsdOracle.sol";
import { CyberIdTestBase } from "../utils/CyberIdTestBase.sol";
import { DataTypes } from "../../src/libraries/DataTypes.sol";
import { PermissionedStableFeeMiddleware } from "../../src/middlewares/cyberid/PermissionedStableFeeMiddleware.sol";
import { TestLib712 } from "../utils/TestLib712.sol";

/**
 * @dev All test names follow the pattern of "test_[GIVEN]_[WHEN]_[THEN]"
 */
contract CyberIdPermissionedStableFeeMwTest is CyberIdTestBase {
    address public mw;

    bytes32 public constant REGISTER_TYPEHASH =
        keccak256(
            "register(string cid,address to,uint256 nonce,uint256 deadline,bool free)"
        );

    uint256 public treasurySk = 999;
    address public treasuryAddress = vm.addr(treasurySk);

    function setUp() public override {
        super.setUp();
        MockUsdOracle oracle = new MockUsdOracle();
        PermissionedStableFeeMiddleware permissionMw = new PermissionedStableFeeMiddleware(
                address(oracle),
                address(cid)
            );
        mw = address(permissionMw);
        cid.setMiddleware(
            mw,
            abi.encode(
                aliceAddress,
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
    }

    /* solhint-disable func-name-mixedcase */
    function test_NameNotRegistered_CheckNameAvailable_Available() public {
        // 1 letter
        assertTrue(cid.available("1"));
        // 20 letters
        assertTrue(cid.available("123456789abcdefghiz_"));
        // utf8 characters
        assertFalse(cid.available(unicode"中文"));
        // utf8 characters
        assertFalse(cid.available(unicode"😋"));
        // 0 letter
        assertFalse(cid.available(""));
        // space
        assertFalse(cid.available(" "));
        // dash
        assertFalse(cid.available("-"));
        // 21 letters
        assertFalse(cid.available("123456789abcdefghiz_1"));
    }

    function test_MiddlewareCreated_SetDataFromNonNameRegistry_RevertUnauthorized()
        public
    {
        vm.stopPrank();
        vm.startPrank(bobAddress);
        vm.expectRevert("NOT_NAME_REGISTRY");
        PermissionedStableFeeMiddleware(mw).setMwData(
            abi.encode(
                bobAddress,
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
    }

    function test_NameNotRegistered_Register_Success() public {
        string memory name = "test";
        uint256 deadline = startTs;
        bytes32 digest = TestLib712.hashTypedDataV4(
            mw,
            keccak256(
                abi.encode(
                    REGISTER_TYPEHASH,
                    keccak256(bytes(name)),
                    aliceAddress,
                    0,
                    deadline,
                    true
                )
            ),
            "PermissionedStableFeeMw",
            "1"
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceSk, digest);

        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), aliceAddress, cid.getTokenId(name));
        vm.expectEmit(true, true, true, true);
        emit Register(
            aliceAddress,
            aliceAddress,
            cid.getTokenId(name),
            name,
            0
        );
        cid.register(
            name,
            aliceAddress,
            bytes32(0),
            abi.encode(v, r, s, deadline, true)
        );
    }

    function test_NameRegistered_RegisterUsingSameSig_RevertInvalidSig()
        public
    {
        string memory name = "test";
        uint256 deadline = startTs;
        bytes32 digest = TestLib712.hashTypedDataV4(
            mw,
            keccak256(
                abi.encode(
                    REGISTER_TYPEHASH,
                    keccak256(bytes(name)),
                    aliceAddress,
                    0,
                    deadline,
                    true
                )
            ),
            "PermissionedStableFeeMw",
            "1"
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceSk, digest);

        cid.register(
            name,
            aliceAddress,
            bytes32(0),
            abi.encode(v, r, s, deadline, true)
        );
        vm.expectRevert("INVALID_SIGNATURE");
        cid.register(
            name,
            aliceAddress,
            bytes32(0),
            abi.encode(v, r, s, deadline, true)
        );
    }

    function test_NameNotRegistered_SigDeadlineExceeded_RevertDeadlineExceeded()
        public
    {
        string memory name = "test";
        uint256 deadline = startTs - 1 seconds;
        bytes32 digest = TestLib712.hashTypedDataV4(
            mw,
            keccak256(
                abi.encode(
                    REGISTER_TYPEHASH,
                    keccak256(bytes(name)),
                    aliceAddress,
                    0,
                    deadline,
                    true
                )
            ),
            "PermissionedStableFeeMw",
            "1"
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceSk, digest);

        vm.expectRevert("DEADLINE_EXCEEDED");
        cid.register(
            name,
            aliceAddress,
            bytes32(0),
            abi.encode(v, r, s, deadline, true)
        );
    }

    function test_NameNotRegistered_RegisterWithWrongSigner_RevertInvalidSig()
        public
    {
        string memory name = "test";
        uint256 deadline = startTs;
        bytes32 digest = TestLib712.hashTypedDataV4(
            mw,
            keccak256(
                abi.encode(
                    REGISTER_TYPEHASH,
                    keccak256(bytes(name)),
                    aliceAddress,
                    0,
                    deadline,
                    true
                )
            ),
            "PermissionedStableFeeMw",
            "1"
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobSk, digest);

        vm.expectRevert("INVALID_SIGNATURE");
        cid.register(
            name,
            aliceAddress,
            bytes32(0),
            abi.encode(v, r, s, deadline, true)
        );
    }

    function test_NameNotRegistered_RegisterWithWrongTo_RevertInvalidSig()
        public
    {
        string memory name = "test";
        uint256 deadline = startTs;
        bytes32 digest = TestLib712.hashTypedDataV4(
            mw,
            keccak256(
                abi.encode(
                    REGISTER_TYPEHASH,
                    keccak256(bytes(name)),
                    bobAddress,
                    0,
                    deadline,
                    true
                )
            ),
            "PermissionedStableFeeMw",
            "1"
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceSk, digest);

        vm.expectRevert("INVALID_SIGNATURE");
        cid.register(
            name,
            aliceAddress,
            bytes32(0),
            abi.encode(v, r, s, deadline, true)
        );
    }

    function test_NameNotRegistered_RegisterWithWrongName_RevertInvalidSig()
        public
    {
        string memory name = "test";
        uint256 deadline = startTs;
        bytes32 digest = TestLib712.hashTypedDataV4(
            mw,
            keccak256(
                abi.encode(
                    REGISTER_TYPEHASH,
                    keccak256(bytes("test2")),
                    aliceAddress,
                    0,
                    deadline,
                    true
                )
            ),
            "PermissionedStableFeeMw",
            "1"
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceSk, digest);

        vm.expectRevert("INVALID_SIGNATURE");
        cid.register(
            name,
            aliceAddress,
            bytes32(0),
            abi.encode(v, r, s, deadline, true)
        );
    }

    function test_NameNotRegistered_RegisterWithWrongNonce_RevertInvalidSig()
        public
    {
        string memory name = "test";
        uint256 deadline = startTs;
        bytes32 digest = TestLib712.hashTypedDataV4(
            mw,
            keccak256(
                abi.encode(
                    REGISTER_TYPEHASH,
                    keccak256(bytes(name)),
                    aliceAddress,
                    1,
                    deadline,
                    true
                )
            ),
            "PermissionedStableFeeMw",
            "1"
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceSk, digest);

        vm.expectRevert("INVALID_SIGNATURE");
        cid.register(
            name,
            aliceAddress,
            bytes32(0),
            abi.encode(v, r, s, deadline, true)
        );
    }

    function test_NameNotRegistered_RegisterWithNotFree_RevertInsufficientFunds()
        public
    {
        string memory name = "test";
        uint256 deadline = startTs;
        bytes32 digest = TestLib712.hashTypedDataV4(
            mw,
            keccak256(
                abi.encode(
                    REGISTER_TYPEHASH,
                    keccak256(bytes(name)),
                    aliceAddress,
                    0,
                    deadline,
                    false
                )
            ),
            "PermissionedStableFeeMw",
            "1"
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceSk, digest);

        vm.expectRevert("INSUFFICIENT_FUNDS");
        cid.register(
            name,
            aliceAddress,
            bytes32(0),
            abi.encode(v, r, s, deadline, false)
        );
    }

    function test_NameNotRegistered_RegisterWithNotFree_Success() public {
        string memory name = "test";
        uint256 deadline = startTs;
        bytes32 digest = TestLib712.hashTypedDataV4(
            mw,
            keccak256(
                abi.encode(
                    REGISTER_TYPEHASH,
                    keccak256(bytes(name)),
                    aliceAddress,
                    0,
                    deadline,
                    false
                )
            ),
            "PermissionedStableFeeMw",
            "1"
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceSk, digest);
        uint256 expectedCost = PermissionedStableFeeMiddleware(mw).getPriceWei(
            name
        );

        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), aliceAddress, cid.getTokenId(name));
        vm.expectEmit(true, true, true, true);
        emit Register(
            aliceAddress,
            aliceAddress,
            cid.getTokenId(name),
            name,
            expectedCost
        );
        cid.register{ value: expectedCost + 1 wei }(
            name,
            aliceAddress,
            bytes32(0),
            abi.encode(v, r, s, deadline, false)
        );
        assertEq(aliceAddress.balance, startBalance - expectedCost);
        assertEq(treasuryAddress.balance, expectedCost);
    }

    /* solhint-disable func-name-mixedcase */
}
