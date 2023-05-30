// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import "forge-std/Script.sol";
import { PermissionMw } from "../src/middlewares/PermissionMw.sol";
import { Constants } from "../src/libraries/Constants.sol";
import { TestLib712 } from "../test/utils/TestLib712.sol";

contract TempScript is Script {
    function run() external {
        // vm.startBroadcast();
        // vm.stopBroadcast();
    }
}
