// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import "forge-std/Test.sol";
import "../../src/core/CyberId.sol";
import { CyberIdTestBase } from "../utils/CyberIdTestBase.sol";
import { DataTypes } from "../../src/libraries/DataTypes.sol";
import { PermissionMiddleware } from "../../src/middlewares/cyberid/PermissionMiddleware.sol";
import { TestLib712 } from "../utils/TestLib712.sol";

/**
 * @dev All test names follow the pattern of "test_[GIVEN]_[WHEN]_[THEN]"
 */
contract CyberIdPermissionMwTest is CyberIdTestBase {
    address public mw;

    bytes32 public constant REGISTER_TYPEHASH =
        keccak256(
            "register(string cid,address to,uint256 nonce,uint256 deadline)"
        );

    function setUp() public override {
        super.setUp();
        PermissionMiddleware permissionMw = new PermissionMiddleware(
            address(cid)
        );
        mw = address(permissionMw);
        cid.setMiddleware(mw, abi.encode(aliceAddress));
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
        PermissionMiddleware(mw).setMwData(abi.encode(bobAddress));
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
                    deadline
                )
            ),
            "PermissionMw",
            "1"
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceSk, digest);

        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), aliceAddress, cid.getTokenId(name));
        vm.expectEmit(true, true, true, true);
        emit Register(name, aliceAddress, cid.getTokenId(name), 0);
        cid.register(
            name,
            aliceAddress,
            bytes32(0),
            abi.encode(v, r, s, deadline)
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
                    deadline
                )
            ),
            "PermissionMw",
            "1"
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceSk, digest);

        cid.register(
            name,
            aliceAddress,
            bytes32(0),
            abi.encode(v, r, s, deadline)
        );
        vm.expectRevert("INVALID_SIGNATURE");
        cid.register(
            name,
            aliceAddress,
            bytes32(0),
            abi.encode(v, r, s, deadline)
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
                    deadline
                )
            ),
            "PermissionMw",
            "1"
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceSk, digest);

        vm.expectRevert("DEADLINE_EXCEEDED");
        cid.register(
            name,
            aliceAddress,
            bytes32(0),
            abi.encode(v, r, s, deadline)
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
                    deadline
                )
            ),
            "PermissionMw",
            "1"
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobSk, digest);

        vm.expectRevert("INVALID_SIGNATURE");
        cid.register(
            name,
            aliceAddress,
            bytes32(0),
            abi.encode(v, r, s, deadline)
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
                    deadline
                )
            ),
            "PermissionMw",
            "1"
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceSk, digest);

        vm.expectRevert("INVALID_SIGNATURE");
        cid.register(
            name,
            aliceAddress,
            bytes32(0),
            abi.encode(v, r, s, deadline)
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
                    deadline
                )
            ),
            "PermissionMw",
            "1"
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceSk, digest);

        vm.expectRevert("INVALID_SIGNATURE");
        cid.register(
            name,
            aliceAddress,
            bytes32(0),
            abi.encode(v, r, s, deadline)
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
                    deadline
                )
            ),
            "PermissionMw",
            "1"
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceSk, digest);

        vm.expectRevert("INVALID_SIGNATURE");
        cid.register(
            name,
            aliceAddress,
            bytes32(0),
            abi.encode(v, r, s, deadline)
        );
    }
    /* solhint-disable func-name-mixedcase */
}
