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

    function test_Committed_CommitWithin1Day_RevertCommitReplay() public {
        cid.commit(commitment);
        vm.warp(startTs + 10 minutes);
        vm.expectRevert("COMMIT_REPLAY");
        cid.commit(commitment);
    }

    function test_Committed_CommitAfter1Day_CommitSuccess() public {
        cid.commit(commitment);
        vm.warp(startTs + 1 days + 1 seconds);
        cid.commit(commitment);
    }

    function test_NotCommitted_Register_RevertNotCommitted() public {
        vm.expectRevert("NOT_COMMITTED");
        cid.register("alice", aliceAddress, secret, "");
    }

    function test_CommitExpired_Register_RevertNotCommitted() public {
        cid.commit(commitment);
        vm.warp(startTs + 1 days + 1 seconds);
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
        emit Register(
            aliceAddress,
            aliceAddress,
            cid.getTokenId("alice"),
            "alice",
            0
        );
        cid.register("alice", aliceAddress, secret, "");
        assertEq(aliceAddress.balance, startBalance);
        assertEq(address(cid).balance, 0);

        bytes32 node = bytes32(cid.getTokenId("alice"));
        assertEq(registry.owner(node), aliceAddress);
        assertEq(registry.resolver(node), address(resolver));
        assertEq(resolver.addr(node), aliceAddress);
    }

    function test_Registered_Burn_Success() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register("alice", aliceAddress, secret, "");
        assertEq(cid.totalSupply(), 1);

        cid.burn("alice");
        assertEq(cid.totalSupply(), 0);

        bytes32 node = bytes32(cid.getTokenId("alice"));
        assertEq(registry.owner(node), address(0));
        assertEq(registry.resolver(node), address(resolver));
        assertEq(resolver.addr(node), address(0));
    }

    function test_Registered_Transfer_RecordUpdated() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register("alice", aliceAddress, secret, "");
        assertEq(cid.totalSupply(), 1);

        cid.unpause();
        cid.transferFrom(aliceAddress, bobAddress, cid.getTokenId("alice"));

        bytes32 node = bytes32(cid.getTokenId("alice"));
        assertEq(registry.owner(node), bobAddress);
        assertEq(registry.resolver(node), address(resolver));
        assertEq(resolver.addr(node), bobAddress);
    }

    function test_ResolverUpdated_Transfer_ZeroResolver() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register("alice", aliceAddress, secret, "");
        assertEq(cid.totalSupply(), 1);

        bytes32 node = bytes32(cid.getTokenId("alice"));
        registry.setResolver(node, address(0x12345));

        cid.unpause();
        cid.transferFrom(aliceAddress, bobAddress, uint256(node));

        assertEq(registry.owner(node), bobAddress);
        assertEq(registry.resolver(node), address(0));
        assertEq(resolver.addr(node), aliceAddress);
    }

    function test_Registered_BurnOthers_RevertUnauthorized() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register("alice", aliceAddress, secret, "");
        assertEq(cid.totalSupply(), 1);

        vm.startPrank(bobAddress);
        vm.expectRevert("UNAUTHORIZED");
        cid.burn("alice");
    }

    function test_WithoutRole_BatchRegister_RevertUnauthorized() public {
        DataTypes.BatchRegisterCyberIdParams[]
            memory params = new DataTypes.BatchRegisterCyberIdParams[](2);
        params[0] = DataTypes.BatchRegisterCyberIdParams(
            "alice",
            aliceAddress,
            address(0)
        );
        params[1] = DataTypes.BatchRegisterCyberIdParams(
            "bob",
            bobAddress,
            address(0)
        );
        vm.startPrank(bobAddress);
        vm.expectRevert(
            "AccessControl: account 0x440d9ab59a4ed2f575666c23ef8c17c53a96e3e0 is missing role 0x97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b929"
        );
        cid.batchRegister(params);
    }

    function test_MintForOthers_ReverseResolve_NameNotSet() public {
        bytes32 commitment2 = cid.generateCommit(
            "alice",
            bobAddress,
            secret,
            ""
        );
        cid.commit(commitment2);
        vm.warp(startTs + 61 seconds);
        cid.register("alice", bobAddress, secret, "");
        bytes32 node = bytes32(cid.getTokenId("alice"));

        assertEq(registry.owner(node), bobAddress);
        assertEq(registry.resolver(node), address(resolver));
        assertEq(resolver.addr(node), bobAddress);

        bytes32 reverseNode = reverseRegistrar.node(bobAddress);
        assertEq(registry.owner(reverseNode), address(0));
        assertEq(registry.resolver(reverseNode), address(0));
    }

    function test_MintForSelf_ReverseResolve_OnlySetOnce() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register("alice", aliceAddress, secret, "");
        bytes32 node = bytes32(cid.getTokenId("alice"));

        assertEq(registry.owner(node), aliceAddress);
        assertEq(registry.resolver(node), address(resolver));
        assertEq(resolver.addr(node), aliceAddress);

        bytes32 reverseNode = reverseRegistrar.node(aliceAddress);
        assertEq(registry.owner(reverseNode), aliceAddress);
        assertEq(registry.resolver(reverseNode), address(resolver));
        assertEq(resolver.name(reverseNode), "alice.cyber");

        bytes32 commitment2 = cid.generateCommit(
            "alice2",
            aliceAddress,
            secret,
            ""
        );
        cid.commit(commitment2);
        vm.warp(startTs + 61 seconds + 61 seconds);
        cid.register("alice2", aliceAddress, secret, "");

        bytes32 node2 = bytes32(cid.getTokenId("alice2"));

        assertEq(registry.owner(node2), aliceAddress);
        assertEq(registry.resolver(node2), address(resolver));
        assertEq(resolver.addr(node2), aliceAddress);

        bytes32 reverseNode2 = reverseRegistrar.node(aliceAddress);
        assertEq(registry.owner(reverseNode2), aliceAddress);
        assertEq(registry.resolver(reverseNode2), address(resolver));
        assertEq(resolver.name(reverseNode2), "alice.cyber");
    }

    function test_WithRole_BatchRegister_Success() public {
        DataTypes.BatchRegisterCyberIdParams[]
            memory params = new DataTypes.BatchRegisterCyberIdParams[](2);
        params[0] = DataTypes.BatchRegisterCyberIdParams(
            "alice",
            aliceAddress,
            address(0)
        );
        params[1] = DataTypes.BatchRegisterCyberIdParams(
            "bob",
            bobAddress,
            address(0)
        );
        cid.batchRegister(params);
        assertEq(cid.ownerOf(cid.getTokenId("alice")), aliceAddress);
        assertEq(cid.ownerOf(cid.getTokenId("bob")), bobAddress);

        bytes32 reverseNode = keccak256(
            abi.encodePacked(
                bytes32(
                    0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2
                ),
                keccak256(bytes("1cc0c65ca5dd6b767338946f2c44c02040744ef5"))
            )
        );
        assertEq(registry.owner(reverseNode), aliceAddress);
        assertEq(registry.resolver(reverseNode), address(resolver));
        assertEq(resolver.name(reverseNode), "alice.cyber");
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
            "0xf274ad8930852a6a62f907d26d6aa10156d2bb37471f229eda0f557c74069d83"
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
                    "0xf274ad8930852a6a62f907d26d6aa10156d2bb37471f229eda0f557c74069d83"
                )
            )
        );
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
