// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import "forge-std/Test.sol";
import "../../src/core/CyberId.sol";
import { MockWallet } from "../utils/MockWallet.sol";
import { DataTypes } from "../../src/libraries/DataTypes.sol";
import { CyberIdTestBase } from "../utils/CyberIdTestBase.sol";

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
        cid.register("alice", aliceAddress, secret, 1, "");
    }

    function test_CommitExpired_Register_RevertNotCommitted() public {
        cid.commit(commitment);
        vm.warp(startTs + 10 minutes + 1 seconds);
        vm.expectRevert("NOT_COMMITTED");
        cid.register("alice", aliceAddress, secret, 1, "");
    }

    function test_Committed_RegisterWithin60Seconds_RevertTooQuick() public {
        cid.commit(commitment);
        vm.warp(startTs + 60 seconds);
        vm.expectRevert("REGISTER_TOO_QUICK");
        cid.register("alice", aliceAddress, secret, 1, "");
    }

    function test_Committed_WrongDurationRegister_RevertWrongDuration() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        vm.expectRevert("MIN_DURATION_ONE_YEAR");
        cid.register("alice", aliceAddress, secret, 0, "");
    }

    function test_Registered_RegisterAgain_RevertNotCommitted() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register("alice", aliceAddress, secret, 1, "");
        vm.expectRevert("NOT_COMMITTED");
        cid.register("alice", aliceAddress, secret, 1, "");
    }

    function test_NameRegisteredByOthers_Register_RevertInvalidName() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register("alice", aliceAddress, secret, 1, "");

        cid.commit(commitment);
        vm.warp(startTs + 61 seconds * 2);
        vm.expectRevert("INVALID_NAME");
        cid.register("alice", aliceAddress, secret, 1, "");
    }

    function test_NameExpired_Register_RevertTokenExists() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register("alice", aliceAddress, secret, 1, "");

        vm.warp(startTs + 61 seconds + 365 days + 30 days);
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds + 365 days + 30 days + 61 seconds);
        vm.expectRevert("ERC721: token already minted");
        cid.register("alice", aliceAddress, secret, 1, "");
    }

    function test_Committed_Register_Success() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), aliceAddress, cid.getTokenId("alice"));
        vm.expectEmit(true, true, true, true);
        emit Register(
            "alice",
            aliceAddress,
            startTs + 61 seconds + 365 days,
            0
        );
        cid.register("alice", aliceAddress, secret, 1, "");
        assertEq(aliceAddress.balance, startBalance);
        assertEq(address(cid).balance, 0);
    }

    function test_NotRegistered_Renew_RevertNotRegistered() public {
        vm.expectRevert("NOT_REGISTERED");
        cid.renew("alice", 1, "");
    }

    function test_Registered_AfterGracePeriodRenew_RevertNotRenewable() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, secret, 1, "");

        vm.warp(startTs + 61 seconds + 365 days + 30 days);
        vm.expectRevert("NOT_RENEWABLE");
        cid.renew("alice", 1, "");
    }

    function test_Registered_WithinGracePeriodRenew_NameRenewed() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, secret, 1, "");

        uint256 newExpiry = startTs + 61 seconds + 365 days + 365 days;
        vm.warp(startTs + 61 seconds + 365 days + 30 days - 1 seconds);
        vm.expectEmit(true, true, true, true);
        emit Renew("alice", newExpiry, 0);
        cid.renew{ value: 1 ether }("alice", 1, "");
        assertEq(cid.expiries(cid.getTokenId("alice")), newExpiry);
        assertEq(aliceAddress.balance, startBalance - 2 ether);
        assertEq(address(cid).balance, 2 ether);
    }

    function test_NorRegistered_Bid_RevertNotRegistered() public {
        vm.expectRevert("NOT_REGISTERED");
        cid.bid(aliceAddress, "alice", "");
    }

    function test_NameWithinGracePeriod_Bid_RevertNotBiddable() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, secret, 1, "");

        vm.warp(startTs + 61 seconds + 365 days + 30 days - 1 seconds);
        vm.expectRevert("NOT_BIDDABLE");
        cid.bid(aliceAddress, "alice", "");
    }

    function test_NotRegistered_OwnerOf_RevertInvalidTokenId() public {
        uint256 tokenId = cid.getTokenId("alice");
        vm.expectRevert("ERC721: invalid token ID");
        cid.ownerOf(tokenId);
    }

    function test_Registered_OwnerOf_Success() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, secret, 1, "");

        assertEq(cid.ownerOf(cid.getTokenId("alice")), aliceAddress);
    }

    function test_Registered_ExpiredOwnerOf_RevertExpired() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, secret, 1, "");

        vm.warp(startTs + 61 seconds + 365 days);
        uint256 tokenId = cid.getTokenId("alice");
        vm.expectRevert("EXPIRED");
        cid.ownerOf(tokenId);
    }

    function test_NotRegistered_SafeTransferFrom_RevertInvalidToken() public {
        uint256 tokenId = cid.getTokenId("alice");
        vm.expectRevert("ERC721: invalid token ID");
        cid.safeTransferFrom(aliceAddress, bobAddress, tokenId, "");
    }

    function test_Registered_SafeTransferFrom_Success() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, secret, 1, "");

        uint256 tokenId = cid.getTokenId("alice");
        vm.expectEmit(true, true, true, true);
        emit Transfer(aliceAddress, bobAddress, tokenId);
        cid.safeTransferFrom(aliceAddress, bobAddress, tokenId, "");
    }

    function test_NameExpired_SafeTransferFrom_RevertExpired() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, secret, 1, "");

        vm.warp(startTs + 61 seconds + 365 days);
        uint256 tokenId = cid.getTokenId("alice");
        vm.expectRevert("EXPIRED");
        cid.safeTransferFrom(aliceAddress, bobAddress, tokenId, "");
    }

    function test_NotRegistered_SafeTransferFrom2_RevertInvalidToken() public {
        uint256 tokenId = cid.getTokenId("alice");
        vm.expectRevert("ERC721: invalid token ID");
        cid.safeTransferFrom(aliceAddress, bobAddress, tokenId);
    }

    function test_Registered_SafeTransferFrom2_Success() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, secret, 1, "");

        uint256 tokenId = cid.getTokenId("alice");
        vm.expectEmit(true, true, true, true);
        emit Transfer(aliceAddress, bobAddress, tokenId);
        cid.safeTransferFrom(aliceAddress, bobAddress, tokenId);
    }

    function test_NameExpired_SafeTransferFrom2_RevertExpired() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, secret, 1, "");

        vm.warp(startTs + 61 seconds + 365 days);
        uint256 tokenId = cid.getTokenId("alice");
        vm.expectRevert("EXPIRED");
        cid.safeTransferFrom(aliceAddress, bobAddress, tokenId);
    }

    function test_NotRegistered_TransferFrom_RevertInvalidToken() public {
        uint256 tokenId = cid.getTokenId("alice");
        vm.expectRevert("ERC721: invalid token ID");
        cid.transferFrom(aliceAddress, bobAddress, tokenId);
    }

    function test_NameExpired_TransferFrom_RevertExpired() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, secret, 1, "");

        vm.warp(startTs + 61 seconds + 365 days);
        uint256 tokenId = cid.getTokenId("alice");
        vm.expectRevert("EXPIRED");
        cid.transferFrom(aliceAddress, bobAddress, tokenId);
    }

    function test_Registered_TransferFrom_Success() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, secret, 1, "");

        uint256 tokenId = cid.getTokenId("alice");
        vm.expectEmit(true, true, true, true);
        emit Transfer(aliceAddress, bobAddress, tokenId);
        cid.transferFrom(aliceAddress, bobAddress, tokenId);
    }

    function test_BaseUriNotSet_TokenUri_Success() public {
        uint256 tokenId = cid.getTokenId("alice");
        assertEq(
            cid.tokenURI(tokenId),
            "0x9c0257114eb9399a2985f8e75dad7600c5d89fe3824ffa99ec1c3eb8bf3b0501"
        );
    }

    function test_BaseUriSet_TokenUri_Success() public {
        string memory baseUri = "https://api.cyberconnect.dev/";
        cid.setBaseTokenUri(baseUri);
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
        cid.register{ value: 1 ether }("alice", aliceAddress, secret, 1, "");

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

    function test_NameExpired_SetMetadata_RevertExpired() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, secret, 1, "");

        uint256 tokenId = cid.getTokenId("alice");
        string memory avatarKey = "avatar";
        string
            memory avatarValue = "ipfs://Qmb5YRL6hjutLUF2dw5V5WGjQCip4e1WpRo8w3iFss4cWB";
        DataTypes.MetadataPair[]
            memory metadatas = new DataTypes.MetadataPair[](1);
        metadatas[0] = DataTypes.MetadataPair(avatarKey, avatarValue);
        vm.warp(startTs + 61 seconds + 365 days);
        vm.expectRevert("EXPIRED");
        cid.batchSetMetadatas(tokenId, metadatas);
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
        cid.register{ value: 1 ether }("alice", aliceAddress, secret, 1, "");

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
        cid.register{ value: 1 ether }("alice", aliceAddress, secret, 1, "");

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

    /* solhint-disable func-name-mixedcase */
}
