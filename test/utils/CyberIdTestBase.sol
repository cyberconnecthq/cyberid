// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import "forge-std/Test.sol";
import "../../src/core/CyberId.sol";
import { DataTypes } from "../../src/libraries/DataTypes.sol";
import { MockMiddleware } from "../utils/MockMiddleware.sol";
import { ERC1967Proxy } from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { CyberIdRegistry } from "../../src/core/CyberIdRegistry.sol";
import { CyberIdPublicResolver } from "../../src/core/CyberIdPublicResolver.sol";
import { CyberIdReverseRegistrar } from "../../src/core/CyberIdReverseRegistrar.sol";

import { ReverseRegistrar } from "@ens/registry/ReverseRegistrar.sol";
import { ENS } from "@ens/registry/ENS.sol";

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

    CyberIdRegistry public registry;
    CyberIdPublicResolver public resolver;
    ReverseRegistrar public reverseRegistrar;

    event Register(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId,
        string cid,
        uint256 cost
    );
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    function setUp() public virtual {
        vm.startPrank(aliceAddress);

        registry = new CyberIdRegistry(aliceAddress);
        resolver = new CyberIdPublicResolver(registry, aliceAddress);
        reverseRegistrar = new CyberIdReverseRegistrar(registry, aliceAddress);
        reverseRegistrar.setDefaultResolver(address(resolver));

        CyberId cidImpl = new CyberId();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(cidImpl),
            abi.encodeWithSelector(
                CyberId.initialize.selector,
                address(registry),
                address(resolver),
                address(reverseRegistrar),
                "CYBER ID",
                "CYBERID",
                aliceAddress
            )
        );
        registry.setSubnodeOwner(
            bytes32(0),
            keccak256(bytes("cyber")),
            address(proxy)
        );
        bytes32 reverseNode = registry.setSubnodeOwner(
            bytes32(0),
            keccak256(bytes("reverse")),
            aliceAddress
        );
        bytes32 addrReverseNode = registry.setSubnodeOwner(
            reverseNode,
            keccak256(bytes("addr")),
            address(reverseRegistrar)
        );

        require(
            addrReverseNode ==
                bytes32(
                    0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2
                ),
            "WRONG_ADDR_REVERSE_NODE"
        );

        resolver.setTrustedCyberIdRegistrar(address(proxy));
        resolver.setTrustedReverseRegistrar(address(reverseRegistrar));
        reverseRegistrar.setController(address(proxy), true);
        cid = CyberId(address(proxy));
        cid.grantRole(keccak256(bytes("OPERATOR_ROLE")), aliceAddress);
        MockMiddleware middleware = new MockMiddleware();
        cid.setMiddleware(address(middleware), new bytes(0));
        // set timestamp to startTs
        vm.warp(startTs);
        vm.deal(aliceAddress, startBalance);
        commitment = cid.generateCommit("alice", aliceAddress, secret, "");
    }
}
