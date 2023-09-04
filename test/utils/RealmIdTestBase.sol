// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import "forge-std/Test.sol";
import "../../src/core/RealmId.sol";
import { ERC1967Proxy } from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "forge-std/console.sol";

abstract contract RealmIdTestBase is Test {
    RealmId public mid;
    uint256 public aliceSk = 666;
    address public aliceAddress = vm.addr(aliceSk);
    uint256 public bobSk = 888;
    address public bobAddress = vm.addr(bobSk);
    // 2023-05-22T17:25:30
    uint256 public startTs = 1684747530;
    uint256 public startBalance = 2000 ether;
    bytes32 public realmNode;

    event Register(
        string name,
        bytes32 parentNode,
        uint256 indexed tokenId,
        address indexed to
    );
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );
    event Burn(uint256 indexed tokenId, uint256 burnCount);

    function setUp() public virtual {
        vm.startPrank(bobAddress);
        RealmId midImpl = new RealmId();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(midImpl),
            abi.encodeWithSelector(
                RealmId.initialize.selector,
                "Realm ID",
                "RID",
                aliceAddress
            )
        );

        vm.stopPrank();
        vm.startPrank(aliceAddress);
        mid = RealmId(address(proxy));
        realmNode = mid.allowNode(
            "moca",
            bytes32(0),
            true,
            "",
            address(0),
            new bytes(0)
        );

        // set timestamp to startTs
        vm.warp(startTs);
        vm.deal(aliceAddress, startBalance);
    }
}
