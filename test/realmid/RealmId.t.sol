// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { RealmIdTestBase } from "../utils/RealmIdTestBase.sol";
import { MockMiddleware } from "../utils/MockMiddleware.sol";
import { DataTypes } from "../../src/libraries/DataTypes.sol";
import { RealmId } from "../../src/core/RealmId.sol";

import "forge-std/console.sol";

/**
 * @dev All test names follow the pattern of "test_[GIVEN]_[WHEN]_[THEN]"
 */
contract RealmIdTest is RealmIdTestBase {
    /* solhint-disable func-name-mixedcase */
    function test_MiddlewareNotSet_CheckNameAvailable_Available() public {
        assertTrue(mid.available(unicode"alice", realmNode));
        assertTrue(mid.available(unicode"bob", realmNode));
        assertTrue(mid.available(unicode"bobb", realmNode));
        assertTrue(mid.available(unicode"三个字", realmNode));
        assertTrue(mid.available(unicode"四个字儿", realmNode));
        assertTrue(mid.available(unicode"😋😋😋", realmNode));
        assertTrue(mid.available(unicode"😋😋😋😋", realmNode));
        assertTrue(mid.available(unicode"    ", realmNode));
        assertTrue(mid.available(unicode"", realmNode));
        assertTrue(mid.available(unicode"bo", realmNode));
        assertTrue(mid.available(unicode"二字", realmNode));
        assertTrue(mid.available(unicode"😋😋", realmNode));
        assertTrue(mid.available("zerowidthcharacter\u200a\u200b", realmNode));
        assertTrue(mid.available("zerowidthcharacter\u200a\u200c", realmNode));
        assertTrue(mid.available("zerowidthcharacter\u200a\u200d", realmNode));
        assertTrue(mid.available("zerowidthcharacter\ufefe\ufeff", realmNode));
    }

    function test_NodeNotAllowed_CheckNameAvailable_NotAvailable() public {
        bytes32 musicNode = keccak256(
            abi.encodePacked(bytes32(0), keccak256(bytes("music")))
        );
        vm.expectRevert("NODE_NOT_ALLOWED");
        mid.available("alice", musicNode);
    }

    function test_NodeNotAllowed_AllowNodeAndCheckNameAvailable_Available()
        public
    {
        bytes32 musicNode = mid.allowNode(
            "music",
            bytes32(0),
            true,
            "",
            address(0),
            new bytes(0)
        );
        assertTrue(mid.available("alice", musicNode));
    }

    function test_MiddlewareNotSet_RegisterName_Success() public {
        string memory name = "test";

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
        mid.register(name, realmNode, aliceAddress, "");
    }

    function test_NameRegistered_RegisterAgain_RevertNameNotAvailable() public {
        string memory name = "test";
        mid.register(name, realmNode, aliceAddress, "");
        vm.expectRevert("NAME_NOT_AVAILABLE");
        mid.register(name, realmNode, aliceAddress, "");
    }

    function test_NameRegistered_QueryAvailable_NotAvailable() public {
        assertTrue(mid.available("test", realmNode));
        string memory name = "test";
        mid.register(name, realmNode, aliceAddress, "");
        assertFalse(mid.available("test", realmNode));
    }

    function test_NameRegistered_Transfer_RevertNowAllowed() public {
        string memory name = "test";
        uint256 tokenId = mid.register(name, realmNode, aliceAddress, "");
        vm.expectRevert("TRANSFER_NOT_ALLOWED");
        mid.transferFrom(aliceAddress, bobAddress, tokenId);
        vm.expectRevert("TRANSFER_NOT_ALLOWED");
        mid.safeTransferFrom(aliceAddress, bobAddress, tokenId);
        vm.expectRevert("TRANSFER_NOT_ALLOWED");
        mid.safeTransferFrom(aliceAddress, bobAddress, tokenId, "");
    }

    function test_Unpause_Transfer_Success() public {
        string memory name = "test";
        uint256 tokenId = mid.register(name, realmNode, aliceAddress, "");
        mid.unpause();
        mid.transferFrom(aliceAddress, bobAddress, tokenId);
        assertEq(mid.ownerOf(tokenId), bobAddress);

        vm.stopPrank();
        vm.startPrank(bobAddress);
        mid.safeTransferFrom(bobAddress, aliceAddress, tokenId);
        assertEq(mid.ownerOf(tokenId), aliceAddress);

        vm.stopPrank();
        vm.startPrank(aliceAddress);
        mid.safeTransferFrom(aliceAddress, bobAddress, tokenId, "");
        assertEq(mid.ownerOf(tokenId), bobAddress);
    }

    function test_UnpauseAndPause_Transfer_RevertNowAllowed() public {
        test_Unpause_Transfer_Success();
        mid.pause();
        string memory name = "test";
        uint256 tokenId = mid.getTokenId(name, realmNode);
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

        uint256 tokenId = mid.register(name, realmNode, aliceAddress, "");
        assertEq(1, mid.totalSupply());

        assertEq(0, mid.burnCounts(tokenId));
        vm.expectEmit(true, true, true, true);
        emit Burn(tokenId, 1);
        mid.burn(tokenId);
        assertEq(0, mid.totalSupply());
        assertEq(1, mid.burnCounts(tokenId));

        mid.register(name, realmNode, aliceAddress, "");
        assertEq(1, mid.totalSupply());

        vm.expectEmit(true, true, true, true);
        emit Burn(tokenId, 2);
        mid.burn(tokenId);
        assertEq(2, mid.burnCounts(tokenId));
    }

    function test_BaseUriNotSet_TokenUri_Success() public {
        uint256 tokenId = mid.register("alice", realmNode, aliceAddress, "");
        assertEq(
            mid.tokenURI(tokenId),
            "34381505080506270002041962522073071494230304175856376258432815400806256652646"
        );
    }

    function test_BaseUriSet_TokenUri_Success() public {
        uint256 tokenId = mid.register("alice", realmNode, aliceAddress, "");
        string memory baseUri = "https://api.cyberconnect.dev/";
        mid.setBaseTokenURI(realmNode, baseUri);
        assertEq(
            mid.tokenURI(tokenId),
            string(
                abi.encodePacked(
                    baseUri,
                    "34381505080506270002041962522073071494230304175856376258432815400806256652646"
                )
            )
        );
    }

    function test_TokenNotMinted_TokenUri_RevertInavlidTokenId() public {
        vm.expectRevert("INVALID_TOKEN_ID");
        mid.tokenURI(1);
    }

    function test_MiddlewareNotSet_SetMiddleware_Success() public {
        assertEq(mid.middlewares(realmNode), address(0));
        MockMiddleware middleware = new MockMiddleware();
        mid.setMiddleware(realmNode, address(middleware), bytes("0x1234"));
        assertEq(mid.middlewares(realmNode), address(middleware));
        assertEq(middleware.mwData(), bytes("0x1234"));

        mid.setMiddleware(realmNode, address(0), "");
        assertEq(mid.middlewares(realmNode), address(0));
    }

    function test_NameRegistered_SetMetadata_ReadSuccess() public {
        uint256 tokenId = mid.register("alice", realmNode, aliceAddress, "");

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
        uint256 tokenId = mid.getTokenId("alice", realmNode);
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
        uint256 tokenId = mid.register("alice", realmNode, aliceAddress, "");

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
        uint256 tokenId = mid.register("alice", realmNode, aliceAddress, "");

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

    function test_NameRegistered_SetGatedMetadata_ReadSuccess() public {
        uint256 tokenId = mid.register("alice", realmNode, aliceAddress, "");

        string memory avatarKey = "avatar";
        string
            memory avatarValue = "ipfs://Qmb5YRL6hjutLUF2dw5V5WGjQCip4e1WpRo8w3iFss4cWB";
        DataTypes.MetadataPair[]
            memory metadatas = new DataTypes.MetadataPair[](1);
        metadatas[0] = DataTypes.MetadataPair(avatarKey, avatarValue);
        mid.batchSetGatedMetadatas(tokenId, metadatas);
        assertEq(avatarValue, mid.getGatedMetadata(tokenId, avatarKey));
        metadatas[0] = DataTypes.MetadataPair(avatarKey, unicode"中文");
        mid.batchSetGatedMetadatas(tokenId, metadatas);
        assertEq(unicode"中文", mid.getGatedMetadata(tokenId, avatarKey));
    }

    function test_NameNotRegistered_SetGatedMetadata_RevertInvalidToken()
        public
    {
        uint256 tokenId = mid.getTokenId("alice", realmNode);
        string memory avatarKey = "avatar";
        string
            memory avatarValue = "ipfs://Qmb5YRL6hjutLUF2dw5V5WGjQCip4e1WpRo8w3iFss4cWB";
        DataTypes.MetadataPair[]
            memory metadatas = new DataTypes.MetadataPair[](1);
        metadatas[0] = DataTypes.MetadataPair(avatarKey, avatarValue);
        vm.expectRevert("TOKEN_NOT_MINTED");
        mid.batchSetGatedMetadatas(tokenId, metadatas);
    }

    function test_GatedMetadataSet_ClearGatedMetadata_ReadSuccess() public {
        uint256 tokenId = mid.register("alice", realmNode, aliceAddress, "");

        DataTypes.MetadataPair[]
            memory metadatas = new DataTypes.MetadataPair[](2);
        metadatas[0] = DataTypes.MetadataPair("1", "1");
        metadatas[1] = DataTypes.MetadataPair("2", "2");
        mid.batchSetGatedMetadatas(tokenId, metadatas);
        assertEq(mid.getGatedMetadata(tokenId, "1"), "1");
        assertEq(mid.getGatedMetadata(tokenId, "2"), "2");
        mid.clearGatedMetadatas(tokenId);
        assertEq(mid.getGatedMetadata(tokenId, "1"), "");
        assertEq(mid.getGatedMetadata(tokenId, "2"), "");
    }

    function test_GatedMetadataSet_ClearGatedMetadataByOthers_RevertUnAuth()
        public
    {
        uint256 tokenId = mid.register("alice", realmNode, aliceAddress, "");

        DataTypes.MetadataPair[]
            memory metadatas = new DataTypes.MetadataPair[](2);
        metadatas[0] = DataTypes.MetadataPair("1", "1");
        metadatas[1] = DataTypes.MetadataPair("2", "2");
        mid.batchSetGatedMetadatas(tokenId, metadatas);
        assertEq(mid.getGatedMetadata(tokenId, "1"), "1");
        assertEq(mid.getGatedMetadata(tokenId, "2"), "2");
        vm.stopPrank();
        vm.startPrank(bobAddress);
        vm.expectRevert("GATED_METADATA_UNAUTHORISED");
        mid.clearGatedMetadatas(tokenId);
        assertEq(mid.getGatedMetadata(tokenId, "1"), "1");
        assertEq(mid.getGatedMetadata(tokenId, "2"), "2");
    }

    function test_AliceIsOwner_BobUpgradeContract_ReverNotOwner() public {
        mid.register("alice", realmNode, aliceAddress, "");
        vm.stopPrank();
        vm.startPrank(bobAddress);
        vm.expectRevert("NOT_OWNER");
        mid.upgradeTo(address(0));
    }

    function test_NameRegistered_UpgradeContract_NameIsStillRegistered()
        public
    {
        mid.register("alice", realmNode, aliceAddress, "");
        RealmId implV2 = new RealmId();
        mid.upgradeTo(address(implV2));
        assertEq(mid.ownerOf(mid.getTokenId("alice", realmNode)), aliceAddress);
    }

    function test_CheckEIP137() public {
        bytes32 ethNode = mid.allowNode(
            "eth",
            bytes32(0),
            true,
            "",
            address(0),
            new bytes(0)
        );
        assertEq(
            ethNode,
            0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae
        );

        bytes32 cyberNode = mid.allowNode(
            "cyber",
            bytes32(0),
            true,
            "",
            address(0),
            new bytes(0)
        );
        assertEq(
            cyberNode,
            0x085ce9dbd6bf88d21613576ea20ed9c2c0f37a9f4d3608bc0d69f735e4d2d146
        );
    }

    /* solhint-disable func-name-mixedcase */
}
