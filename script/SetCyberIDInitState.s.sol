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
                0x714638Def68cF32A641B0735e489733B3187f431, // cyber id
                0x889c6Bb8d1dFBc0210007dB15404AFb4C4BA913e // permissioned stable fee mw
            );
        }
        vm.stopBroadcast();
    }
}
