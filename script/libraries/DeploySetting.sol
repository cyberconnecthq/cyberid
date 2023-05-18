// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

contract DeploySetting {
    struct DeployParameters {
        address deployerContract;
    }

    DeployParameters internal deployParams;

    uint256 internal constant BASE_GOERLI = 84531;

    function _setDeployParams() internal {
        if (block.chainid == BASE_GOERLI) {
            deployParams.deployerContract = address(
                0xa6B0Df5d90eE6881b39da6DBCA36ebD44e6428D8
            );
        } else {
            revert("PARAMS_NOT_SET");
        }
    }
}
