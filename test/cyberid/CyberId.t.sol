// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import "forge-std/Test.sol";
import "../../src/core/CyberId.sol";
import { MockWallet } from "../utils/MockWallet.sol";
import { DataTypes } from "../../src/libraries/DataTypes.sol";
import { CyberIdTestBase } from "../utils/CyberIdTestBase.sol";
import { MockMiddleware } from "../utils/MockMiddleware.sol";
import { IAccessControlEnumerableUpgradeable } from "openzeppelin-upgradeable/contracts/access/IAccessControlEnumerableUpgradeable.sol";
import { IERC721Upgradeable } from "openzeppelin-upgradeable/contracts/token/ERC721/IERC721Upgradeable.sol";

/**
 * @dev All test names follow the pattern of "test_[GIVEN]_[WHEN]_[THEN]"
 */
contract CyberIdTest is CyberIdTestBase {
    /* solhint-disable func-name-mixedcase */
    function test_MiddlewareNotSet_CheckNameAvailable_Available() public {
        assertTrue(cid.available(unicode"alice"));
        assertTrue(cid.available(unicode"bob"));
        assertTrue(cid.available(unicode"bobb"));
        assertTrue(cid.available(unicode"三个字"));
        assertTrue(cid.available(unicode"四个字儿"));
        assertTrue(cid.available(unicode"😋😋😋"));
        assertTrue(cid.available(unicode"😋😋😋😋"));
        assertTrue(cid.available(unicode"    "));
        assertTrue(cid.available(unicode""));
        assertTrue(cid.available(unicode"bo"));
        assertTrue(cid.available(unicode"二字"));
        assertTrue(cid.available(unicode"😋😋"));
        assertTrue(cid.available("zerowidthcharacter\u200a\u200b"));
        assertTrue(cid.available("zerowidthcharacter\u200a\u200c"));
        assertTrue(cid.available("zerowidthcharacter\u200a\u200d"));
        assertTrue(cid.available("zerowidthcharacter\ufefe\ufeff"));
    }

    function test_RandomSecret_GenerateCommit_Success() public {
        // bytes32 secret = keccak256(abi.encodePacked(block.timestamp));
        bytes32 commit = cid.generateCommit("alice", aliceAddress, secret, "");
        assertEq(commit, commitment);
    }

    function test_GenerateCommit_Commit_CommitSuccess() public {
        cid.commit(commitment);
        assertEq(cid.timestampOf(commitment), startTs);
    }

    function test_Committed_CommitWithin10mins_RevertCommitReplay() public {
        cid.commit(commitment);
        vm.warp(startTs + 10 minutes);
        vm.expectRevert("COMMIT_REPLAY");
        cid.commit(commitment);
    }

    function test_Committed_CommitAfter10mins_CommitSuccess() public {
        cid.commit(commitment);
        vm.warp(startTs + 10 minutes + 1 seconds);
        cid.commit(commitment);
    }

    function test_NotCommitted_Register_RevertNotCommitted() public {
        vm.expectRevert("NOT_COMMITTED");
        cid.register("alice", aliceAddress, secret, "");
    }

    function test_CommitExpired_Register_RevertNotCommitted() public {
        cid.commit(commitment);
        vm.warp(startTs + 10 minutes + 1 seconds);
        vm.expectRevert("NOT_COMMITTED");
        cid.register("alice", aliceAddress, secret, "");
    }

    function test_Committed_RegisterWithin60Seconds_RevertTooQuick() public {
        cid.commit(commitment);
        vm.warp(startTs + 60 seconds);
        vm.expectRevert("REGISTER_TOO_QUICK");
        cid.register("alice", aliceAddress, secret, "");
    }

    function test_Registered_RegisterAgain_RevertNotCommitted() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register("alice", aliceAddress, secret, "");
        vm.expectRevert("NOT_COMMITTED");
        cid.register("alice", aliceAddress, secret, "");
    }

    function test_NameRegisteredByOthers_Register_RevertInvalidName() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register("alice", aliceAddress, secret, "");

        cid.commit(commitment);
        vm.warp(startTs + 61 seconds * 2);
        vm.expectRevert("ERC721: token already minted");
        cid.register("alice", aliceAddress, secret, "");
    }

    function test_Committed_Register_Success() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), aliceAddress, cid.getTokenId("alice"));
        vm.expectEmit(true, true, true, true);
        emit Register("alice", aliceAddress, cid.getTokenId("alice"), 0);
        cid.register("alice", aliceAddress, secret, "");
        assertEq(aliceAddress.balance, startBalance);
        assertEq(address(cid).balance, 0);
    }

    function test_Registered_Burn_Success() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register("alice", aliceAddress, secret, "");
        assertEq(cid.totalSupply(), 1);

        cid.burn(cid.getTokenId("alice"));
        assertEq(cid.totalSupply(), 0);
    }

    function test_Registered_BurnOthers_RevertUnauthorized() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register("alice", aliceAddress, secret, "");
        assertEq(cid.totalSupply(), 1);

        vm.startPrank(bobAddress);
        uint256 tokenId = cid.getTokenId("alice");
        vm.expectRevert("UNAUTHORIZED");
        cid.burn(tokenId);
    }

    function test_WithoutRole_BatchRegister_RevertUnauthorized() public {
        DataTypes.BatchRegisterCyberIdParams[]
            memory params = new DataTypes.BatchRegisterCyberIdParams[](2);
        params[0] = DataTypes.BatchRegisterCyberIdParams("alice", aliceAddress);
        params[1] = DataTypes.BatchRegisterCyberIdParams("bob", bobAddress);
        vm.startPrank(bobAddress);
        vm.expectRevert(
            "AccessControl: account 0x440d9ab59a4ed2f575666c23ef8c17c53a96e3e0 is missing role 0x97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b929"
        );
        cid.batchRegister(params);
    }

    function test_WithRole_BatchRegister_RevertUnauthorized() public {
        DataTypes.BatchRegisterCyberIdParams[]
            memory params = new DataTypes.BatchRegisterCyberIdParams[](2);
        params[0] = DataTypes.BatchRegisterCyberIdParams("alice", aliceAddress);
        params[1] = DataTypes.BatchRegisterCyberIdParams("bob", bobAddress);
        cid.batchRegister(params);
        assertEq(cid.ownerOf(cid.getTokenId("alice")), aliceAddress);
        assertEq(cid.ownerOf(cid.getTokenId("bob")), bobAddress);
    }

    function test_SupportsInterface_IAccessControlEnumerableUpgradeable_Success()
        public
    {
        assertTrue(
            cid.supportsInterface(
                type(IAccessControlEnumerableUpgradeable).interfaceId
            )
        );
    }

    function test_SupportsInterface_IERC721Upgradeable_Success() public {
        assertTrue(cid.supportsInterface(type(IERC721Upgradeable).interfaceId));
    }

    function test_NotRegistered_OwnerOf_RevertInvalidTokenId() public {
        uint256 tokenId = cid.getTokenId("alice");
        vm.expectRevert("ERC721: invalid token ID");
        cid.ownerOf(tokenId);
    }

    function test_Registered_OwnerOf_Success() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, secret, "");

        assertEq(cid.ownerOf(cid.getTokenId("alice")), aliceAddress);
    }

    function test_NotRegistered_SafeTransferFrom_RevertInvalidToken() public {
        uint256 tokenId = cid.getTokenId("alice");
        cid.unpause();
        vm.expectRevert("ERC721: invalid token ID");
        cid.safeTransferFrom(aliceAddress, bobAddress, tokenId, "");
    }

    function test_Registered_SafeTransferFrom_Success() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, secret, "");

        uint256 tokenId = cid.getTokenId("alice");
        cid.unpause();
        vm.expectEmit(true, true, true, true);
        emit Transfer(aliceAddress, bobAddress, tokenId);
        cid.safeTransferFrom(aliceAddress, bobAddress, tokenId, "");
    }

    function test_RegisteredButPaused_SafeTransferFrom_RevertNotAllowed()
        public
    {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, secret, "");

        uint256 tokenId = cid.getTokenId("alice");
        vm.expectRevert("TRANSFER_NOT_ALLOWED");
        cid.safeTransferFrom(aliceAddress, bobAddress, tokenId, "");
    }

    function test_RegisteredButPaused_UnpauseAndPause_RevertNotAllowed()
        public
    {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, secret, "");

        uint256 tokenId = cid.getTokenId("alice");
        cid.unpause();
        vm.expectEmit(true, true, true, true);
        emit Transfer(aliceAddress, bobAddress, tokenId);
        cid.safeTransferFrom(aliceAddress, bobAddress, tokenId, "");
        vm.startPrank(bobAddress);
        cid.safeTransferFrom(bobAddress, aliceAddress, tokenId, "");

        vm.startPrank(aliceAddress);
        cid.pause();
        vm.expectRevert("TRANSFER_NOT_ALLOWED");
        cid.safeTransferFrom(aliceAddress, bobAddress, tokenId, "");
    }

    function test_NotRegistered_SafeTransferFrom2_RevertInvalidToken() public {
        uint256 tokenId = cid.getTokenId("alice");
        cid.unpause();
        vm.expectRevert("ERC721: invalid token ID");
        cid.safeTransferFrom(aliceAddress, bobAddress, tokenId);
    }

    function test_Registered_SafeTransferFrom2_Success() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, secret, "");

        uint256 tokenId = cid.getTokenId("alice");
        cid.unpause();
        vm.expectEmit(true, true, true, true);
        emit Transfer(aliceAddress, bobAddress, tokenId);
        cid.safeTransferFrom(aliceAddress, bobAddress, tokenId);
    }

    function test_NotRegistered_TransferFrom_RevertInvalidToken() public {
        uint256 tokenId = cid.getTokenId("alice");
        cid.unpause();
        vm.expectRevert("ERC721: invalid token ID");
        cid.transferFrom(aliceAddress, bobAddress, tokenId);
    }

    function test_Registered_TransferFrom_Success() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, secret, "");

        uint256 tokenId = cid.getTokenId("alice");
        cid.unpause();
        vm.expectEmit(true, true, true, true);
        emit Transfer(aliceAddress, bobAddress, tokenId);
        cid.transferFrom(aliceAddress, bobAddress, tokenId);
    }

    function test_BaseUriNotSet_TokenUri_Success() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, secret, "");

        uint256 tokenId = cid.getTokenId("alice");
        assertEq(
            cid.tokenURI(tokenId),
            "0x9c0257114eb9399a2985f8e75dad7600c5d89fe3824ffa99ec1c3eb8bf3b0501"
        );
    }

    function test_BaseUriSet_TokenUri_Success() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, secret, "");
        string memory baseUri = "https://api.cyberconnect.dev/";
        cid.setBaseTokenURI(baseUri);
        uint256 tokenId = cid.getTokenId("alice");
        assertEq(
            cid.tokenURI(tokenId),
            string(
                abi.encodePacked(
                    baseUri,
                    "0x9c0257114eb9399a2985f8e75dad7600c5d89fe3824ffa99ec1c3eb8bf3b0501"
                )
            )
        );
    }

    function test_NameRegistered_SetMetadata_ReadSuccess() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, secret, "");

        uint256 tokenId = cid.getTokenId("alice");
        string memory avatarKey = "avatar";
        string
            memory avatarValue = "ipfs://Qmb5YRL6hjutLUF2dw5V5WGjQCip4e1WpRo8w3iFss4cWB";
        DataTypes.MetadataPair[]
            memory metadatas = new DataTypes.MetadataPair[](1);
        metadatas[0] = DataTypes.MetadataPair(avatarKey, avatarValue);
        cid.batchSetMetadatas(tokenId, metadatas);
        assertEq(avatarValue, cid.getMetadata(tokenId, avatarKey));
        metadatas[0] = DataTypes.MetadataPair(avatarKey, unicode"中文");
        cid.batchSetMetadatas(tokenId, metadatas);
        assertEq(unicode"中文", cid.getMetadata(tokenId, avatarKey));
    }

    function test_NameNotRegistered_SetMetadata_RevertInvalidToken() public {
        uint256 tokenId = cid.getTokenId("alice");
        string memory avatarKey = "avatar";
        string
            memory avatarValue = "ipfs://Qmb5YRL6hjutLUF2dw5V5WGjQCip4e1WpRo8w3iFss4cWB";
        DataTypes.MetadataPair[]
            memory metadatas = new DataTypes.MetadataPair[](1);
        metadatas[0] = DataTypes.MetadataPair(avatarKey, avatarValue);
        vm.expectRevert("ERC721: invalid token ID");
        cid.batchSetMetadatas(tokenId, metadatas);
    }

    function test_MetadataSet_ClearMetadata_ReadSuccess() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, secret, "");

        uint256 tokenId = cid.getTokenId("alice");
        DataTypes.MetadataPair[]
            memory metadatas = new DataTypes.MetadataPair[](2);
        metadatas[0] = DataTypes.MetadataPair("1", "1");
        metadatas[1] = DataTypes.MetadataPair("2", "2");
        cid.batchSetMetadatas(tokenId, metadatas);
        assertEq(cid.getMetadata(tokenId, "1"), "1");
        assertEq(cid.getMetadata(tokenId, "2"), "2");
        cid.clearMetadatas(tokenId);
        assertEq(cid.getMetadata(tokenId, "1"), "");
        assertEq(cid.getMetadata(tokenId, "2"), "");
    }

    function test_MetadataSet_ClearMetadataByOthers_RevertUnAuth() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, secret, "");

        uint256 tokenId = cid.getTokenId("alice");
        DataTypes.MetadataPair[]
            memory metadatas = new DataTypes.MetadataPair[](2);
        metadatas[0] = DataTypes.MetadataPair("1", "1");
        metadatas[1] = DataTypes.MetadataPair("2", "2");
        cid.batchSetMetadatas(tokenId, metadatas);
        assertEq(cid.getMetadata(tokenId, "1"), "1");
        assertEq(cid.getMetadata(tokenId, "2"), "2");
        vm.stopPrank();
        vm.startPrank(bobAddress);
        vm.expectRevert("METADATA_UNAUTHORISED");
        cid.clearMetadatas(tokenId);
        assertEq(cid.getMetadata(tokenId, "1"), "1");
        assertEq(cid.getMetadata(tokenId, "2"), "2");
    }

    function test_MiddlewareNotSet_SetMiddleware_Success() public {
        MockMiddleware middleware = new MockMiddleware();
        cid.setMiddleware(address(middleware), bytes("0x1234"));
        assertEq(cid.middleware(), address(middleware));
        assertEq(middleware.mwData(), bytes("0x1234"));

        vm.expectRevert("ZERO_MIDDLEWARE");
        cid.setMiddleware(address(0), "");
    }

    /* solhint-disable func-name-mixedcase */
}
