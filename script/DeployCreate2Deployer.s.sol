// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import { Create2Deployer } from "../src/deployer/Create2Deployer.sol";
import { DeploySetting } from "./libraries/DeploySetting.sol";

contract DeployerCreate2Deployer is Script, DeploySetting {
    function run() external {
        uint256 nonce = vm.getNonce(msg.sender);
        if (block.chainid == DeploySetting.BASE_GOERLI) {
            require(nonce == 1, "nonce must be 0");
            console.log("deployer", msg.sender);
            require(
                msg.sender == 0x7B23B874cD857C5968434F95674165a36CfD5E4e,
                "address must be deployer"
            );
        } else if (block.chainid == DeploySetting.MUMBAI) {
            require(nonce == 0, "nonce must be 0");
            console.log("deployer", msg.sender);
            require(
                msg.sender == 0x7B23B874cD857C5968434F95674165a36CfD5E4e,
                "address must be deployer"
            );
        } else {
            revert("PARAMS_NOT_SET");
        }

        vm.startBroadcast();
        new Create2Deployer();
        vm.stopBroadcast();
    }
}
