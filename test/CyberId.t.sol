// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import "forge-std/Test.sol";
import "../src/core/CyberId.sol";
import { MockUsdOracle } from "./utils/MockUsdOracle.sol";
import { MockWallet } from "./utils/MockWallet.sol";
import { DataTypes } from "../src/libraries/DataTypes.sol";

/**
 * @dev All test names follow the pattern of "test_[GIVEN]_[WHEN]_[THEN]"
 */
contract CyberIdTest is Test {
    CyberId public cid;
    address public aliceAddress =
        address(0x2E0446079705B6Bacc4730fB3EDA5DA68aE5Fe4D);
    address public bobAddress =
        address(0x5617FEC489c0295C565626e45ed77F2265c283C6);
    address public mockWalletAddress;
    bytes32 public commitment =
        0xeef54eed8da56e808443372ffeab4d7b46043e6db8aa8b3cd9de5f5340ec1f2b;
    bytes32 public secret =
        0x0eefdc6e193f9cbd5f64811cd42779ce2e472065df02ecb9db84d8b7e11951ca;
    // 2023-05-22T17:25:30
    uint256 public startTs = 1684747530;
    uint256 public startBalance = 2000 ether;

    event Register(
        string cid,
        address indexed to,
        uint256 expiry,
        uint256 cost
    );
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );
    event Renew(string cid, uint256 expiry, uint256 cost);
    event Bid(string cid, uint256 expiry, uint256 cost);

    function setUp() public {
        vm.startPrank(aliceAddress);
        MockUsdOracle usdOracle = new MockUsdOracle();
        MockWallet mockWallet = new MockWallet();
        mockWalletAddress = address(mockWallet);
        cid = new CyberId("CYBER ID", "CYBERID", address(usdOracle));
        // set timestamp to startTs
        vm.warp(startTs);
        vm.deal(aliceAddress, startBalance);
        vm.deal(mockWalletAddress, startBalance);
    }

    /* solhint-disable func-name-mixedcase */
    function test_NameNotRegistered_CheckNameAvailable_Available() public {
        assertTrue(cid.available(unicode"alice"));
        assertTrue(cid.available(unicode"bob"));
        assertTrue(cid.available(unicode"bobb"));
        assertTrue(cid.available(unicode"三个字"));
        assertTrue(cid.available(unicode"四个字儿"));
        assertTrue(cid.available(unicode"😋😋😋"));
        assertTrue(cid.available(unicode"😋😋😋😋"));
        assertTrue(cid.available(unicode"    "));
    }

    function test_NameNotRegistered_CheckNameAvailable_NotAvailable() public {
        assertFalse(cid.available(unicode""));
        assertFalse(cid.available(unicode"bo"));
        assertFalse(cid.available(unicode"二字"));
        assertFalse(cid.available(unicode"😋😋"));
        assertFalse(cid.available("zerowidthcharacter\u200a\u200b"));
        assertFalse(cid.available("zerowidthcharacter\u200a\u200c"));
        assertFalse(cid.available("zerowidthcharacter\u200a\u200d"));
        assertFalse(cid.available("zerowidthcharacter\ufefe\ufeff"));
    }

    function test_RandomSecret_GenerateCommit_Success() public {
        // bytes32 secret = keccak256(abi.encodePacked(block.timestamp));
        bytes32 commit = cid.generateCommit("alice", aliceAddress, 1, secret);
        assertEq(commit, commitment);
    }

    function test_ContractDeployed_Commit_CommitSuccess() public {
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
        cid.register("alice", aliceAddress, 1, secret, 1);
    }

    function test_CommitExpired_Register_RevertNotCommitted() public {
        cid.commit(commitment);
        vm.warp(startTs + 10 minutes + 1 seconds);
        vm.expectRevert("NOT_COMMITTED");
        cid.register("alice", aliceAddress, 1, secret, 1);
    }

    function test_Committed_RegisterWithin60Seconds_RevertTooQuick() public {
        cid.commit(commitment);
        vm.warp(startTs + 60 seconds);
        vm.expectRevert("REGISTER_TOO_QUICK");
        cid.register("alice", aliceAddress, 1, secret, 1);
    }

    function test_Committed_WrongDurationRegister_RevertWrongDuration() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        vm.expectRevert("MIN_DURATION_ONE_YEAR");
        cid.register("alice", aliceAddress, 1, secret, 0);
    }

    function test_Registered_RegisterAgain_RevertNotCommitted() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);
        vm.expectRevert("NOT_COMMITTED");
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);
    }

    function test_Committed_RegisterWithInsufficientFunds_RevertInsufficientFunds()
        public
    {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        uint256 cost = cid.getPriceWeiAt("alice", 1, 1);
        vm.expectRevert("INSUFFICIENT_FUNDS");
        cid.register{ value: cost - 1 wei }(
            "alice",
            aliceAddress,
            1,
            secret,
            1
        );
    }

    function test_NameRegisteredByOthers_Register_RevertInvalidName() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);

        cid.commit(commitment);
        vm.warp(startTs + 61 seconds * 2);
        vm.expectRevert("INVALID_NAME");
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);
    }

    function test_NameExpired_Register_RevertTokenExists() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);

        vm.warp(startTs + 61 seconds + 365 days + 30 days);
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds + 365 days + 30 days + 61 seconds);
        vm.expectRevert("ERC721: token already minted");
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);
    }

    function test_Committed_Register_Success() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        uint256 cost = cid.getPriceWeiAt("alice", 1, 1);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), aliceAddress, cid.getTokenId("alice"));
        vm.expectEmit(true, true, true, true);
        emit Register(
            "alice",
            aliceAddress,
            startTs + 61 seconds + 365 days,
            cost
        );
        cid.register{ value: cost * 1 wei }(
            "alice",
            aliceAddress,
            1,
            secret,
            1
        );
        assertEq(aliceAddress.balance, startBalance - cost);
        assertEq(address(cid).balance, cost);
    }

    function test_Committed_RegisterToWrongWallet_RevertRefundFail() public {
        vm.stopPrank();
        vm.startPrank(mockWalletAddress);
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        uint256 cost = cid.getPriceWeiAt("alice", 1, 1);
        vm.expectRevert("REFUND_FAILED");
        cid.register{ value: cost * 1 wei + 1 ether }(
            "alice",
            aliceAddress,
            1,
            secret,
            1
        );
    }

    function test_Committed_RegisterWithOverPay_Refund() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        uint256 cost = cid.getPriceWeiAt("alice", 1, 1);
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), aliceAddress, cid.getTokenId("alice"));
        vm.expectEmit(true, true, true, true);
        emit Register(
            "alice",
            aliceAddress,
            startTs + 61 seconds + 365 days,
            cost
        );
        cid.register{ value: startBalance }(
            "alice",
            aliceAddress,
            1,
            secret,
            1
        );
        assertEq(aliceAddress.balance, startBalance - cost);
        assertEq(address(cid).balance, cost);
    }

    function test_NotRegistered_RenewWithInsufficientFunds_RevertInsufficientFunds()
        public
    {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);

        vm.warp(startTs + 61 seconds + 365 days + 30 days - 1 seconds);
        uint256 cost = cid.getPriceWei("alice", 1);
        vm.expectRevert("INSUFFICIENT_FUNDS");
        cid.renew{ value: cost - 1 wei }("alice", 1);
    }

    function test_NotRegistered_Renew_RevertNotRegistered() public {
        vm.expectRevert("NOT_REGISTERED");
        cid.renew("alice", 1);
    }

    function test_Registered_AfterGracePeriodRenew_RevertNotRenewable() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);

        vm.warp(startTs + 61 seconds + 365 days + 30 days);
        vm.expectRevert("NOT_RENEWABLE");
        cid.renew("alice", 1);
    }

    function test_Registered_WithinGracePeriodRenew_NameRenewed() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);
        uint256 registerCost = cid.getPriceWeiAt("alice", 1, 1);

        uint256 renewCost = cid.getPriceWei("alice", 1);
        uint256 newExpiry = startTs + 61 seconds + 365 days + 365 days;
        vm.warp(startTs + 61 seconds + 365 days + 30 days - 1 seconds);
        vm.expectEmit(true, true, true, true);
        emit Renew("alice", newExpiry, renewCost);
        cid.renew{ value: 1 ether }("alice", 1);
        assertEq(cid.expiries(cid.getTokenId("alice")), newExpiry);
        assertEq(aliceAddress.balance, startBalance - registerCost - renewCost);
        assertEq(address(cid).balance, registerCost + renewCost);
    }

    function test_Registered_RenewWithWrongWallet_RevertRefundFail() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);

        vm.stopPrank();
        vm.startPrank(mockWalletAddress);
        vm.warp(startTs + 61 seconds + 365 days + 30 days - 1 seconds);
        vm.expectRevert("REFUND_FAILED");
        cid.renew{ value: 1 ether }("alice", 1);
    }

    function test_NorRegistered_Bid_RevertNotRegistered() public {
        vm.expectRevert("NOT_REGISTERED");
        cid.bid(aliceAddress, "alice");
    }

    function test_NameWithinGracePeriod_Bid_RevertNotBiddable() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);

        vm.warp(startTs + 61 seconds + 365 days + 30 days - 1 seconds);
        vm.expectRevert("NOT_BIDDABLE");
        cid.bid(aliceAddress, "alice");
    }

    function test_NameAfterGracePeriod_BidWithInsufficientFunds_RevertInsufficientFunds()
        public
    {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);

        uint256 baseFee = cid.getPriceWei("alice", 1);
        vm.warp(startTs + 61 seconds + 365 days + 30 days);
        // round 0 cost base fee + 1000 eth
        vm.expectRevert("INSUFFICIENT_FUNDS");
        cid.bid{ value: baseFee * 1 wei + 1000 ether - 1 wei }(
            bobAddress,
            "alice"
        );
    }

    function test_NameAfterGracePeriod_BidAtRound0_Success() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);
        uint256 registerCost = cid.getPriceWeiAt("alice", 1, 1);

        uint256 baseFee = cid.getPriceWei("alice", 1);
        uint256 bidFee = baseFee + 1000 ether;
        vm.warp(startTs + 61 seconds + 365 days + 30 days);
        vm.expectEmit(true, true, true, true);
        emit Bid(
            "alice",
            startTs + 61 seconds + 365 days + 30 days + 365 days,
            bidFee
        );
        // round 0 cost base fee + 1000 eth, overpay 1 eth on purpose to test refund
        cid.bid{ value: bidFee + 1 ether }(bobAddress, "alice");
        uint256 tokenId = cid.getTokenId("alice");
        assertEq(cid.ownerOf(tokenId), bobAddress);
        assertEq(aliceAddress.balance, startBalance - registerCost - bidFee);
        assertEq(address(cid).balance, registerCost + bidFee);
    }

    function test_NameAfterGracePeriod_BidAtRound0WithWrongWallet_RevertRefundFail()
        public
    {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);

        vm.stopPrank();
        vm.startPrank(mockWalletAddress);
        uint256 baseFee = cid.getPriceWei("alice", 1);
        uint256 bidFee = baseFee + 1000 ether;
        vm.warp(startTs + 61 seconds + 365 days + 30 days);
        vm.expectRevert("REFUND_FAILED");
        cid.bid{ value: bidFee + 1 ether }(bobAddress, "alice");
    }

    function test_NameAfterGracePeriod_BidAtRound394_Success() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);
        uint256 registerCost = cid.getPriceWeiAt("alice", 1, 1);

        uint256 baseFee = cid.getPriceWei("alice", 1);
        uint256 bidFee = baseFee;
        uint256 bidTs = startTs +
            61 seconds +
            365 days +
            30 days +
            8 hours *
            394;
        vm.warp(bidTs);
        vm.expectEmit(true, true, true, true);
        emit Bid("alice", bidTs + 365 days, bidFee);
        // round 0 cost base fee + 1000 eth, overpay 1 eth on purpose to test refund
        cid.bid{ value: bidFee + 1 ether }(bobAddress, "alice");
        uint256 tokenId = cid.getTokenId("alice");
        assertEq(cid.ownerOf(tokenId), bobAddress);
        assertEq(aliceAddress.balance, startBalance - registerCost - bidFee);
        assertEq(address(cid).balance, registerCost + bidFee);
    }

    function test_Registered_Withdraw_OwnerReceived() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);
        uint256 registerCost = cid.getPriceWeiAt("alice", 1, 1);
        assertEq(address(cid).balance, registerCost);
        assertEq(aliceAddress.balance, startBalance - registerCost);

        cid.withdraw();
        assertEq(address(cid).balance, 0);
        assertEq(aliceAddress.balance, startBalance);
    }

    function test_NotRegistered_OwnerOf_RevertInvalidTokenId() public {
        uint256 tokenId = cid.getTokenId("alice");
        vm.expectRevert("ERC721: invalid token ID");
        cid.ownerOf(tokenId);
    }

    function test_Registered_OwnerOf_Success() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);

        assertEq(cid.ownerOf(cid.getTokenId("alice")), aliceAddress);
    }

    function test_Registered_ExpiredOwnerOf_RevertExpired() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);

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
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);

        uint256 tokenId = cid.getTokenId("alice");
        vm.expectEmit(true, true, true, true);
        emit Transfer(aliceAddress, bobAddress, tokenId);
        cid.safeTransferFrom(aliceAddress, bobAddress, tokenId, "");
    }

    function test_NameExpired_SafeTransferFrom_RevertExpired() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);

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
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);

        uint256 tokenId = cid.getTokenId("alice");
        vm.expectEmit(true, true, true, true);
        emit Transfer(aliceAddress, bobAddress, tokenId);
        cid.safeTransferFrom(aliceAddress, bobAddress, tokenId);
    }

    function test_NameExpired_SafeTransferFrom2_RevertExpired() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);

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
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);

        vm.warp(startTs + 61 seconds + 365 days);
        uint256 tokenId = cid.getTokenId("alice");
        vm.expectRevert("EXPIRED");
        cid.transferFrom(aliceAddress, bobAddress, tokenId);
    }

    function test_Registered_TransferFrom_Success() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);

        uint256 tokenId = cid.getTokenId("alice");
        vm.expectEmit(true, true, true, true);
        emit Transfer(aliceAddress, bobAddress, tokenId);
        cid.transferFrom(aliceAddress, bobAddress, tokenId);
    }

    function test_BaseUriNotSet_TokenUri_Success() public {
        uint256 tokenId = cid.getTokenId("alice");
        assertEq(
            cid.tokenURI(tokenId),
            "0x9c0257114eb9399a2985f8e75dad7600c5d89fe3824ffa99ec1c3eb8bf3b0501.json"
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
                    "0x9c0257114eb9399a2985f8e75dad7600c5d89fe3824ffa99ec1c3eb8bf3b0501.json"
                )
            )
        );
    }

    function test_NameRegistered_SetMetadata_ReadSuccess() public {
        cid.commit(commitment);
        vm.warp(startTs + 61 seconds);
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);

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
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);

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
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);

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
        cid.register{ value: 1 ether }("alice", aliceAddress, 1, secret, 1);

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
