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
            // address mw = LibDeploy.deployCyberIdPermissionedStableMw(
            //     vm,
            //     deployParams,
            //     cyberIdProxy
            // );
            address mw = 0x8A7D29248e497eF02DB6fc888d716553d26161ef;
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
        }
        vm.stopBroadcast();
    }
}
