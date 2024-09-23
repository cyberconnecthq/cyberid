// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import "forge-std/Script.sol";
import { DeploySetting } from "./libraries/DeploySetting.sol";
import { LibDeploy } from "./libraries/LibDeploy.sol";
import { CyberId } from "../src/core/CyberId.sol";
import { PermissionedStableFeeMiddleware } from "../src/middlewares/cyberid/PermissionedStableFeeMiddleware.sol";

contract SetCyberIdMw is Script, DeploySetting {
    function run() external {
        _setDeployParams();
        vm.startBroadcast();

        if (block.chainid == DeploySetting.CYBER) {
            address cyberIdProxy = 0xC137Be6B59E824672aaDa673e55Cf4D150669af8;
            address mw = LibDeploy.deployCyberIdPermissionedStableMw(
                vm,
                deployParams,
                cyberIdProxy
            );
            CyberId(cyberIdProxy).setMiddleware(
                mw,
                abi.encode(
                    deployParams.signer,
                    deployParams.recipient,
                    [uint256(100 ether), 40 ether, 10 ether, 4 ether]
                )
            );
        } else if (block.chainid == DeploySetting.CYBER_TESTNET) {
            address cyberIdProxy = 0x58688732998f6c9f7Bde811C6576AD471C373061;
            address mw = LibDeploy.deployCyberIdPermissionedStableMw(
                vm,
                deployParams,
                cyberIdProxy
            );
            CyberId(cyberIdProxy).setMiddleware(
                mw,
                abi.encode(
                    deployParams.signer,
                    deployParams.recipient,
                    [uint256(100 ether), 40 ether, 10 ether, 4 ether]
                )
            );
        } else if (block.chainid == DeploySetting.OP_GOERLI) {
            address cyberIdProxy = 0x6AC6A275931f721A83Ed5d813C87aA7Bfb443c3C;
            CyberId(cyberIdProxy).unpause();
            CyberId(cyberIdProxy).setMiddleware(
                0x5a598E0040B8d429CD41b17E201D356d517d3aD3,
                abi.encode(
                    true,
                    deployParams.recipient,
                    [
                        uint256(10000 ether),
                        2000 ether,
                        1000 ether,
                        500 ether,
                        100 ether,
                        50 ether,
                        10 ether,
                        5 ether
                    ]
                )
            );
        } else if (block.chainid == DeploySetting.OP) {
            address cyberIdProxy = 0xe55793f55dF1F1B5037ebA41881663583d4f9B24;
            CyberId(cyberIdProxy).setMiddleware(
                0x3Ec8E19306DF5A262b365E433Dd9A2A137a92FC3,
                abi.encode(
                    false,
                    deployParams.signer,
                    deployParams.recipient,
                    [
                        uint256(10000 ether),
                        2000 ether,
                        1000 ether,
                        500 ether,
                        100 ether,
                        50 ether,
                        10 ether,
                        5 ether
                    ]
                )
            );
            // CyberId(cyberIdProxy).unpause();
        } else if (block.chainid == DeploySetting.OP_SEPOLIA) {
            address cyberIdProxy = 0x484D1170d28EECda1200c32B186C66BE6e0332ec;
            address stableFeeMw = LibDeploy.deployCyberIdStableMw(
                vm,
                deployParams,
                cyberIdProxy
            );
            CyberId(cyberIdProxy).setMiddleware(
                stableFeeMw,
                abi.encode(
                    true,
                    deployParams.recipient,
                    [
                        uint256(10000 ether),
                        2000 ether,
                        1000 ether,
                        500 ether,
                        100 ether,
                        50 ether,
                        10 ether,
                        5 ether
                    ]
                )
            );
        }
        vm.stopBroadcast();
    }
}
