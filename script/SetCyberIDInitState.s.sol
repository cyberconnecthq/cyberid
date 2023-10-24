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
                0xe55793f55dF1F1B5037ebA41881663583d4f9B24, // cyber id
                0x3Ec8E19306DF5A262b365E433Dd9A2A137a92FC3, // permissioned stable fee mw
                0x5eA688312b97D5F1eD36DB65240a2e04f1Eb5899, // registry
                0x2A40683b8664FEBdCDE113cb890F4CCd9B07F55E, // public resolver
                0x0D56dA4A8cF09BEC31e22C66209605FF7DFB8ea2 // reverse registrar
            );
        }
        vm.stopBroadcast();
    }
}
