// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

import { ReverseRegistrar } from "@ens/registry/ReverseRegistrar.sol";
import { ENS } from "@ens/registry/ENS.sol";

contract CyberIdReverseRegistrar is ReverseRegistrar {
    constructor(ENS _ens, address _owner) ReverseRegistrar(_ens) {
        _transferOwnership(_owner);
    }
}
