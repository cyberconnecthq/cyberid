// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { MocaIdTestBase } from "../utils/MocaIdTestBase.sol";
import { MockMiddleware } from "../utils/MockMiddleware.sol";
import { DataTypes } from "../../src/libraries/DataTypes.sol";
import { MocaId } from "../../src/core/MocaId.sol";

/**
 * @dev All test names follow the pattern of "test_[GIVEN]_[WHEN]_[THEN]"
 */
contract MocaIdTest is MocaIdTestBase {
    /* solhint-disable func-name-mixedcase */
    function test_MiddlewareNotSet_CheckNameAvailable_Available() public {
        assertTrue(mid.available(unicode"alice"));
        assertTrue(mid.available(unicode"bob"));
        assertTrue(mid.available(unicode"bobb"));
        assertTrue(mid.available(unicode"三个字"));
        assertTrue(mid.available(unicode"四个字儿"));
        assertTrue(mid.available(unicode"😋😋😋"));
        assertTrue(mid.available(unicode"😋😋😋😋"));
        assertTrue(mid.available(unicode"    "));
        assertTrue(mid.available(unicode""));
        assertTrue(mid.available(unicode"bo"));
        assertTrue(mid.available(unicode"二字"));
        assertTrue(mid.available(unicode"😋😋"));
        assertTrue(mid.available("zerowidthcharacter\u200a\u200b"));
        assertTrue(mid.available("zerowidthcharacter\u200a\u200c"));
        assertTrue(mid.available("zerowidthcharacter\u200a\u200d"));
        assertTrue(mid.available("zerowidthcharacter\ufefe\ufeff"));
    }

    function test_MiddlewareNotSet_RegisterName_Success() public {
        string memory name = "test";

        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), aliceAddress, mid.getTokenId(name));
        vm.expectEmit(true, true, true, true);
        emit Register(name, mid.getTokenId(name), aliceAddress);
        mid.register(name, aliceAddress, "");
    }

    function test_NameRegistered_RegisterAgain_RevertNameNotAvailable() public {
        string memory name = "test";
        mid.register(name, aliceAddress, "");
        vm.expectRevert("NAME_NOT_AVAILABLE");
        mid.register(name, aliceAddress, "");
    }

    function test_NameRegistered_QueryAvailable_NotAvailable() public {
        assertTrue(mid.available("test"));
        string memory name = "test";
        mid.register(name, aliceAddress, "");
        assertFalse(mid.available("test"));
    }

    function test_NameRegistered_Transfer_RevertNowAllowed() public {
        string memory name = "test";
        mid.register(name, aliceAddress, "");
        uint256 tokenId = mid.getTokenId(name);
        vm.expectRevert("TRANSFER_NOT_ALLOWED");
        mid.transferFrom(aliceAddress, bobAddress, tokenId);
        vm.expectRevert("TRANSFER_NOT_ALLOWED");
        mid.safeTransferFrom(aliceAddress, bobAddress, tokenId);
        vm.expectRevert("TRANSFER_NOT_ALLOWED");
        mid.safeTransferFrom(aliceAddress, bobAddress, tokenId, "");
    }

    function test_NameBurned_Register_Success() public {
        string memory name = "test";
        assertEq(0, mid.totalSupply());

        mid.register(name, aliceAddress, "");
        assertEq(1, mid.totalSupply());

        mid.burn(mid.getTokenId(name));
        assertEq(0, mid.totalSupply());

        mid.register(name, aliceAddress, "");
        assertEq(1, mid.totalSupply());
    }

    function test_BaseUriNotSet_TokenUri_Success() public {
        mid.register("alice", aliceAddress, "");
        uint256 tokenId = mid.getTokenId("alice");
        assertEq(
            mid.tokenURI(tokenId),
            "0x9c0257114eb9399a2985f8e75dad7600c5d89fe3824ffa99ec1c3eb8bf3b0501"
        );
    }

    function test_BaseUriSet_TokenUri_Success() public {
        mid.register("alice", aliceAddress, "");
        string memory baseUri = "https://api.cyberconnect.dev/";
        mid.setBaseTokenUri(baseUri);
        uint256 tokenId = mid.getTokenId("alice");
        assertEq(
            mid.tokenURI(tokenId),
            string(
                abi.encodePacked(
                    baseUri,
                    "0x9c0257114eb9399a2985f8e75dad7600c5d89fe3824ffa99ec1c3eb8bf3b0501"
                )
            )
        );
    }

    function test_TokenNotMinted_TokenUri_RevertInavlidTokenId() public {
        vm.expectRevert("INVALID_TOKEN_ID");
        mid.tokenURI(1);
    }

    function test_MiddlewareNotSet_SetMiddleware_Success() public {
        assertEq(mid.middleware(), address(0));
        MockMiddleware middleware = new MockMiddleware();
        mid.setMiddleware(address(middleware), bytes("0x1234"));
        assertEq(mid.middleware(), address(middleware));
        assertEq(middleware.mwData(), bytes("0x1234"));

        mid.setMiddleware(address(0), "");
        assertEq(mid.middleware(), address(0));
    }

    function test_NameRegistered_SetMetadata_ReadSuccess() public {
        mid.register("alice", aliceAddress, "");

        uint256 tokenId = mid.getTokenId("alice");
        string memory avatarKey = "avatar";
        string
            memory avatarValue = "ipfs://Qmb5YRL6hjutLUF2dw5V5WGjQCip4e1WpRo8w3iFss4cWB";
        DataTypes.MetadataPair[]
            memory metadatas = new DataTypes.MetadataPair[](1);
        metadatas[0] = DataTypes.MetadataPair(avatarKey, avatarValue);
        mid.batchSetMetadatas(tokenId, metadatas);
        assertEq(avatarValue, mid.getMetadata(tokenId, avatarKey));
        metadatas[0] = DataTypes.MetadataPair(avatarKey, unicode"中文");
        mid.batchSetMetadatas(tokenId, metadatas);
        assertEq(unicode"中文", mid.getMetadata(tokenId, avatarKey));
    }

    function test_NameNotRegistered_SetMetadata_RevertInvalidToken() public {
        uint256 tokenId = mid.getTokenId("alice");
        string memory avatarKey = "avatar";
        string
            memory avatarValue = "ipfs://Qmb5YRL6hjutLUF2dw5V5WGjQCip4e1WpRo8w3iFss4cWB";
        DataTypes.MetadataPair[]
            memory metadatas = new DataTypes.MetadataPair[](1);
        metadatas[0] = DataTypes.MetadataPair(avatarKey, avatarValue);
        vm.expectRevert("ERC721: invalid token ID");
        mid.batchSetMetadatas(tokenId, metadatas);
    }

    function test_MetadataSet_ClearMetadata_ReadSuccess() public {
        mid.register("alice", aliceAddress, "");

        uint256 tokenId = mid.getTokenId("alice");
        DataTypes.MetadataPair[]
            memory metadatas = new DataTypes.MetadataPair[](2);
        metadatas[0] = DataTypes.MetadataPair("1", "1");
        metadatas[1] = DataTypes.MetadataPair("2", "2");
        mid.batchSetMetadatas(tokenId, metadatas);
        assertEq(mid.getMetadata(tokenId, "1"), "1");
        assertEq(mid.getMetadata(tokenId, "2"), "2");
        mid.clearMetadatas(tokenId);
        assertEq(mid.getMetadata(tokenId, "1"), "");
        assertEq(mid.getMetadata(tokenId, "2"), "");
    }

    function test_MetadataSet_ClearMetadataByOthers_RevertUnAuth() public {
        mid.register("alice", aliceAddress, "");

        uint256 tokenId = mid.getTokenId("alice");
        DataTypes.MetadataPair[]
            memory metadatas = new DataTypes.MetadataPair[](2);
        metadatas[0] = DataTypes.MetadataPair("1", "1");
        metadatas[1] = DataTypes.MetadataPair("2", "2");
        mid.batchSetMetadatas(tokenId, metadatas);
        assertEq(mid.getMetadata(tokenId, "1"), "1");
        assertEq(mid.getMetadata(tokenId, "2"), "2");
        vm.stopPrank();
        vm.startPrank(bobAddress);
        vm.expectRevert("METADATA_UNAUTHORISED");
        mid.clearMetadatas(tokenId);
        assertEq(mid.getMetadata(tokenId, "1"), "1");
        assertEq(mid.getMetadata(tokenId, "2"), "2");
    }

    function test_AliceIsOwner_BobUpgradeContract_ReverNotOwner() public {
        mid.register("alice", aliceAddress, "");
        vm.stopPrank();
        vm.startPrank(bobAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        mid.upgradeTo(address(0));
    }

    function test_NameRegistered_UpgradeContract_NameIsStillRegistered()
        public
    {
        mid.register("alice", aliceAddress, "");
        MocaId implV2 = new MocaId();
        mid.upgradeTo(address(implV2));
        assertEq(mid.ownerOf(mid.getTokenId("alice")), aliceAddress);
    }

    /* solhint-disable func-name-mixedcase */
}
