// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import "forge-std/Test.sol";
import { RealmIdTestBase } from "../utils/RealmIdTestBase.sol";
import { PermissionMw } from "../../src/middlewares/realmid/PermissionMw.sol";
import { Constants } from "../../src/libraries/Constants.sol";
import { TestLib712 } from "../utils/TestLib712.sol";

/**
 * @dev All test names follow the pattern of "test_[GIVEN]_[WHEN]_[THEN]"
 */
contract RealmIdPermissionMwTest is RealmIdTestBase {
    address public mw;

    function setUp() public override {
        super.setUp();
        PermissionMw permissionMw = new PermissionMw(address(mid));
        mw = address(permissionMw);
        mid.setMiddleware(realmNode, mw, abi.encode(aliceAddress));
    }

    /* solhint-disable func-name-mixedcase */
    function test_NameNotRegistered_CheckNameAvailable_Available() public {
        // 1 letter
        assertTrue(mid.available("1", realmNode));
        // 20 letters
        assertTrue(mid.available("123456789abcdefghiz_", realmNode));
        // utf8 characters
        assertFalse(mid.available(unicode"中文", realmNode));
        // utf8 characters
        assertFalse(mid.available(unicode"😋", realmNode));
        // 0 letter
        assertFalse(mid.available("", realmNode));
        // space
        assertFalse(mid.available(" ", realmNode));
        // dash
        assertFalse(mid.available("-", realmNode));
        // 21 letters
        assertFalse(mid.available("123456789abcdefghiz_1", realmNode));
    }

    function test_MiddlewareCreated_SetDataFromNonNameRegistry_RevertUnauthorized()
        public
    {
        vm.stopPrank();
        vm.startPrank(bobAddress);
        vm.expectRevert("NOT_NAME_REGISTRY");
        PermissionMw(mw).setMwData(abi.encode(bobAddress));
    }

    function test_NameNotRegistered_Register_Success() public {
        string memory name = "test";
        uint256 deadline = startTs;
        bytes32 digest = TestLib712.hashTypedDataV4(
            mw,
            keccak256(
                abi.encode(
                    Constants._REGISTER_TYPEHASH,
                    keccak256(bytes(name)),
                    realmNode,
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
        emit Transfer(
            address(0),
            aliceAddress,
            mid.getTokenId(name, realmNode)
        );
        vm.expectEmit(true, true, true, true);
        emit Register(
            name,
            realmNode,
            mid.getTokenId(name, realmNode),
            aliceAddress
        );
        mid.register(
            name,
            realmNode,
            aliceAddress,
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
                    Constants._REGISTER_TYPEHASH,
                    keccak256(bytes(name)),
                    realmNode,
                    aliceAddress,
                    0,
                    deadline
                )
            ),
            "PermissionMw",
            "1"
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceSk, digest);

        mid.register(
            name,
            realmNode,
            aliceAddress,
            abi.encode(v, r, s, deadline)
        );
        vm.expectRevert("INVALID_SIGNATURE");
        mid.register(
            name,
            realmNode,
            aliceAddress,
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
                    Constants._REGISTER_TYPEHASH,
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
        mid.register(
            name,
            realmNode,
            aliceAddress,
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
                    Constants._REGISTER_TYPEHASH,
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
        mid.register(
            name,
            realmNode,
            aliceAddress,
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
                    Constants._REGISTER_TYPEHASH,
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
        mid.register(
            name,
            realmNode,
            aliceAddress,
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
                    Constants._REGISTER_TYPEHASH,
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
        mid.register(
            name,
            realmNode,
            aliceAddress,
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
                    Constants._REGISTER_TYPEHASH,
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
        mid.register(
            name,
            realmNode,
            aliceAddress,
            abi.encode(v, r, s, deadline)
        );
    }
    /* solhint-disable func-name-mixedcase */
}
