// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import "forge-std/Script.sol";
import { DeploySetting } from "./libraries/DeploySetting.sol";
import { LibDeploy } from "./libraries/LibDeploy.sol";
import { MockUsdOracle } from "../test/utils/MockUsdOracle.sol";

contract DeployCyberId is Script, DeploySetting {
    function run() external {
        _setDeployParams();
        vm.startBroadcast();

        if (
            block.chainid == DeploySetting.OP_GOERLI ||
            block.chainid == DeploySetting.OP ||
            block.chainid == DeploySetting.OP_SEPOLIA ||
            block.chainid == DeploySetting.CYBER_TESTNET ||
            block.chainid == DeploySetting.CYBER
        ) {
            LibDeploy.deployCyberId(vm, deployParams);
        }
        vm.stopBroadcast();
    }
}

contract DeployMockOracle is Script, DeploySetting {
    function run() external {
        _setDeployParams();
        vm.startBroadcast();

        if (block.chainid == DeploySetting.CYBER_TESTNET) {
            new MockUsdOracle();
        }
        vm.stopBroadcast();
    }
}
