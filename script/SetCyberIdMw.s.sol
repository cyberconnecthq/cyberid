// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import "forge-std/Script.sol";
import { DeploySetting } from "./libraries/DeploySetting.sol";
import { LibDeploy } from "./libraries/LibDeploy.sol";
import { CyberId } from "../src/core/CyberId.sol";

contract SetCyberIdMw is Script, DeploySetting {
    function run() external {
        _setDeployParams();
        vm.startBroadcast();

        if (block.chainid == DeploySetting.OP_GOERLI) {
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
        }
        vm.stopBroadcast();
    }
}
