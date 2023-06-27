// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import "forge-std/Test.sol";
import "../../src/core/MocaId.sol";
import { ERC1967Proxy } from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "forge-std/console.sol";

abstract contract MocaIdTestBase is Test {
    MocaId public mid;
    uint256 public aliceSk = 666;
    address public aliceAddress = vm.addr(aliceSk);
    uint256 public bobSk = 888;
    address public bobAddress = vm.addr(bobSk);
    // 2023-05-22T17:25:30
    uint256 public startTs = 1684747530;
    uint256 public startBalance = 2000 ether;
    bytes32 public mocaNode;

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

    function setUp() public virtual {
        vm.startPrank(bobAddress);
        MocaId midImpl = new MocaId();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(midImpl),
            abi.encodeWithSelector(
                MocaId.initialize.selector,
                "MOCA ID",
                "MOCAID",
                aliceAddress
            )
        );

        vm.stopPrank();
        vm.startPrank(aliceAddress);
        mid = MocaId(address(proxy));
        mid.grantRole(keccak256("OPERATOR_ROLE"), aliceAddress);
        mocaNode = mid.allowNode("moca", bytes32(0), true);
        console.logBytes32(mocaNode);

        // set timestamp to startTs
        vm.warp(startTs);
        vm.deal(aliceAddress, startBalance);
    }
}
