// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

contract DeploySetting {
    struct DeployParameters {
        address deployerContract;
        address usdOracle;
    }

    DeployParameters internal deployParams;

    uint256 internal constant BASE_GOERLI = 84531;

    uint256 internal constant MUMBAI = 80001;

    function _setDeployParams() internal {
        if (block.chainid == BASE_GOERLI) {
            deployParams.deployerContract = address(
                0xa6B0Df5d90eE6881b39da6DBCA36ebD44e6428D8
            );
            deployParams.usdOracle = address(
                0xcD2A119bD1F7DF95d706DE6F2057fDD45A0503E2
            );
        } else if (block.chainid == MUMBAI) {
            deployParams.deployerContract = address(
                0x277c467cB75175E8a2821FAB1054dC3745C19bA4
            );
        } else {
            revert("PARAMS_NOT_SET");
        }
    }
}
