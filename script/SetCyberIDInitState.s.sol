// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import "forge-std/Script.sol";
import { DeploySetting } from "./libraries/DeploySetting.sol";
import { LibDeploy } from "./libraries/LibDeploy.sol";

contract SetCyberIDInitState is Script, DeploySetting {
    function run() external {
        _setDeployParams();
        vm.startBroadcast();

        if (
            block.chainid == DeploySetting.OP_GOERLI ||
            block.chainid == DeploySetting.OP
        ) {
            LibDeploy.setCyberIDInitState(
                deployParams,
                0x2616c48a5Fff1EEf69cd044e7866906610ac4EB6, // cyber id
                0xb71612F4914c7763C1c5cac0A084B5DB40Be7EB2, // permissioned stable fee mw
                0xfB99ed56DEbEc34F0BaC7Aeea661B9fD67017E46, // registry
                0xAB268EE7aa3Be9AC10a57435B08b255bA2824a2d, // public resolver
                0x5d0c37e494EDfe4A3b32CEA1bFF8F9FE0cCCc3EF // reverse registrar
            );
        }
        vm.stopBroadcast();
    }
}
