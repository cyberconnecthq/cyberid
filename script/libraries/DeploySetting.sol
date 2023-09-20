// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.14;

contract DeploySetting {
    struct DeployParameters {
        address deployerContract;
        address usdOracle;
        address signer;
    }

    DeployParameters internal deployParams;

    uint256 internal constant BASE_GOERLI = 84531;
    uint256 internal constant MUMBAI = 80001;
    uint256 internal constant OP_GOERLI = 420;

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
        } else if (block.chainid == OP_GOERLI) {
            deployParams.deployerContract = address(
                0x277c467cB75175E8a2821FAB1054dC3745C19bA4
            );
            deployParams.usdOracle = address(
                0x57241A37733983F97C4Ab06448F244A1E0Ca0ba8
            );
            deployParams.signer = address(
                0xaB24749c622AF8FC567CA2b4d3EC53019F83dB8F
            );
        } else {
            revert("PARAMS_NOT_SET");
        }
    }
}
