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
                0x6AC6A275931f721A83Ed5d813C87aA7Bfb443c3C, // cyber id
                0xC81e61eBDd2F4ce8e4242f7a866bd41935033d0a, // permissioned stable fee mw
                0x783a3C984C315a16A813E3468464262e1dAe088E, // registry
                0xF742d057a12dA8E6a1339C5a0DAb05130b86a1d1, // public resolver
                0x04A49Ff8c8E6144738841f6FF0a8C04f82F71e3b // reverse registrar
            );
        }
        vm.stopBroadcast();
    }
}
