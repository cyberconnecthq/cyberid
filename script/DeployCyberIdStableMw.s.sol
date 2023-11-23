// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import "forge-std/Script.sol";
import { DeploySetting } from "./libraries/DeploySetting.sol";
import { LibDeploy } from "./libraries/LibDeploy.sol";

contract DeployCyberIdStableMw is Script, DeploySetting {
    function run() external {
        _setDeployParams();
        vm.startBroadcast();

        if (block.chainid == DeploySetting.OP_GOERLI) {
            LibDeploy.deployCyberIdStableMw(
                vm,
                deployParams,
                0x6AC6A275931f721A83Ed5d813C87aA7Bfb443c3C
            );
        } else if (block.chainid == DeploySetting.OP) {
            LibDeploy.deployCyberIdStableMw(
                vm,
                deployParams,
                0xe55793f55dF1F1B5037ebA41881663583d4f9B24
            );
        }
        vm.stopBroadcast();
    }
}
