// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import "forge-std/Test.sol";
import "../../src/core/CyberId.sol";
import { DataTypes } from "../../src/libraries/DataTypes.sol";
import { MockMiddleware } from "../utils/MockMiddleware.sol";

abstract contract CyberIdTestBase is Test {
    CyberId public cid;
    uint256 public aliceSk = 666;
    address public aliceAddress = vm.addr(aliceSk);
    uint256 public bobSk = 888;
    address public bobAddress = vm.addr(bobSk);
    bytes32 public commitment;
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

    function setUp() public virtual {
        vm.startPrank(aliceAddress);
        cid = new CyberId("CYBER ID", "CYBERID", aliceAddress);
        MockMiddleware middleware = new MockMiddleware();
        cid.setMiddleware(address(middleware), new bytes(0));
        // set timestamp to startTs
        vm.warp(startTs);
        vm.deal(aliceAddress, startBalance);
        commitment = cid.generateCommit("alice", aliceAddress, secret, "");
    }
}
